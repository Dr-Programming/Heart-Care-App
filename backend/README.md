# Heart-Care Backend

Spring Boot REST API for the Heart-Care App (patient-only scope). Offline-first companion to the Flutter mobile app: the device is the source of truth; this API persists synced records and handles auth.

## Tech Stack
- Java 21 · Spring Boot 4.1.0 · Maven
- PostgreSQL 16 (Docker for local dev) · Flyway migrations
- Spring Security + JWT (jjwt) · BCrypt
- Testcontainers + JUnit 5

## Quick Start
```bash
# 1. Start PostgreSQL (from repo root)
cp .env.example .env        # first time only — fill in overrides + JWT_SECRET
docker compose up -d

# 2. Run the API (from backend/)
cd backend
mvn spring-boot:run         # serves on http://localhost:8080

# 3. Run tests (requires Docker for Testcontainers)
mvn test
```

## Build Progress

| # | Slice | Status |
|---|-------|--------|
| 1 | Foundation + Auth (scaffold, Docker DB, JWT security, register/login/me) | ✅ Done |
| 2 | Patient profile (GET/PUT /patients/me, profile + goals JSONB) | ✅ Done |
| 3 | Medications & dose logs (CRUD + Taken/Missed/Skipped logging, JSONB schedule) | ✅ Done |
| 4 | Vitals | ⬜ Not started |
| 5 | Symptoms | ⬜ Not started |
| 6 | Activity | ⬜ Not started |
| 7 | Sync engine | ⬜ Not started |

## Documentation
- [API reference](docs/API.md)
- [Database & migrations](docs/DATABASE.md)
- [Development guide](docs/DEVELOPMENT.md)
