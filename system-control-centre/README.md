# System Control Centre (dashboard)

The React dashboard of the System Control Centre. It shows live metrics for the Heart Care platform
and runs Demonstration Mode. Overall setup and architecture: [`monitoring/README.md`](../monitoring/README.md).

Stack: React 19, Vite, TypeScript, Tailwind CSS 4, Recharts, TanStack Query, react-router (same as
`admin-web/`).

## Development

Needs the Monitoring API running on port 8090. The quickest way is the full stack in Docker; or run
`monitoring-api/` with `mvn spring-boot:run` and the `SCC_*` and `PROMETHEUS_URL` variables set.

```bash
npm install
npm run dev     # http://localhost:5175, proxies /api to http://localhost:8090
npm run build   # type-check and production build
npm run lint
```

Set `VITE_PROXY_TARGET` to proxy to a Monitoring API elsewhere.

## Structure

```
src/
  services/   client.ts (fetch + session), monitoringApi.ts (endpoints), types.ts (DTOs)
  hooks/      useMonitoring.ts: every query and its refresh interval, in one place
  components/ MetricCard, StatusIndicator, PerformanceChart, PulseTrace, DataTable, Panel, Sidebar
  layouts/    ConsoleLayout: header status strip + section navigation
  pages/      Login, Overview, ApiPerformance, Database, Infrastructure, Network, Activity, Demo
  lib/        formatting and status thresholds
```

Polling is centralised in `useMonitoring.ts`: one request per section on its own interval
(5 seconds; 10 for the database), shared by every component that reads it and paused while the tab
is hidden. Every metric can be `null` when its source is not reporting; the UI shows a dash and,
for whole sections, says which exporter to start.

The colour thresholds in `src/lib/tone.ts` (for example CPU amber at 70%, red at 90%) are initial
demonstration settings, not service-level targets.

## Docker

The image builds the bundle and serves it from nginx. nginx forwards only `/api/monitoring/` to
`monitoring-api:8090`, so the Monitoring API's actuator is never reachable through the dashboard.
