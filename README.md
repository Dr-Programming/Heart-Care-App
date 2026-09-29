# Heart-Care-App

**Project Started:** 2026-04-17

A cross-platform mobile application for managing coronary heart disease (CHD) patients in Ethiopia, developed as a UOW Capstone Project (Project 29).

## About

Heart-Care-App helps patients track and manage their CHD treatment plans. It supports offline-first usage for areas with limited connectivity and provides bilingual support in English and Amharic.

The current scope is **patient-only**. A clinician role, real-time alerting, and appointment scheduling are not part of this build.

**Supervised by:** Dr. Elena Vlahu-Gjorgievska & Prof. Khin Than Win
**Client:** Tesema Etefa Birhanu

## Tech Stack

- **Mobile:** Flutter (Dart) — iOS & Android
- **Backend:** Spring Boot (Java) — REST API
- **Database:** PostgreSQL (hosted on Railway)
- **Admin panel:** React + Vite (`admin-web/`) — database viewer and researcher management
- **Research app:** React + Vite (`research-web/`) — anonymised analytics for approved researchers

## Key Features

- Medication tracking with dose reminders
- Vitals logging (blood pressure, glucose, heart rate, weight)
- Symptom check-ins and activity logs
- On-device alerts for abnormal vitals and symptoms (evaluated offline)
- Offline-first sync — works without internet connectivity
- Bilingual UI (English & Amharic)

## Status

Early development.

- **Backend:** all 7 slices (auth, patient profile, medications & dose logs, vitals, symptoms, activity, offline sync) are implemented and tested. See [`backend/README.md`](./backend/README.md) for build/run instructions and slice-by-slice progress.
- **Mobile:** not yet built, but the first slice — **Foundation & Auth** — is designed and approved (`docs/design/2026-08-02-phone-pin-auth-and-mobile-foundation-design.md`). Stack decided: Flutter · Riverpod · go_router · Drift · Dio. Auth moves to phone + 4-digit PIN (see [`docs/frontend-decisions.md`](./docs/frontend-decisions.md)).

## Admin panel

`admin-web/` is a read-only React console for browsing patients and their records (profile, medications,
dose history, vitals, symptom check-ins, activity), plus cross-patient lists of out-of-range vitals and
urgent symptom check-ins. It replaces opening the database in a generic DB manager.

1. Set `ADMIN_USERNAME` and `ADMIN_PASSWORD` (12+ characters) in `.env` — see `.env.example`. The backend
   creates that admin account on startup if it doesn't exist; it never overwrites an existing one.
2. `docker compose up -d --build`
3. Open http://localhost:3000 and sign in.

Admin accounts are separate from patient accounts, admin tokens last 8 hours, and every admin request is
written to the backend log under `admin-audit`. See [`admin-web/README.md`](./admin-web/README.md) for local
development.

## Research access

Researchers get anonymised access to the data through a separate app, `research-web/`
(http://localhost:3001). Admins control everything from **Researchers** in the admin panel:

- **Accounts:** only an admin can create a researcher account. The admin gets a one-time password to pass on. The researcher must replace it at first sign-in, and that is their only self-service change; after that only an admin can reset it. Researchers can't edit their name, username or organisation.
- **Scope of access:** per researcher, the admin chooses **aggregates only** or **pseudonymous records**, which datasets are included, a date window, an expiry date and CSV download permission. Revoking, resetting or expiring access cuts the researcher off on their next request.
- **Privacy:** patients appear only as codes (`P-7F3AKQ2M`) that differ per researcher. No names, phones, notes or exact ages are shared. Any result describing fewer than *k* patients is hidden; *k* is set by the admin and defaults to 5.
- **Deleting:** deleting a researcher (with a reason) signs them out and moves them to the **Researcher archive**. Their access settings, admin history and activity log stay there for audits. The username can't be reused, and an admin can restore the account.
- **Tracking:** every researcher request is logged (Research activity, with CSV export), as is every admin change to a researcher.
- **Tools:** a cohort builder, descriptive statistics with histograms, trends comparing up to three cohorts, medication adherence against blood pressure, correlation between measures, and the symptom-severity mix over time. All of it runs as SQL inside Postgres.

Setup: add `RESEARCH_PSEUDONYM_SECRET` to `.env` (see `.env.example`), then `docker compose up -d --build`.
See [`research-web/README.md`](./research-web/README.md).
