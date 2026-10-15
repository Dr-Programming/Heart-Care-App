# Libu Care Admin (`admin-web`)

A React console over the Heart-Care database. Patient data is read-only: patients, their profile,
medications, dose history, vitals, symptom check-ins and activity, plus cross-patient lists of
out-of-range vitals and urgent symptom check-ins. It also manages researcher access (accounts, grants,
revoke and reset, the minimum group size) and shows the research activity log. It talks only to the
backend's `/api/v1/admin/**` endpoints and never to Postgres directly.

Stack: Vite, React, TypeScript, React Router, TanStack Query, TanStack Table, Tailwind CSS, Recharts.

## Run with Docker (normal use)

1. In the repo-root `.env`, set `ADMIN_USERNAME` and `ADMIN_PASSWORD` (12+ characters). The backend
   creates that account on startup if it doesn't exist. It never overwrites an existing account, so
   changing the password in `.env` later has no effect on an account that's already there.
2. From the repo root: `docker compose up -d --build`
3. Open http://localhost:3000 and sign in.

nginx serves the build and proxies `/api` to the backend container.

## Local development

With the backend running on `localhost:8080`:

```sh
cd admin-web
npm install
npm run dev      # http://localhost:5173, /api proxied to :8080 (override with VITE_PROXY_TARGET)
npm run build    # type-check + production build
npm run lint
```

## Admin guide

### Pages

| Page | What it shows |
|---|---|
| **Overview** | Patients registered, sign-ups in the last 7 days, vitals out of range, urgent or emergency check-ins, accounts locked after failed PINs, record totals and a 30-day sign-up chart. |
| **Patients** | Everyone registered through the mobile app, searchable by name or phone, with status (Active / Locked). Select a patient for their full record: profile, medications, dose history, vitals, check-ins and activity. |
| **Flagged vitals** | Out-of-range readings across all patients. |
| **Urgent symptoms** | Check-ins filtered by severity: *Urgent or emergency*, *Emergency only* or *Monitor or worse*. |
| **Researchers** | Researcher accounts and their access, and the minimum group size. |
| **Research activity** | Every request a researcher made, with CSV export. |
| **Researcher archive** | Deleted researchers, kept for audits. |

Nothing on the patient pages can be edited. Filters, sort and page are kept in the URL, so a filtered view
can be bookmarked or shared.

### Adding a researcher

1. **Researchers → Add a researcher.** Enter their full name, username and organisation.
2. Choose their access:
   - **What they can see:** *Aggregates only* (counts, averages, distributions, trends) or
     *Pseudonymous records* (aggregates plus row-level records under a random code per patient).
   - **Datasets:** any of Vitals, Symptom check-ins, Activity, Medications and doses, Demographics. At
     least one is required.
   - **Limits:** an optional date window for the data, an optional expiry date (access ends at the end of
     that day, UTC), and whether CSV downloads are allowed.
3. Save. The panel shows a **temporary password** once. Pass it to the researcher securely. They must
   replace it at their first sign-in at http://localhost:3001.

Researchers can't change their own name, username or organisation, and they can't change their password
again after the first sign-in; only an admin can reset it.

### Managing a researcher

Open them from **Researchers**:

- **Change access:** edit the grant and **Save access**. It applies to their next request.
- **Revoke access:** signs them out immediately. They can't sign in until you **Restore access**, which
  lets them back in with their current password.
- **Reset password:** issues a new temporary password and signs them out. They change it at next sign-in.
- **Delete researcher:** requires a reason. They are signed out and moved to the **Researcher archive**
  with their access settings, admin history and activity log. The username stays reserved.
- **Restore from archive:** brings them back to the list with access revoked. Restore access and reset
  the password to let them sign in again.

Each researcher's page has an **Admin history** of every change, with the access before and after.

### Minimum group size

Set on the **Researchers** page (default 5). Any research result describing fewer patients than this is
hidden from every researcher. Raising it protects small groups better; lowering it shows more detail.

## Notes

- Admin accounts are separate from patient and researcher accounts.
- The admin token is kept in `sessionStorage`, so it doesn't outlive the browser tab. The panel signs
  you out when the 8-hour token expires.
- Every admin request is written to the backend log under `admin-audit`
  (`docker logs heartcare-backend | grep admin-audit`).
- Theme follows the OS until you pick one; the choice is saved per browser.
