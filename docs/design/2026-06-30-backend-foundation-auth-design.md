# Backend Design — Patient-Only Architecture & Slice 1 (Foundation + Auth)

**Project:** Heart-Care App (UOW Capstone — Project 29)
**Date:** 2026-06-30
**Status:** Approved for implementation planning
**Scope of this spec:** Overall patient-only backend architecture, the build sequence, the documentation plan, and the detailed design of **Slice 1 — Foundation + Auth**. Later slices each get their own spec/plan.

---

## 1. Context & Scope Decisions

The backend is a **Spring Boot REST API** for the Heart-Care offline-first mobile app. Because the app is offline-first, **the device is the source of truth**; the backend persists records that the device syncs up. The original `ARCHITECTURE.md` described a richer system (clinician role, real-time alerts, appointments), but `FUNCTIONAL_REQUIREMENTS.md` annotations and a scope review have narrowed the backend MVP.

### In scope (backend MVP)
- Auth — patient registration + login, JWT issuance.
- Patient profile + goals.
- Medications + dose logs.
- Vitals (BP, glucose, HR, weight).
- Symptoms (daily check-in).
- Activity logging (P2).
- Offline batch **sync** endpoint with idempotency.

### Dropped / deferred (confirmed)
- **Clinician module** — dropped (`FR-AUTH-010`, §12 "TO BE DROPPED").
- **Real-time alerts / WebSocket / STOMP** — dropped. Alert-threshold evaluation lives **on-device** (`FR-DEC-011`: decision support must work offline).
- **Appointments** (§13) — dropped from backend.
- **Education / Diet content** — bundled on device; backend CMS "voided" (`FR-EDU-012`).
- **Admin role** — P4, not built.
- **Password reset** (`FR-AUTH-008`, P2) — needs email; deferred.
- **Logout** (`FR-AUTH-007`) — client-side token clear; JWT is stateless, no backend endpoint.

### Forward-compat notes
- `users.role` column is retained (default `PATIENT`) so a clinician/admin role can be added later without a destructive migration, but **no role-gated endpoints exist** in the MVP.

---

## 2. Tech Stack & Versions

| Component | Choice | Notes |
|---|---|---|
| Language/runtime | **Java 21 (LTS)** | Installed: 21.0.9 |
| Framework | **Spring Boot 4.1.0** | Latest stable; Java 17 baseline, Java 21 fully supported. Pulls in **Spring Framework 7 / Spring Security 7** → use current lambda security DSL. |
| Build | **Maven 3.9.x** | Installed: 3.9.14 |
| DB (dev + prod) | **PostgreSQL 16** | Dev via Docker Compose; prod on Railway |
| Migrations | **Flyway** | `V1__`…; never edit an applied migration |
| ORM | Spring Data JPA / Hibernate | `ddl-auto=validate` (Flyway owns schema) |
| Auth | Spring Security + **jjwt** (`io.jsonwebtoken`) | HS256, BCrypt password hashing |
| Validation | Bean Validation (Jakarta) | DTO-level constraints |
| Test | Spring Boot Test, JUnit 5, Mockito, **Testcontainers (PostgreSQL)** | Real-Postgres integration tests |

---

## 3. Overall Backend Architecture

**Package-by-feature** under `com.heartcare`, with a shared `common/` package for cross-cutting infrastructure. Structure follows `PROJECT_STRUCTURE.md §2`.

### Structural rules (from PROJECT_STRUCTURE.md §5)
1. Features never import from each other directly — cross-feature needs go through `common/` or a service interface.
2. DTOs never leave their feature package — `sync/` passes raw payloads to feature services via clean method calls, not by constructing other features' DTOs.
3. All paths/URLs configured in `application.yml`, never hardcoded in classes.

### Conventions
- **Base path:** `/api/v1`.
- **Response envelope** (`ARCHITECTURE.md §11`):
  ```json
  { "success": true, "data": {}, "message": "OK", "timestamp": "2026-06-30T10:00:00Z" }
  ```
  Implemented as `common/response/ApiResponse<T>`. Errors are wrapped in the same envelope by `GlobalExceptionHandler`.
