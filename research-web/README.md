# Libu Care Research (`research-web`)

The researcher-facing app: anonymised analytics over the Heart-Care data, for researchers an admin has
approved in the admin panel. It talks only to the backend's `/api/v1/research/**` endpoints. The
server enforces every limit: datasets, level, date window, expiry, export and the minimum group size.

Stack: Vite, React, TypeScript, React Router, TanStack Query, Tailwind CSS and Recharts, the same as
`admin-web`, with a teal accent so the two are never confused.

## Run

With Docker, from the repo root (`RESEARCH_PSEUDONYM_SECRET` must be set in `.env`):

```sh
docker compose up -d --build
```

Then open http://localhost:3001. nginx serves the build and proxies `/api` to the backend container.

Local development, with the backend on `localhost:8080`:

```sh
cd research-web
npm install
npm run dev      # http://localhost:5174, /api proxied to :8080
npm run build
npm run lint
```

There is no sign-up. Accounts are created by an admin in the admin panel (**Researchers → Add a
researcher**; see [`admin-web/README.md`](../admin-web/README.md#adding-a-researcher)).

## Researcher guide

### First sign-in

1. Your administrator gives you a username and a temporary password.
2. Sign in at http://localhost:3001. You're asked to **choose your own password**: at least 12 characters
   and different from the temporary one.
3. That is the only time you can change it. If you forget it, ask your administrator to reset it.

Everything you do in the app is recorded and visible to your administrator.

### What you can access

The **Your access** page shows exactly what your administrator granted:

- **Level:** *Aggregates only* (counts, averages, distributions, trends) or *Pseudonymous records*
  (aggregates plus row-level records).
- **Datasets:** any of vitals, symptom check-ins, activity, medications and doses, demographics.
- **Date window** for the data, **access end date**, and whether **CSV downloads** are allowed.

Your administrator can change, revoke or end your access at any time; it takes effect on your next request.

### Pages

- **Your access:** level, datasets, date window, expiry, downloads and the minimum group size.
- **Cohorts:** build a patient group from age band, CHD stage, other conditions, app language, medication,
  vitals and symptom check-ins, with a live patient count. Save it to reuse in the analyses; without one,
  analyses use all patients.
- **Explore a measure:** summary statistics (with 95% confidence interval) and a histogram, per reading
  or one average per patient, optionally split by age band, CHD stage or language.
- **Trends:** weekly or monthly means or rates, comparing up to three cohorts.
- **Outcomes:** blood pressure by medication adherence; correlation between two measures (Pearson *r*, a
  scatter at pseudonymous level, a binned grid otherwise); and the share of check-ins at each severity
  over time.
- **Records:** pseudonymised rows per dataset (pseudonymous access only).
- **Account:** your name, username and organisation, read only.

When downloads are allowed, analysis panels have a CSV export button.

### How results are protected

- Patients appear only as codes like `P-7F3AKQ2M`. Your codes differ from other researchers' codes for
  the same patients. Names, phone numbers, notes and exact ages are never shown; age is given as a band.
- Any result describing fewer patients than the **minimum group size** (shown on *Your access*, default 5)
  is hidden. Hidden results are drawn hatched and labelled, never as zero. A cohort that is too small says
  *Too few to analyse*.
- Filters only list values shared by enough patients.
