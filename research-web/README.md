# Libu Care Research (`research-web`)

The researcher-facing app: anonymised analytics over the Heart-Care data, for researchers an admin has
approved in the admin panel. It talks only to the backend's `/api/v1/research/**` endpoints. The
server enforces every limit: datasets, level, date window, expiry, export and the minimum group size.

Stack: Vite, React, TypeScript, React Router, TanStack Query, Tailwind CSS and Recharts, the same as
`admin-web`, with a teal accent so the two are never confused.

## Pages

- **Your access:** level, datasets, date window, expiry, downloads and the minimum group size.
- **Cohorts:** filter builder with a live, suppression-aware patient count; saved cohorts.
- **Explore a measure:** summary statistics and a histogram, per reading or per patient, optionally split by age band, CHD stage or language.
- **Trends:** weekly or monthly means or rates, comparing up to three cohorts.
- **Outcomes:** adherence against blood pressure, correlation (a scatter at pseudonymous level, a binned grid otherwise), and the symptom-severity mix over time.
- **Records:** pseudonymised rows (pseudonymous grants only).
- **Account:** read only.

Hidden results (fewer than *k* patients) are drawn hatched and labelled, never as zero.

## Run

With Docker, from the repo root: `docker compose up -d --build`, then open http://localhost:3001.

Local development, with the backend on `localhost:8080`:

```sh
cd research-web
npm install
npm run dev      # http://localhost:5174, /api proxied to :8080
npm run build
npm run lint
```
