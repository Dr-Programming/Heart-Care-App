# System Control Centre: monitoring stack

The System Control Centre (SCC) is a separate monitoring console for the Heart Care platform. It
gives a live view of how the system performs while admin, researcher and mobile users work in it,
and can record a **demonstration session** with a measured performance report.

It watches the platform without changing how the platform works. If the monitoring stack is stopped
or broken, the admin panel, research app, mobile app and API carry on as normal.

## Architecture

```
 Admin web ─┐                                   ┌─ windows_exporter (on the Windows host)
 Research ──┼── nginx ──► backend :8080 ────┐   │
 Mobile ────┘ (ngrok)      │  :9081 actuator├──►│  Prometheus ◄── postgres-exporter ◄── PostgreSQL
                           │  (internal)    │   │  (15 days)  ◄── cAdvisor (containers)
                           ▼                │   │
                       PostgreSQL           │   └──────────────┐
                                            │                  ▼
                                            └── activity ─► Monitoring API :8090 ──► scc-web :3002
                                                feed            (PromQL lives here)    (React)
```

- **Prometheus** collects and stores every metric, sampled every 5 seconds and kept for 15 days or
  2 GB, whichever comes first.
- **Monitoring API** (`monitoring-api/`, Spring Boot) is the only thing that queries Prometheus. It
  turns PromQL results into plain JSON for each dashboard section and runs Demonstration Mode.
- **scc-web** (`system-control-centre/`, React) is the dashboard. It never sees PromQL, Prometheus or
  the database.
- **The backend** serves metrics on a separate management port (9081) that is never published to
  the host. ngrok forwards port 8080, so nothing about the monitoring is reachable from the internet.

