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
| email | VARCHAR(255) UNIQUE NOT NULL | login identifier — **dropped by V8** |
| password_hash | VARCHAR(255) NOT NULL | BCrypt hash — **dropped by V8** |
| full_name | VARCHAR(255) NOT NULL | |
| role | VARCHAR(20) NOT NULL | default `PATIENT`; retained for forward-compat, only `PATIENT` written |
| created_at | TIMESTAMPTZ NOT NULL | default `now()` |

> V8 replaced the email+password identity columns with phone+PIN. For the current shape of
> `users`, read this table together with [V8](#v8--phone_pin_auth) below.

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

### V5 — `create_vitals_logs`

`vitals_logs` — one row per vital-sign reading.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | app-assigned |
| user_id | UUID NOT NULL | FK → `users(id)` `ON DELETE CASCADE` |
| type | VARCHAR(20) NOT NULL | `BLOOD_PRESSURE` / `GLUCOSE` / `HEART_RATE` / `WEIGHT` / `CHOLESTEROL` |
| vital_values | JSONB NOT NULL | per-type numeric map (`values` is a reserved word, hence `vital_values`); server injects `bmi` for weight |
| flagged | BOOLEAN NOT NULL | default `false`; server-computed clinical alert flag (FR-VIT-008) |
| measured_at | TIMESTAMPTZ NOT NULL | when the reading was taken |
| note | TEXT | nullable |
| client_record_id | UUID | unique per `user_id` (`UNIQUE (user_id, client_record_id)`) |
| created_at | TIMESTAMPTZ NOT NULL | default `now()` |

Indexes: `(user_id, measured_at)`, `(user_id, type)`.

### V6 — `create_symptom_logs`

`symptom_logs` — one row per daily symptom check-in.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | app-assigned |
| user_id | UUID NOT NULL | FK → `users(id)` `ON DELETE CASCADE` |
| data | JSONB NOT NULL | patient-entered fields: `chestPain`, `shortnessOfBreath`, `heartRate`, `bloodPressure`, `swelling`, `energyLevel`, optional `worseThanYesterday` |
| assessment | JSONB NOT NULL | server-computed `{overall, symptoms}` severity snapshot (FR-SYM-010) |
| overall_severity | VARCHAR(20) NOT NULL | queryable snapshot of `assessment.overall` (`NONE` / `MONITOR` / `URGENT` / `EMERGENCY`) |
| measured_at | TIMESTAMPTZ NOT NULL | when the check-in was taken |
| note | TEXT | nullable |
| client_record_id | UUID | unique per `user_id` (`UNIQUE (user_id, client_record_id)`) |
| created_at | TIMESTAMPTZ NOT NULL | default `now()` |

Indexes: `(user_id, measured_at)`, `(user_id, overall_severity)`. Unique constraint:
`uq_symptom_user_client_record` on `(user_id, client_record_id)`.

### V7 — `create_activity_logs`

`activity_logs` — one row per logged physical-activity session. Unlike `vitals_logs`/
`symptom_logs`, this slice computes nothing, so there is **no assessment/severity column**.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | app-assigned |
| user_id | UUID NOT NULL | FK → `users(id)` `ON DELETE CASCADE` |
| data | JSONB NOT NULL | patient-entered fields: `type`, `durationMinutes`, `intensity`, optional `steps`, `distanceMeters` |
| measured_at | TIMESTAMPTZ NOT NULL | when the session happened |
| note | TEXT | nullable |
| client_record_id | UUID | unique per `user_id` (`UNIQUE (user_id, client_record_id)`) |
| created_at | TIMESTAMPTZ NOT NULL | default `now()` |

Index: `idx_activity_user_measured` on `(user_id, measured_at)`. Unique constraint:
`uq_activity_user_client_record` on `(user_id, client_record_id)`.

### Slice 7 — Sync engine: no migration

`POST /api/v1/sync` (Slice 7) added **no migration of its own**. It reuses the `UNIQUE (user_id,
client_record_id)` constraint already present on `medications`, `dose_logs`, `vitals_logs`,
`symptom_logs`, and `activity_logs` (V3–V7 above) as its entire deduplication mechanism. (`V8`
below belongs to the later auth rework, not to sync.)

`sync_queue` is **not** a PostgreSQL table. It is a device-side Drift/SQLite table tracking what
a given phone still owes the server (`PENDING` / `SYNCING` / `SYNCED`) — inherently local state,
since a second device would have a different queue for the same patient. See
`docs/design/2026-07-17-sync-design.md`, Decision 1.

### V8 — `phone_pin_auth`

Swaps the identity columns on `users`: email+password out, phone + 4-digit PIN in, plus the two
columns that back the login lockout. No other table changes.

| Column | Type | Notes |
|--------|------|-------|
| phone | VARCHAR(20) UNIQUE NOT NULL | login identifier; `+251` + 9 digits (`users_phone_key`) |
| pin_hash | VARCHAR(255) NOT NULL | BCrypt hash of the 4-digit PIN |
| preferred_language | VARCHAR(2) NOT NULL | default `en`; `en` / `am` |
| failed_login_attempts | INTEGER NOT NULL | default `0`; consecutive failures, cleared on success |
| locked_until | TIMESTAMPTZ | nullable; while in the future, login returns `423` |

Dropped: `email`, `password_hash`.

The migration **truncates `users` first**, cascading to every log table. This is not incidental:
`phone` is `UNIQUE NOT NULL` and no phone number was ever collected, so no backfill value exists.
The app was pre-release with no production users when V8 was written; any local or Railway dev
data is lost on upgrade and must be re-registered.

`preferred_language` now exists on both `users` (set at registration, drives the app's UI language)
and `patient_profiles` (V2). The `users` copy is the one auth reads and returns.
