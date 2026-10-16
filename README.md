# Heart-Care-App (Libu Care)

**Project Started:** 2026-04-17

A cross-platform mobile application for managing coronary heart disease (CHD) patients in Ethiopia, developed as a UOW Capstone Project (Project 29).

**Supervised by:** Dr. Elena Vlahu-Gjorgievska & Prof. Khin Than Win
**Client:** Tesema Etefa Birhanu

## About

Heart-Care-App helps patients track and manage their CHD treatment plans. It is offline-first for areas
with limited connectivity and bilingual in English and Amharic.

The system has three kinds of user, each with its own app and its own sign-in:

| User | App | Signs in with |
|---|---|---|
| Patient | Flutter mobile app (`mobile/`) | Ethiopian phone number (`+251…`) + 4-digit PIN |
| Admin | Admin panel (`admin-web/`, http://localhost:3000) | Username + password |
| Researcher | Research app (`research-web/`, http://localhost:3001) | Username + password, issued by an admin |

There is no clinician role and no real-time alerting to clinics. Alerts are evaluated on the phone, and
appointments are the patient's own reminders.

## Repository layout

```
mobile/         Flutter app for patients              -> mobile/README.md
backend/        Spring Boot REST API + Flyway schema  -> backend/README.md
admin-web/      React admin panel                     -> admin-web/README.md
research-web/   React research app                    -> research-web/README.md
system-control-centre/  React monitoring dashboard    -> system-control-centre/README.md
monitoring-api/ Spring Boot API behind the dashboard  -> monitoring/README.md
monitoring/     Prometheus, exporters, JMeter plan    -> monitoring/README.md
docs/           design specs and implementation plans
docker-compose.yml             PostgreSQL + API + both web apps
docker-compose.monitoring.yml  System Control Centre overlay (optional)
```

Other top-level documents: [`ARCHITECTURE.md`](ARCHITECTURE.md), [`FUNCTIONAL_REQUIREMENTS.md`](FUNCTIONAL_REQUIREMENTS.md),
[`PROJECT_STRUCTURE.md`](PROJECT_STRUCTURE.md), [`TEST_SUITE.md`](TEST_SUITE.md), [`TEST_REPORT.md`](TEST_REPORT.md),
[`BUGS_FIXED.md`](BUGS_FIXED.md).

## Tech Stack

- **Mobile:** Flutter (Dart), Android & iOS. Riverpod, go_router, Drift (SQLite), Dio
- **Backend:** Java 21, Spring Boot, Spring Security + JWT, Flyway
- **Database:** PostgreSQL 16 (Docker locally; Railway is the planned host)
- **Admin panel & research app:** React, Vite, TypeScript, TanStack Query, Tailwind CSS, Recharts, served by nginx

## Quick start

Requires Docker, and Flutter for the mobile app.

```bash
# 1. Configure (first time only)
cp .env.example .env
#    then set JWT_SECRET, RESEARCH_PSEUDONYM_SECRET (both: openssl rand -base64 48),
#    POSTGRES_PASSWORD, and ADMIN_USERNAME / ADMIN_PASSWORD (12+ characters)

# 2. Start PostgreSQL, the API and both web apps
docker compose up -d --build

# 3. Run the mobile app on an Android emulator
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

| Service | URL |
|---|---|
| API | http://localhost:8080/api/v1 |
| Admin panel | http://localhost:3000 |
| Research app | http://localhost:3001 |
| PostgreSQL | `localhost:5432` |

The mobile app's server URL is compiled in at build time. Without `--dart-define` it uses the default in
`mobile/lib/core/config/env.dart` (currently an ngrok tunnel). See
[`mobile/README.md`](mobile/README.md#server-url) for emulator, physical-phone and ngrok setups.

### System Control Centre (optional)

A separate monitoring console showing live performance while people use the platform, with a
Demonstration Mode that produces a measured performance report. Set the `MONITORING_DB_PASSWORD` and
`SCC_*` values in `.env`, then:

```bash
docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d --build
```

Open http://localhost:3002. Setup, security notes and load testing: [`monitoring/README.md`](monitoring/README.md).

**"Container name already in use":** the containers have fixed names (`heartcare-postgres`, …). If they
were first created under a different compose project name, `docker compose up` refuses to reuse them.
Start with the original project name to keep the existing database volume, e.g.
`docker compose -p heart-care-app-main up -d --build`. Check the name with
`docker ps -a --format "{{.Names}}\t{{.Label \"com.docker.compose.project\"}}"`.

## Features

### Patients (mobile app)

- Register and sign in with phone + PIN. Change the PIN, or reset a forgotten one through three security
  questions; a patient can also add their own question, kept on that phone. PIN changes made offline sync later.
- Onboarding and profile: CHD stage, health goals, caregiver contact and clinic contact.
- Medications with dose reminders, dose history and adherence.
- Vitals: blood pressure, glucose, heart rate, weight/BMI, cholesterol, with history and trend charts.
- Daily symptom check-in with a severity assessment and recommended action.
- Activity logging, with daily advice on what to do and avoid based on the day's check-in.
- On-device alerts for abnormal readings. Repeated urgent readings prompt the patient to call their clinic.
- Appointments with one-time reminders.
- Visit summary of the last month, exportable as a PDF to show a doctor.
- Health education: topics, healthy-eating guide and quizzes.
- Offline-first sync: everything is saved on the phone first and sent when online. A shared phone can switch
  between patients; it won't sign in another patient while the previous one has unsent records, unless they
  choose to delete them.
- English and አማርኛ.

### Admins (admin panel)

Read-only view of all patient records, triage lists of flagged vitals and urgent check-ins, and full control
of researcher accounts and their access. See [`admin-web/README.md`](admin-web/README.md).

### Researchers (research app)

Anonymised analytics within the limits an admin grants: cohorts, descriptive statistics, trends, outcome
analyses and, when allowed, pseudonymised records and CSV downloads. See
[`research-web/README.md`](research-web/README.md).

## Security and privacy

- Patients, admins and researchers are separate account types in separate tables. A token for one can't
  call another's endpoints.
- Patient sessions use an access token plus a single-use, rotating refresh token (60 days). Reusing a
  refresh token that was already rotated revokes every session from that sign-in.
- PINs, passwords and security answers are stored only as BCrypt hashes. Five wrong PINs lock the account
  for 15 minutes.
- Every admin request is written to the backend log under `admin-audit`. Every researcher request and every
  admin change to a researcher is recorded in the database.
- Researchers see patients only as per-researcher codes (`P-7F3AKQ2M`). Names, phones, notes and exact ages
  are never shared. Results describing fewer than *k* patients are hidden (*k* defaults to 5).

## Status

- **Backend:** complete. Auth (phone + PIN, refresh tokens, forgot PIN), patient profile, medications & dose
  logs, vitals, symptoms, activity, offline sync, admin API and research API. 16 Flyway migrations. See
  [`backend/README.md`](backend/README.md).
- **Mobile:** feature-complete for the patient scope above. See [`mobile/README.md`](mobile/README.md).
- **Admin panel** and **research app:** complete. See their READMEs.

## Testing

```bash
cd backend && mvn test          # requires Docker (Testcontainers)
cd mobile && flutter analyze && flutter test
cd admin-web && npm run build && npm run lint
cd research-web && npm run build && npm run lint
```

Test cases and results: [`TEST_SUITE.md`](TEST_SUITE.md), [`TEST_REPORT.md`](TEST_REPORT.md).
