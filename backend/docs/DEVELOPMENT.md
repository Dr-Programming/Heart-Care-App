# Development Guide

## Prerequisites
- Java 21, Maven 3.9+, Docker (running).

## Local database
From the repo root:
```bash
docker compose up -d      # starts postgres:16 on localhost:5432 — works out of the box
docker compose down       # stop
```
`docker compose up -d` works without a `.env` file; `docker-compose.yml` supplies `heartcare` as the
default db, user, and password. Copy `.env.example` to `.env` only when you want to override those
values or set a strong `JWT_SECRET` for a shared/production environment.

## Running & testing
```bash
cd backend
mvn spring-boot:run                             # run API (profile: dev)
mvn test                                        # all tests (uses Testcontainers → needs Docker)
mvn test -Dtest=AuthControllerIntegrationTest   # single test class
```

## Configuration
- `application.yml` — base config; `app.jwt.secret` / `app.jwt.expiration-ms`.
- `application-dev.yml` — local datasource (active by default); falls back to `heartcare` credentials if env vars are unset.
- Secrets come from env vars (`JWT_SECRET`, `POSTGRES_*`); never commit a real `.env` or `application-prod.yml`.

## Package conventions (package-by-feature, `com.heartcare`)
- `common/` — shared infra (response envelope, exceptions, security, config).
- `<feature>/` — controller, service, repository, `model/`, `dto/` for that feature only.
- Features never import each other directly; DTOs never leave their feature package.
- All routes under `/api/v1`.
