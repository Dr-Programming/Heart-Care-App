# Development Guide

## Prerequisites
- Java 21, Maven 3.9+, Docker (running).

## Local stack (Docker)
From the repo root:
```bash
docker compose up -d --build   # postgres:16 on localhost:5432 + the API on localhost:8080
docker compose logs -f backend # follow API logs
docker compose down            # stop both
```
The API needs `JWT_SECRET`, which has no default anywhere: copy `.env.example` to `.env` and set it.
Without it the `backend` container exits at startup. `docker-compose.yml` supplies `heartcare` as the
default db, user, and password, so those can stay unset. Inside the compose network the API reaches
the database as `postgres:5432`, via `SPRING_DATASOURCE_URL` overriding `application-dev.yml`.

`--build` is needed after backend code changes; the image does not rebuild on its own.

## Running & testing on the host
```bash
docker compose up -d postgres                   # database only; works without a .env
cd backend
export JWT_SECRET=$(openssl rand -base64 48)    # mvn does not read .env
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
