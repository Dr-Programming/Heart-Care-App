# Load testing with JMeter

`heartcare-load.jmx` simulates the three kinds of user at once, so the System Control Centre shows
how the platform behaves under realistic mixed load:

| Thread group | Signs in with | Then repeats (1 to 3 s think time between requests) |
|---|---|---|
| Admin users | `adminUser` / `adminPassword` | dashboard, patient list, flagged vitals, urgent symptoms, research audit log |
| Researcher users | `researcherUser` / `researcherPassword` | data catalogue, describe systolic BP, weekly trend, severity over time, saved cohorts |
| Mobile users | a row of `patients.csv` | profile, record heart rate, recent vitals, medications, sync an activity, activity history |

Every user signs in once, then loops until `duration` runs out.

## Before the first run

1. Install [Apache JMeter](https://jmeter.apache.org/download_jmeter.cgi) 5.6 or later (it needs Java,
   which the backend already requires).
2. **Admin account**: the one from `ADMIN_USERNAME` / `ADMIN_PASSWORD` in `.env`.
3. **Researcher account**: create one in the admin panel, sign in once at research-web to replace the
   one-time password, and grant at least the VITALS and SYMPTOMS datasets. Researcher requests fail
   with `PASSWORD_CHANGE_REQUIRED` until the password has been changed.
4. **Mobile accounts**: from the repo root,
   ```powershell
   powershell -File monitoring\jmeter\create-test-patients.ps1 -Count 10
   ```
   This registers test patients and writes `monitoring/jmeter/patients.csv` (git-ignored). The
   backend allows 10 sign-ups per IP per hour; rows are recycled, so 10 accounts serve any number of
   mobile threads. Run it only against a demonstration database.

## Running

Run JMeter in non-GUI mode, ideally **on a different machine** from the server, so the load generator
does not compete with the system it measures. Point `host` at the server's LAN address.

```powershell
jmeter -n -t monitoring\jmeter\heartcare-load.jmx -l results.jtl -e -o report `
  -Jhost=192.168.1.20 -Jport=8080 `
  -JadminPassword=... -JresearcherUser=dr.example -JresearcherPassword=... `
  -JadminUsers=1 -JresearcherUsers=2 -JmobileUsers=12 -Jduration=300 -Jrampup=60
```

`-e -o report` writes JMeter's own HTML report to `report/`, to compare with the SCC demonstration
summary.

| Property | Default | Meaning |
|---|---|---|
| `host`, `port`, `protocol` | `localhost`, `8080`, `http` | Backend address |
| `adminUsers`, `researcherUsers`, `mobileUsers` | `1`, `2`, `5` | Concurrent users per role |
| `duration` | `120` | Seconds the test runs |
| `rampup` | `30` | Seconds over which users start |
| `adminUser`, `adminPassword` | `admin`, empty | Admin panel account |
| `researcherUser`, `researcherPassword` | `researcher`, empty | Researcher account |
| `patientsCsv` | `patients.csv` | `phone,pin` file, relative to the `.jmx` |

Credentials are only ever passed as properties; none are stored in the plan.

## Suggested scenarios

These are proposed test levels, not claims about the platform's capacity.

| Scenario | Admin | Researcher | Mobile | Total | `duration` |
|---|---|---|---|---|---|
| Baseline | 0 | 0 | 1 | 1 | 120 |
| Small load | 1 | 1 | 3 | 5 | 300 |
| Medium load | 2 | 3 | 10 | 15 | 300 |
| High load | 3 | 5 | 22 | 30 | 600 |
| Stress | Raise `mobileUsers` step by step (40, 60, 80…) | | | | 300 per step |

For the stress test, run successive steps and stop when P95 latency or the error rate on the SCC
API performance page climbs sharply; the Database page's "Requests waiting" and the Infrastructure
CPU chart show whether the pool, the database or the host is the bottleneck.

## With the System Control Centre

1. Open the SCC **Demonstration** page and press **Start demonstration**. Enter the conditions you are
   about to run, for example "Medium load: 2 admin, 3 researcher, 10 mobile for 5 minutes".
2. Start JMeter.
3. Watch Overview, API performance and Database while it runs.
4. When JMeter finishes, press **Stop and generate report**, then **Export JSON**.

The SCC report's request totals are computed by Prometheus from 5-second samples, so expect them
to be close to, not identical with, JMeter's own count.
