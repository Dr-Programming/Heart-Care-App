# Libu Care Admin (`admin-web`)

A React console over the Heart-Care database. Patient data is read-only: patients, their profile,
medications, dose history, vitals, symptom check-ins and activity, plus cross-patient lists of
out-of-range vitals and urgent symptom check-ins. It also manages researcher access (accounts, grants,
revoke and reset, the minimum group size) and shows the research activity log. It talks only to the backend's `/api/v1/admin/**` endpoints and never to
Postgres directly.

Stack: Vite, React, TypeScript, React Router, TanStack Query, TanStack Table, Tailwind CSS, Recharts.

## Run with Docker (normal use)

From the repo root, with `ADMIN_USERNAME` / `ADMIN_PASSWORD` set in `.env`:

```sh
docker compose up -d --build
```

Open http://localhost:3000. nginx serves the build and proxies `/api` to the backend container.

## Local development

With the backend running on `localhost:8080`:

```sh
cd admin-web
npm install
npm run dev      # http://localhost:5173, /api proxied to :8080 (override with VITE_PROXY_TARGET)
npm run build    # type-check + production build
npm run lint
```

## Notes

- The admin token is kept in `sessionStorage`, so it doesn't outlive the browser tab. The panel signs
  you out when the 8-hour token expires.
- Filters, sort and page live in the URL, so a filtered view can be bookmarked or shared.
- Theme follows the OS until you pick one; the choice is saved per browser.