- **Idempotent writes:** every record-creating endpoint (from Slice 3 on) accepts a client-generated `clientRecordId` (UUID); duplicates are silently ignored.

---

## 4. Build Sequence

Each slice is an independently runnable, testable vertical. Each gets its own implementation plan and ends by updating the backend docs.

| # | Slice | Delivers | Flyway |
|---|---|---|---|
| **1** | **Foundation + Auth** | Spring Boot scaffold, Docker Postgres, `common/` (envelope, exceptions, Security + JWT), patient register/login → JWT, secured `/auth/me` probe | `V1__users` |
| 2 | Patient profile | `GET/PUT /patients/me`, profile + goals (JSONB) | `V2__patients` |
| 3 | Medications & dose logs | medication CRUD, dose logging, adherence calc | `V3`, `V4` |
| 4 | Vitals | BP/glucose/HR/weight logging + history | `V5` |
| 5 | Symptoms | daily check-in records | `V6` |
| 6 | Activity (P2) | activity logging | `V7` |
| 7 | **Sync engine** | `POST /sync` batch, idempotency via `client_record_id`, routes records to each feature service | — |

**Rationale:** Slice 1 proves the full stack (DB → migration → JWT-secured request) before any feature exists. Sync is last because it depends on every feature service already existing.

---

## 5. Documentation Plan (maintained continuously)

| File | Purpose | Updated |
|---|---|---|
| `backend/README.md` | Entry point: overview, quick-start (run/build/test), **build-progress checklist** of the 7 slices with status | Every slice |
| `backend/docs/API.md` | REST contract — method, path, auth, request/response envelope per endpoint | When endpoints change |
| `backend/docs/DATABASE.md` | Schema + Flyway migration log (table descriptions, what each `V#` added) | Each migration |
| `backend/docs/DEVELOPMENT.md` | Local setup (Docker DB, env vars), run/test commands, package conventions | When workflow changes |

Every slice's implementation plan ends with an "**update docs**" step so README progress + API/DATABASE stay in lockstep with code.

---

## 6. Slice 1 — Foundation + Auth (detailed design)

### 6.1 Package layout
```
com.heartcare
├── HeartCareApplication.java          @SpringBootApplication entry point
├── common/
│   ├── config/
│   │   ├── SecurityConfig.java        stateless filter chain, BCrypt, route gating
│   │   └── CorsConfig.java            CORS for Flutter client (dev: localhost)
│   ├── security/
│   │   ├── JwtTokenProvider.java      create / validate / parse JWT (HS256)
│   │   ├── JwtAuthFilter.java         OncePerRequestFilter → SecurityContext
│   │   └── UserPrincipal.java         authenticated user wrapper
│   ├── exception/
│   │   ├── GlobalExceptionHandler.java  @RestControllerAdvice
│   │   ├── ResourceNotFoundException.java
│   │   ├── UnauthorizedException.java
│   │   └── ValidationException.java
│   └── response/
│       └── ApiResponse.java           { success, data, message, timestamp }
└── auth/
    ├── AuthController.java             POST /auth/register, /auth/login; GET /auth/me
    ├── AuthService.java                register, login, load current user
    ├── UserRepository.java             extends JpaRepository<User, UUID>
    ├── model/User.java                 @Entity
    └── dto/
        ├── RegisterRequest.java        { fullName, email, password }
        ├── LoginRequest.java           { email, password }
        └── AuthResponse.java           { token, userId, role }
```

### 6.2 Migration `V1__create_users.sql`
```sql
CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(255) NOT NULL,
    role          VARCHAR(20)  NOT NULL DEFAULT 'PATIENT',
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);
```
- `gen_random_uuid()` is built into PostgreSQL 13+ (no extension needed).
- `role` retained for forward-compat; registration only ever writes `PATIENT`.

### 6.3 Endpoints (base `/api/v1`)

