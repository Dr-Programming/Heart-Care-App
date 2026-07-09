# Database & Migrations

PostgreSQL 16. Schema is owned by **Flyway** (`backend/src/main/resources/db/migration/`).
JPA runs with `ddl-auto=validate` — Hibernate never alters the schema. Never edit an applied
migration; add a new `V#__description.sql`.

## Migration Log

### V1 — `create_users`
`users` table: account for each patient.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | `gen_random_uuid()` default; assigned by app (Hibernate UUID strategy) |
| email | VARCHAR(255) UNIQUE NOT NULL | login identifier |
| password_hash | VARCHAR(255) NOT NULL | BCrypt hash |
| full_name | VARCHAR(255) NOT NULL | |
| role | VARCHAR(20) NOT NULL | default `PATIENT`; retained for forward-compat, only `PATIENT` written |
| created_at | TIMESTAMPTZ NOT NULL | default `now()` |

### V2 — `create_patient_profiles`
`patient_profiles` table: one row per patient (1:1 with `users`). `user_id` is both PK and FK to `users(id)` (`ON DELETE CASCADE`, so the profile is deleted with its user). JSONB columns: `comorbidities` (string array) and `goals` (BP/cholesterol/steps/weight/diet object).

| Column | Type | Notes |
|--------|------|-------|
| user_id | UUID PK | FK → `users(id)` `ON DELETE CASCADE` |
| birth_year | INTEGER | year only |
| preferred_language | VARCHAR(5) | `en` / `am` |
| height_cm | INTEGER | for BMI (Vitals slice) |
| chd_stage | VARCHAR(50) | |
| disease_history | TEXT | |
| comorbidities | JSONB NOT NULL | default `[]`; string array |
| management_plan | TEXT | |
| goals | JSONB | nullable |
| created_at | TIMESTAMPTZ NOT NULL | default `now()` |
| updated_at | TIMESTAMPTZ NOT NULL | default `now()` |

### V3 — `create_medications`
`medications` table: one row per medication (many per patient). `user_id` FK → `users(id)`
`ON DELETE CASCADE`. `schedule_times` is a JSONB array of `HH:mm` strings. Soft-deactivated
via `active=false` (never hard-deleted, to preserve dose history). `client_record_id` is a
per-user sync idempotency key (`UNIQUE (user_id, client_record_id)`).

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | app-assigned |
| user_id | UUID NOT NULL | FK → `users(id)` `ON DELETE CASCADE` |
| name | VARCHAR(255) NOT NULL | |
| dose_mg | NUMERIC(8,2) NOT NULL | > 0 |
| frequency | VARCHAR(20) NOT NULL | `ONCE_DAILY` / `BID` / `TID` / `CUSTOM` |
| schedule_times | JSONB NOT NULL | default `[]`; array of `HH:mm` |
| active | BOOLEAN NOT NULL | default `true` |
| client_record_id | UUID | unique per `user_id` |
| created_at | TIMESTAMPTZ NOT NULL | default `now()` |
| updated_at | TIMESTAMPTZ NOT NULL | default `now()` |

### V4 — `create_dose_logs`
`dose_logs` table: append-only event log of dose actions (many per medication). `medication_id`
FK → `medications(id)` and `user_id` FK → `users(id)`, both `ON DELETE CASCADE`. Rows are written
by the device when the patient logs a dose; the server stores and serves them and never computes
"what is due now".

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | app-assigned |
| medication_id | UUID NOT NULL | FK → `medications(id)` `ON DELETE CASCADE` |
| user_id | UUID NOT NULL | FK → `users(id)` `ON DELETE CASCADE` |
| scheduled_date | DATE NOT NULL | the day the dose was due |
| scheduled_time | TIME | nullable (ad-hoc dose) |
| status | VARCHAR(10) NOT NULL | `TAKEN` / `MISSED` / `SKIPPED` |
| logged_at | TIMESTAMPTZ NOT NULL | actual action time |
| note | TEXT | nullable |
| client_record_id | UUID | unique per `user_id` |
| created_at | TIMESTAMPTZ NOT NULL | default `now()` |