| Component | Where | Reachable from |
|---|---|---|
| scc-web (dashboard) | container `heartcare-scc-web` | LAN, http://<server>:3002 |
| Monitoring API | container `heartcare-monitoring-api` :8090 | compose network only (via scc-web's `/api/monitoring/`) |
| Prometheus | container `heartcare-prometheus` :9090 | compose network, plus `127.0.0.1:9090` on the server |
| postgres-exporter | container :9187 | compose network only |
| cAdvisor (opt-in) | container :8080 | compose network only |
| Backend actuator | `backend:9081/actuator/*` | compose network only |
| windows_exporter | Windows service :9182 | the server and Docker's private network |

## Running it

1. Set the monitoring values in `.env` (see `.env.example`):
   - `MONITORING_DB_PASSWORD`: password for the read-only `monitoring_user`
   - `SCC_ADMIN_USERNAME`, `SCC_ADMIN_PASSWORD` (12+ characters): the SCC login, separate from the admin panel
   - `SCC_JWT_SECRET`: `openssl rand -base64 48`
2. Start everything:
   ```powershell
   docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d --build
   ```
   The overlay restarts PostgreSQL once with `pg_stat_statements` preloaded. Data is untouched.
3. Optional, for real host CPU, memory, disk and network: install windows_exporter
   ([windows-exporter/README.md](windows-exporter/README.md)). Without it, CPU is shown for the
   Docker VM and host memory is marked unavailable.
4. Optional, for per-container CPU and memory: add `--profile cadvisor` to the command above. See
   [Container metrics](#container-metrics) first: on Docker Desktop it needs a settings change.
5. Open **http://localhost:3002** (or the server's LAN address) and sign in with the SCC account.

To run the platform without monitoring, use plain `docker compose up -d` as before.

### Checking it works

- `http://localhost:9090/targets`: `spring-boot`, `postgresql`, `monitoring-api` and `prometheus`
  should be UP. `windows` is UP once windows_exporter is installed, and `cadvisor` only when its
  profile is enabled; until then they show DOWN, which is expected.
- `curl http://localhost:8080/actuator/prometheus` must **not** return metrics (expect 401). That is
  the ngrok-facing port; actuator only exists on 9081.
- `docker compose logs postgres-monitoring-init` should end without errors.

## Dashboard sections

| Section | Shows | Refresh |
|---|---|---|
| Overview | System health, active users, requests, latency, CPU, memory, a live request trace | 5 s |
| API performance | Requests/s, average and P95 latency, failures, success rate, per-endpoint table, status codes, traffic by app | 5 s |
| Database | Active/idle connections, transactions/s, cache hit ratio, size, slow statements, deadlocks, Hikari pool, top 10 statements | 10 s |
| Infrastructure | Host CPU, memory, disk, network; every container's status, CPU and memory | 5 s |
| Network | ngrok tunnel status, local web vs mobile traffic, failed external requests, server traffic | 5 s |
| Activity | Anonymised timeline of what people are doing | 5 s |
| Demonstration | Start/stop a recorded session and its performance report | 5 s |

The Monitoring API caches each response for 3 seconds, so several open dashboards do not multiply
the load on Prometheus.

### Container metrics

Container **status** always works: each container is checked through its Prometheus target or a
health-check URL. Per-container **CPU and memory** come from cAdvisor, which is opt-in
(`--profile cadvisor`) because of a Docker Desktop limitation, verified on Docker Desktop 28 / WSL2:
with "Use containerd for pulling and storing images" enabled (the default in recent versions),
cAdvisor finds the containers but cannot resolve their image layers, logs
`failed to identify the read-write layer ID`, and exports no per-container data.

- **Linux server with Docker Engine:** enable the profile; it works as is.
- **Docker Desktop:** turn off *Settings → General → Use containerd for pulling and storing images*
  (images are re-pulled), then enable the profile.
- **Otherwise:** leave it off. The Infrastructure page shows each container's status, with CPU and
  memory as a dash, and host-level CPU and memory still come from windows_exporter.

### How mobile and web traffic are told apart

The backend tags every request metric with `client` = `admin`, `researcher`, `mobile` or `public`,
from the route. Routes are role-guarded (`/api/v1/admin/**` needs an admin token,
`/api/v1/research/**` a researcher token, and the rest a patient token, which only the mobile app
has), so the classification can't be faked with a header.

### Active users

"Active users" counts distinct signed-in users whose requests the backend saw in the last 5 minutes.
It is held in memory in the backend; no user ids are exported.

### Activity timeline

The backend keeps the last 200 completed requests as anonymised events (time, app, a fixed
category such as "Researcher ran an analysis", outcome, duration). The Monitoring API reads them
from `backend:9081/actuator/scc-activity`. They never include user ids, record ids, paths with ids,
query parameters or bodies, and they are separate from the business audit tables.

## Demonstration Mode

1. On the **Demonstration** page, enter a name and the test conditions (for example "30 JMeter
   users for 10 minutes"), then press **Start demonstration**. The baseline is recorded.
2. Run the demonstration (see [jmeter/README.md](jmeter/README.md) for load tests).
3. Press **Stop and generate report**. The summary is computed by Prometheus over exactly the
   session's time window: total, successful and failed requests, average and P95 latency, peak
   requests/s, peak CPU and memory, peak active users and peak database sessions.
4. **Export JSON** downloads the report.

The report keeps the operator's stated conditions apart from the measured figures, and lists the
caveats of each measurement. Sessions are held in the Monitoring API's memory (the last 20) and are
lost when it restarts, so export any you want to keep.

## Security

- The SCC has its own login (`SCC_ADMIN_USERNAME` / `SCC_ADMIN_PASSWORD`), separate from the admin
  panel. Sessions last 8 hours. Sign-in is limited to 10 attempts per 15 minutes per client.
- The Monitoring API refuses to start without `SCC_JWT_SECRET` (32+ bytes) and the SCC credentials.
- postgres-exporter connects as `monitoring_user`, which only has the `pg_monitor` role (read access
  to statistics views), never the application's credentials.
- Prometheus, the exporters, the Monitoring API and the backend's actuator are never published to
  the LAN or through ngrok. Only the dashboard (port 3002) is.
- The dashboard shows no personal information: request metrics use route templates
  (`/api/v1/admin/users/{id}`), the activity feed is anonymised, and pg_stat_statements text is
  normalised (`$1` placeholders, never values).

## Development

```bash
cd monitoring-api
mvn test                # no Docker or Testcontainers needed
mvn spring-boot:run     # needs SCC_ADMIN_USERNAME, SCC_ADMIN_PASSWORD, SCC_JWT_SECRET;
                        # PROMETHEUS_URL defaults to http://localhost:9090
```

The Monitoring API listens on port 8090. For the dashboard's dev server, see
[`system-control-centre/README.md`](../system-control-centre/README.md).

## Removing it

`docker compose -f docker-compose.yml -f docker-compose.monitoring.yml down`, then
`docker compose up -d` to bring the platform back without the overlay. The backend's actuator
dependency is harmless without Prometheus. To also drop the stored metrics:
`docker volume rm <project>_heartcare-prometheus-data`.
