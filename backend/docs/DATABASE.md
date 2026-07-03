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
