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
