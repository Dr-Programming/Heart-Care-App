# Heart-Care Backend

Spring Boot REST API for the Heart-Care App. It serves three separate clients: the Flutter patient app,
the admin panel (`admin-web`) and the research app (`research-web`). For patients it is the offline-first
companion to the phone: the device is the source of truth, and this API persists synced records and
handles auth.

## Tech Stack
- Java 21 · Spring Boot 4.1.0 · Maven
- PostgreSQL 16 (Docker for local dev) · Flyway migrations
- Spring Security + JWT (jjwt) · BCrypt
- Testcontainers + JUnit 5

## Quick Start
```bash
# 1. Start PostgreSQL + the API in Docker (from repo root)
cp .env.example .env        # first time only — set the variables below
docker compose up -d --build   # API on http://localhost:8080, DB on localhost:5432

# 2. Run tests (from backend/, requires Docker for Testcontainers)
cd backend
mvn test
```

To run the API on the host instead (IDE debugging, faster edit loop), start only the database and
export the secrets yourself — `mvn` does not read `.env`:

```bash
docker compose up -d postgres
cd backend
export JWT_SECRET=$(openssl rand -base64 48)
export RESEARCH_PSEUDONYM_SECRET=$(openssl rand -base64 48)
mvn spring-boot:run
```

Check it is up: `curl http://localhost:8080/api/v1/health`.

## Configuration

Set in the repo-root `.env` (template: `.env.example`).

| Variable | Required | Purpose |
|---|---|---|
| `JWT_SECRET` | Yes, 32+ bytes | Signs all access tokens. The API refuses to start without it. |
| `RESEARCH_PSEUDONYM_SECRET` | Yes, 32+ bytes | HMAC key for the patient codes researchers see. Keep it stable: changing it gives every patient a new code. |
| `POSTGRES_DB` / `POSTGRES_USER` / `POSTGRES_PASSWORD` | No (default `heartcare`) | Database credentials. |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | No | Creates the admin account on startup if it doesn't exist; never overwrites it. Password must be 12+ characters. |
| `CORS_ALLOWED_ORIGINS` | No (default `http://localhost:*`) | Browser origins allowed to call the API. Native mobile clients are unaffected. |

## API areas

All under `/api/v1`. Each area has its own principal type; a token for one can't call another's endpoints.

| Prefix | Client | Sign-in |
|---|---|---|
| `/auth`, `/patients`, `/medications`, `/dose-logs`, `/vitals`, `/symptoms`, `/activities`, `/sync` | Mobile app | Phone + PIN (`/auth/login`) |
| `/admin/**` | Admin panel | `/admin/auth/login`, 8-hour token |
| `/research/**` | Research app | `/research/auth/login` |
| `/health` | Anyone | — |

## Build Progress

| # | Slice | Status |
|---|-------|--------|
| 1 | Foundation + Auth (scaffold, Docker DB, JWT security, register/login/me) | ✅ Done |
| 2 | Patient profile (GET/PUT /patients/me, profile + goals JSONB) | ✅ Done |
| 3 | Medications & dose logs (CRUD + Taken/Missed/Skipped logging, JSONB schedule) | ✅ Done |
| 4 | Vitals (BP/glucose/heart-rate/weight+BMI/cholesterol logging, server-computed flag, JSONB values) | ✅ Done |
| 5 | Symptoms (daily check-in: chest pain/SOB/HR/BP/swelling/energy, server-computed severity assessment, JSONB data) | ✅ Done |
| 6 | Activity (log physical-activity sessions: type/duration/intensity + optional steps/distance, JSONB data) | ✅ Done |
| 7 | Sync engine (batched offline sync, `POST /api/v1/sync`, per-record SAVED/DUPLICATE/CONFLICT/REJECTED outcomes) | ✅ Done |
| 8 | Phone+PIN auth rework (`+251…` phone + 4-digit PIN replaces email+password, `V8`, 5-try/15-min account lockout closing SecurityReview M-1) | ✅ Done |
| 9 | Admin API (separate `admin_users`, bootstrap account, read-only patient data, flagged vitals / urgent symptoms, `admin-audit` log, `V9`) | ✅ Done |
| 10 | Research API (researcher accounts and grants, per-researcher pseudonyms, minimum group size, cohorts and analytics in SQL, activity log, archive, `V10`–`V11`) | ✅ Done |
| 11 | Test-report fixes (medication `deactivated_at`, one symptom check-in per local day via `X-Timezone`, `V12`–`V13`) | ✅ Done |
| 12 | Sessions and PIN recovery (rotating refresh tokens, forgot PIN via security questions, offline-safe PIN change with `changeId`, `V14`–`V16`) | ✅ Done |

## Documentation
- [API reference](docs/API.md) — patient-facing endpoints (auth, profile, medications, dose logs, vitals, symptoms, activity, sync)
- [Database & migrations](docs/DATABASE.md)
- [Development guide](docs/DEVELOPMENT.md)
- [Security review](docs/SecurityReview.md)