| Method | Path | Auth | Request | Response (`data`) | Req |
|---|---|---|---|---|---|
| POST | `/auth/register` | Public | `{fullName,email,password}` | `{token,userId,role}` (auto-login) | FR-AUTH-001 |
| POST | `/auth/login` | Public | `{email,password}` | `{token,userId,role}` | FR-AUTH-002/004 |
| GET | `/auth/me` | Bearer JWT | — | `{userId,fullName,email,role}` | secured probe |

- All responses use the `ApiResponse` envelope.
- `register` returns a token immediately (auto-login UX), reducing one round trip on slow networks.
- Duplicate email on register → `409 Conflict` via `GlobalExceptionHandler`.
- Bad credentials on login → `401 Unauthorized`, generic message (no user-enumeration leak).

### 6.4 JWT
- Library: `io.jsonwebtoken:jjwt`. Algorithm **HS256**.
- Claims: `sub = userId`, `role`, `iat`, `exp = iat + 7 days` (`FR-AUTH-004`).
- Secret: `app.jwt.secret` in `application.yml`; **prod overrides via env var** (`JWT_SECRET`), never committed.
- `JwtAuthFilter` extracts `Authorization: Bearer <token>`, validates signature + expiry, builds `UserPrincipal`, sets `SecurityContext` with authority `ROLE_PATIENT`. Invalid/expired token → request proceeds unauthenticated → 401 on protected routes.

### 6.5 Security config (Spring Security 7 lambda DSL)
- Stateless session (`SessionCreationPolicy.STATELESS`).
- CSRF disabled (token-based API).
- `BCryptPasswordEncoder` bean.
- Authorization: `permitAll` on `/api/v1/auth/register` and `/api/v1/auth/login`; `authenticated()` for everything else.
- `JwtAuthFilter` registered before `UsernamePasswordAuthenticationFilter`.
- CORS: dev allows `localhost` origins; prod origins configured via property.

### 6.6 Configuration
- `application.yml` — `server.port=8080`, `spring.jpa.hibernate.ddl-auto=validate`, Flyway enabled, `app.jwt.secret` / `app.jwt.expiration` placeholders.
- `application-dev.yml` — datasource → Docker Postgres (`jdbc:postgresql://localhost:5432/heartcare`), dev credentials, dev JWT secret. **Active by default for local dev.**
- `docker-compose.yml` (repo root) — PostgreSQL 16 service (db `heartcare`, port 5432, named volume, healthcheck) + optional pgAdmin.
- `.env.example` (repo root) — `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `JWT_SECRET`. Real `.env` is gitignored.

> **Discrepancy to fix:** `CLAUDE.md` references `docs/docker-compose.yml`; this design places it at **repo root** per `PROJECT_STRUCTURE.md`. The stale `CLAUDE.md` command reference will be corrected.

### 6.7 Testing strategy (TDD)
- **`AuthServiceTest`** (unit, mocked `UserRepository` + encoder):
  - registration hashes the password (never stores plaintext);
  - duplicate email is rejected;
  - login with wrong password fails;
  - successful login/register issues a JWT carrying the correct `sub` + `role`.
- **`AuthIntegrationTest`** (`@SpringBootTest` + Testcontainers PostgreSQL, MockMvc):
  - register → 200 + token;
  - login → 200 + token;
  - `GET /auth/me` with token → 200 + correct user;
  - `GET /auth/me` without/with invalid token → 401.
- Migrations run against the Testcontainer to validate `V1` on real Postgres.

### 6.8 Slice 1 "done" criteria
- `docker compose up -d` starts Postgres; `mvn spring-boot:run` boots, Flyway applies `V1`.
- register → login → `/auth/me` works end-to-end; unauthenticated `/auth/me` returns 401.
- `mvn test` green (unit + integration).
- `backend/README.md`, `docs/API.md`, `docs/DATABASE.md`, `docs/DEVELOPMENT.md` created and reflecting Slice 1.

---

## 7. Out of Scope for Slice 1
- Any feature module beyond auth (patient/medication/vitals/symptoms/activity/sync) — later slices.
- Production `application-prod.yml` / Railway deployment config — added near release.
- Rate limiting, refresh tokens, token revocation — not in MVP.
