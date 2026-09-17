# Heart-Care App — Project Structure

**Project:** Heart-Care App (UOW Capstone — Project 29)  
**Document Owner:** Developing Team  
**Last Updated:** 14 April 2026

---

## Overview

The project is organised as a **monorepo** — one Git repository containing both the Flutter mobile app and the Spring Boot backend as separate top-level folders. Documentation and shared assets live at the root level. Nothing from the frontend bleeds into the backend and vice versa.

```
heart-care-app/                        ← Git repository root
│
├── mobile/                            ← Flutter app (Android + iOS)
├── backend/                           ← Spring Boot API
├── database/                          ← Schema, migrations, seed data
├── docs/                              ← All project documentation
└── README.md                          ← Project overview & setup guide
```

---

## Root Level

```
heart-care-app/
│
├── mobile/                            ← Flutter frontend
├── backend/                           ← Spring Boot backend
├── database/                          ← Schema, migrations & seed data (see Section 3)
│
├── docker-compose.yml                 ← Spins up PostgreSQL + pgAdmin for local dev
├── .env.example                       ← Credential template — COMMITTED (no real secrets)
├── .env                               ← Actual local credentials — GITIGNORED
│
├── docs/                              ← Project documentation
│   ├── ARCHITECTURE.md
│   ├── FUNCTIONAL_REQUIREMENTS.md
│   ├── PROJECT_STRUCTURE.md           ← this file
│   ├── api/                           ← API contracts & Postman collections
│   │   └── heartcare-api.postman_collection.json
│   └── diagrams/                      ← Architecture & flow diagrams
│       ├── system-architecture.png
│       └── db-schema.png
│
└── README.md                          ← How to clone, run, and contribute
```

---

## 1. Flutter App — `mobile/`

The Flutter app follows **Feature-First Clean Architecture**. Each feature of the app is a self-contained folder with its own data layer, domain layer, and presentation layer. Nothing is dumped into a single global `models/` or `screens/` folder — that approach becomes impossible to navigate past a dozen screens.

### Why Feature-First?

A flat structure like `screens/`, `models/`, `widgets/` forces every developer to touch the same folders constantly, causing merge conflicts and making it hard to find what belongs to what. Feature-first means the medication developer works entirely inside `features/medication/` and never collides with the vitals developer working in `features/vitals/`.

```
mobile/
│
├── android/                           ← Android-specific config (auto-generated)
├── ios/                               ← iOS-specific config (auto-generated)
├── assets/                            ← Static files bundled into the app
│   ├── content/                       ← Offline education content (JSON/Markdown)
│   │   ├── chd_facts_en.json
│   │   ├── chd_facts_am.json          ← Amharic version
│   │   ├── diet_guide_en.json
│   │   ├── diet_guide_am.json
│   │   ├── activity_guide_en.json
│   │   └── medication_education_en.json
│   ├── images/                        ← App images and illustrations
│   │   ├── logo.png
│   │   └── onboarding/
│   └── translations/                  ← Localisation strings
│       ├── en.json
│       └── am.json                    ← Amharic translations
│
├── lib/
│   │
│   ├── main.dart                      ← App entry point, DI setup, routing init
│   │
│   ├── core/                          ← Shared code used across ALL features
│   │   ├── constants/
│   │   │   ├── app_colors.dart        ← Colour palette constants
│   │   │   ├── app_strings.dart       ← Static string keys
│   │   │   └── api_endpoints.dart     ← All API URL constants
│   │   │
│   │   ├── theme/
│   │   │   └── app_theme.dart         ← Global MaterialApp theme
│   │   │
│   │   ├── network/
│   │   │   ├── dio_client.dart        ← Dio HTTP client with interceptors
│   │   │   ├── auth_interceptor.dart  ← Attaches JWT to every request
│   │   │   └── connectivity_service.dart ← Detects online/offline state
│   │   │
│   │   ├── database/
│   │   │   ├── app_database.dart      ← Drift database definition (all tables)
│   │   │   └── sync_queue_dao.dart    ← Sync queue data access object
│   │   │
│   │   ├── sync/
│   │   │   └── sync_service.dart      ← Background sync engine
│   │   │
│   │   ├── notifications/
│   │   │   └── notification_service.dart ← Local push notifications setup
│   │   │
│   │   ├── storage/
│   │   │   └── secure_storage.dart    ← JWT token read/write (encrypted)
│   │   │
│   │   ├── error/
│   │   │   ├── failures.dart          ← Sealed failure classes
│   │   │   └── exceptions.dart        ← Custom exception types
│   │   │
│   │   ├── utils/
│   │   │   ├── date_formatter.dart
│   │   │   ├── validators.dart        ← Form field validators
│   │   │   └── alert_evaluator.dart   ← Clinical threshold checks (offline)
│   │   │
│   │   └── widgets/                   ← Reusable UI components
│   │       ├── app_button.dart
│   │       ├── app_text_field.dart
│   │       ├── metric_card.dart       ← Dashboard stat card
│   │       ├── trend_chart.dart       ← Reusable fl_chart wrapper
│   │       └── loading_overlay.dart
│   │
│   └── features/                      ← One folder per app feature
│       │
│       ├── auth/                      ← Login, Register, Role selection
│       │   ├── data/
│       │   │   ├── models/
│       │   │   │   └── user_model.dart
│       │   │   ├── datasources/
│       │   │   │   └── auth_remote_datasource.dart
│       │   │   └── repositories/
│       │   │       └── auth_repository_impl.dart
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   │   └── user.dart
│       │   │   ├── repositories/
│       │   │   │   └── auth_repository.dart     ← abstract interface
│       │   │   └── usecases/
│       │   │       ├── login_usecase.dart
│       │   │       └── register_usecase.dart
│       │   └── presentation/
│       │       ├── screens/
│       │       │   ├── login_screen.dart
│       │       │   └── register_screen.dart
│       │       ├── widgets/
│       │       │   └── auth_form_field.dart
│       │       └── providers/
│       │           └── auth_provider.dart
│       │
│       ├── profile/                   ← Personal patient profile & goals
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       │
│       ├── education/                 ← CHD facts, diet, activity, quiz
│       │   ├── data/
│       │   │   └── datasources/
│       │   │       └── education_local_datasource.dart  ← reads bundled JSON
│       │   ├── domain/
│       │   └── presentation/
│       │       └── screens/
│       │           ├── education_home_screen.dart
│       │           ├── chd_facts_screen.dart
│       │           ├── diet_guide_screen.dart
│       │           ├── activity_guide_screen.dart
│       │           └── quiz_screen.dart
│       │
│       ├── medication/                ← Med list, add med, log dose, reminders
│       │   ├── data/
│       │   │   ├── models/
│       │   │   │   ├── medication_model.dart
│       │   │   │   └── dose_log_model.dart
│       │   │   ├── datasources/
│       │   │   │   ├── medication_local_datasource.dart   ← Drift
│       │   │   │   └── medication_remote_datasource.dart  ← Spring Boot API
│       │   │   └── repositories/
│       │   │       └── medication_repository_impl.dart
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   ├── repositories/
│       │   │   └── usecases/
│       │   │       ├── add_medication_usecase.dart
│       │   │       ├── log_dose_usecase.dart
│       │   │       └── get_adherence_usecase.dart
│       │   └── presentation/
│       │       ├── screens/
│       │       │   ├── medication_list_screen.dart
│       │       │   ├── add_medication_screen.dart
│       │       │   └── dose_history_screen.dart
│       │       ├── widgets/
│       │       │   ├── medication_card.dart
│       │       │   └── dose_status_chip.dart
│       │       └── providers/
│       │           └── medication_provider.dart
│       │
│       ├── symptoms/                  ← Daily symptom check-in & history
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       │
│       ├── vitals/                    ← BP, glucose, HR, weight logging
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       │       └── screens/
│       │           ├── log_vitals_screen.dart
│       │           └── vitals_history_screen.dart
│       │
│       ├── activity/                  ← Physical activity log & guidance
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       │
│       ├── dashboard/                 ← Risk-factor summary & trend charts
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       │       └── screens/
│       │           ├── dashboard_screen.dart
│       │           └── trend_charts_screen.dart
│       │
│       ├── appointments/              ← Follow-up scheduling & reminders
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       │
│       └── clinician/                 ← Clinician-only: patient list, alerts
│           ├── data/
│           ├── domain/
│           └── presentation/
│               └── screens/
│                   ├── patient_list_screen.dart
│                   ├── patient_detail_screen.dart
│                   └── alerts_screen.dart
│
├── test/                              ← Flutter unit & widget tests
│   ├── core/
│   └── features/
│       ├── auth/
│       ├── medication/
│       └── vitals/
│
└── pubspec.yaml                       ← Flutter dependencies
```

---

## 2. Spring Boot Backend — `backend/`

The backend follows **Package-by-Feature** structure rather than the classic Package-by-Layer (`controllers/`, `services/`, `repositories/` at the root). Package-by-layer forces you to jump between three folders every time you work on one feature. Package-by-feature keeps everything for one domain (e.g., `medication`) together.

A `common/` package holds shared infrastructure — security config, exception handling, base response wrappers — that all features use.

```
backend/
│
├── src/
│   ├── main/
│   │   ├── java/com/heartcare/
│   │   │   │
│   │   │   ├── HeartCareApplication.java      ← Spring Boot entry point (@SpringBootApplication)
│   │   │   │
│   │   │   ├── common/                        ← Shared infrastructure (not a feature)
│   │   │   │   ├── config/
│   │   │   │   │   ├── SecurityConfig.java    ← Spring Security + JWT filter chain
│   │   │   │   │   ├── WebSocketConfig.java   ← STOMP WebSocket endpoint config
│   │   │   │   │   └── CorsConfig.java        ← CORS settings for Flutter client
│   │   │   │   │
│   │   │   │   ├── security/
│   │   │   │   │   ├── JwtTokenProvider.java  ← Generate, validate, parse JWT
│   │   │   │   │   ├── JwtAuthFilter.java     ← Intercepts every request, sets SecurityContext
│   │   │   │   │   └── UserPrincipal.java     ← Authenticated user details wrapper
│   │   │   │   │
│   │   │   │   ├── exception/
│   │   │   │   │   ├── GlobalExceptionHandler.java  ← @ControllerAdvice for all errors
│   │   │   │   │   ├── ResourceNotFoundException.java
│   │   │   │   │   ├── UnauthorizedException.java
│   │   │   │   │   └── ValidationException.java
│   │   │   │   │
│   │   │   │   ├── response/
│   │   │   │   │   └── ApiResponse.java       ← Standard { success, data, message, timestamp }
│   │   │   │   │
│   │   │   │   └── alert/
│   │   │   │       └── AlertEvaluatorService.java  ← Clinical threshold checks (BP, HR, glucose)
│   │   │   │
│   │   │   ├── auth/                          ← Register, login, JWT issuance
│   │   │   │   ├── AuthController.java        ← POST /api/v1/auth/login, /register
│   │   │   │   ├── AuthService.java
│   │   │   │   ├── AuthRepository.java        ← extends JpaRepository<User, UUID>
│   │   │   │   ├── model/
│   │   │   │   │   └── User.java              ← @Entity: id, email, passwordHash, role
│   │   │   │   └── dto/
│   │   │   │       ├── LoginRequest.java
│   │   │   │       ├── RegisterRequest.java
│   │   │   │       └── AuthResponse.java      ← { token, role, userId }
│   │   │   │
│   │   │   ├── patient/                       ← Patient profile & goals
│   │   │   │   ├── PatientController.java     ← GET/PUT /api/v1/patients/me
│   │   │   │   ├── PatientService.java
│   │   │   │   ├── PatientRepository.java
│   │   │   │   ├── model/
│   │   │   │   │   └── Patient.java
│   │   │   │   └── dto/
│   │   │   │       ├── PatientProfileRequest.java
│   │   │   │       └── PatientProfileResponse.java
│   │   │   │
│   │   │   ├── medication/                    ← Medications & dose logs
│   │   │   │   ├── MedicationController.java  ← /api/v1/medications
│   │   │   │   ├── DoseLogController.java     ← /api/v1/dose-logs
│   │   │   │   ├── MedicationService.java
│   │   │   │   ├── DoseLogService.java
│   │   │   │   ├── MedicationRepository.java
│   │   │   │   ├── DoseLogRepository.java
│   │   │   │   ├── model/
│   │   │   │   │   ├── Medication.java
│   │   │   │   │   └── DoseLog.java           ← clientRecordId UNIQUE for idempotency
│   │   │   │   └── dto/
│   │   │   │       ├── MedicationRequest.java
│   │   │   │       ├── DoseLogRequest.java
│   │   │   │       └── AdherenceResponse.java
│   │   │   │
│   │   │   ├── vitals/                        ← BP, glucose, HR, weight logs
│   │   │   │   ├── VitalsController.java      ← POST /api/v1/vitals
│   │   │   │   ├── VitalsService.java         ← calls AlertEvaluatorService after save
│   │   │   │   ├── VitalsRepository.java
│   │   │   │   ├── model/
│   │   │   │   │   └── VitalsLog.java
│   │   │   │   └── dto/
│   │   │   │       ├── VitalsRequest.java
│   │   │   │       └── VitalsResponse.java
│   │   │   │
│   │   │   ├── symptoms/                      ← Daily symptom check-ins
│   │   │   │   ├── SymptomController.java     ← POST /api/v1/symptoms
│   │   │   │   ├── SymptomService.java
│   │   │   │   ├── SymptomRepository.java
│   │   │   │   ├── model/
│   │   │   │   │   └── SymptomLog.java
│   │   │   │   └── dto/
│   │   │   │       └── SymptomRequest.java
│   │   │   │
│   │   │   ├── activity/                      ← Physical activity logs
│   │   │   │   ├── ActivityController.java
│   │   │   │   ├── ActivityService.java
│   │   │   │   ├── ActivityRepository.java
│   │   │   │   ├── model/
│   │   │   │   │   └── ActivityLog.java
│   │   │   │   └── dto/
│   │   │   │       └── ActivityRequest.java
│   │   │   │
│   │   │   ├── appointment/                   ← Follow-up appointments
│   │   │   │   ├── AppointmentController.java ← /api/v1/appointments
│   │   │   │   ├── AppointmentService.java
│   │   │   │   ├── AppointmentRepository.java
│   │   │   │   ├── model/
│   │   │   │   │   └── Appointment.java
│   │   │   │   └── dto/
│   │   │   │       └── AppointmentRequest.java
│   │   │   │
│   │   │   ├── sync/                          ← Offline batch sync endpoint
│   │   │   │   ├── SyncController.java        ← POST /api/v1/sync
│   │   │   │   ├── SyncService.java           ← Routes each record type to correct service
│   │   │   │   └── dto/
│   │   │   │       ├── SyncRequest.java       ← { records: [{ entityType, clientRecordId, payload }] }
│   │   │   │       └── SyncResponse.java      ← { synced: [], conflicts: [], errors: [] }
│   │   │   │
│   │   │   ├── alert/                         ← Real-time alerts to clinicians
│   │   │   │   ├── AlertController.java       ← GET /api/v1/clinician/alerts
│   │   │   │   ├── AlertService.java          ← Saves alerts; pushes via WebSocket
│   │   │   │   ├── AlertRepository.java
│   │   │   │   ├── AlertWebSocketController.java  ← STOMP @MessageMapping
│   │   │   │   ├── model/
│   │   │   │   │   └── Alert.java
│   │   │   │   └── dto/
│   │   │   │       └── AlertResponse.java
│   │   │   │
│   │   │   └── clinician/                     ← Clinician-facing patient data views
│   │   │       ├── ClinicianController.java   ← GET /api/v1/clinician/patients
│   │   │       ├── ClinicianService.java
│   │   │       └── dto/
│   │   │           ├── PatientSummaryResponse.java
│   │   │           └── PatientDetailResponse.java
│   │   │
│   │   └── resources/
│   │       ├── application.yml                ← Base config (port, jpa settings)
│   │       ├── application-dev.yml            ← Local dev: H2 or local PostgreSQL
│   │       ├── application-prod.yml           ← Production: Railway PostgreSQL via env vars  [GITIGNORED]
│   │       └── db/
│   │           └── migration/                 ← Flyway SQL scripts — auto-run on startup
│   │               ├── V1__create_users.sql
│   │               ├── V2__create_patients.sql
│   │               ├── V3__create_medications.sql
│   │               ├── V4__create_dose_logs.sql
│   │               ├── V5__create_vitals_logs.sql
│   │               ├── V6__create_symptom_logs.sql
│   │               ├── V7__create_activity_logs.sql
│   │               ├── V8__create_appointments.sql
│   │               ├── V9__create_alerts.sql
│   │               └── V10__create_sync_queue.sql
│   │
│   └── test/
│       └── java/com/heartcare/
│           ├── auth/
│           │   └── AuthServiceTest.java
│           ├── medication/
│           │   └── MedicationServiceTest.java
│           ├── vitals/
│           │   └── VitalsServiceTest.java
│           └── sync/
│               └── SyncServiceTest.java       ← Critical: test idempotency logic
│
└── pom.xml                                    ← Maven dependencies
```

---

## 3. Database — `database/`

This top-level folder is the single source of truth for everything database-related that lives *outside* of Spring Boot's runtime — design artefacts, reference SQL, and seed data for development and testing.

The actual migration scripts that Flyway runs are inside `backend/src/main/resources/db/migration/`. The `database/migrations/` folder here is a **reference copy** kept in sync so the team can review schema history without opening the backend project.

```
database/
│
├── schema/
│   ├── erd.png                        ← Entity-Relationship Diagram (export from dbdiagram.io)
│   ├── erd.dbml                       ← Source file for the ERD (dbdiagram.io format)
│   └── table_descriptions.md          ← Plain-English description of each table and its purpose
│
├── migrations/                        ← Reference copies of Flyway migration SQL
│   │                                     (Flyway runs from backend/resources/db/migration/)
│   ├── V1__create_users.sql           ← users table: id, email, password_hash, role
│   ├── V2__create_patients.sql        ← patients table: profile, comorbidities (JSONB), goals
│   ├── V3__create_medications.sql     ← medications table: name, dose, frequency, schedule
│   ├── V4__create_dose_logs.sql       ← dose_logs: client_record_id UNIQUE, taken/missed/skipped
│   ├── V5__create_vitals_logs.sql     ← vitals_logs: BP, glucose, HR, weight
│   ├── V6__create_symptom_logs.sql    ← symptom_logs: chest pain, SOB, swelling, energy level
│   ├── V7__create_activity_logs.sql   ← activity_logs: type, duration, intensity
│   ├── V8__create_appointments.sql    ← appointments: patient, clinician, scheduled_at, status
│   ├── V9__create_alerts.sql          ← alerts: type, severity, patient_id, resolved
│   └── V10__create_sync_queue.sql     ← sync_queue: entity_type, payload, sync_status
│
└── seed/
    ├── dev_seed.sql                   ← Sample data for local development
    │                                     (test patient, clinician, sample vitals/meds)
    └── test_seed.sql                  ← Minimal clean data for automated integration tests
```

### How Flyway Works

Flyway reads every `V{n}__{description}.sql` file from `backend/src/main/resources/db/migration/` and runs them **in version order** when Spring Boot starts. Once a script has run, Flyway records it in a `flyway_schema_history` table and never runs it again. To change the schema, you **never edit existing migration files** — you always add a new one (e.g., `V11__add_cholesterol_to_vitals.sql`). This keeps every environment (dev, prod) in sync automatically.

### Naming Convention for Migration Files

```
V{version}__{short_description}.sql

V1__create_users.sql          ✅ correct
v1_create_users.sql           ❌ lowercase V — Flyway won't detect it
V1__CreateUsers.sql           ❌ camelCase — use snake_case
V1_create_users.sql           ❌ single underscore — must be double __
```

---

## 5. Key Structural Rules

These rules keep the codebase clean as the team grows and parallel development happens across features.

**Rule 1 — Features never import from each other directly.**
If the `vitals` feature needs data from `patient`, it calls through a service interface or repository — never by importing `vitals` classes into `medication`. Cross-feature dependencies go through `core/` (Flutter) or `common/` (Spring Boot).

**Rule 2 — DTOs never leave their feature package.**
In Spring Boot, a `VitalsRequest` DTO is only used inside the `vitals/` package. The `SyncService` in `sync/` receives a raw JSON payload and passes it to `VitalsService` via a clean method call — not by constructing a `VitalsRequest` inside `sync/`.

**Rule 3 — Local datasource and remote datasource are always separate.**
In Flutter, every feature that has network data has both a `_local_datasource.dart` (Drift/SQLite) and a `_remote_datasource.dart` (Dio). The repository implementation decides which to call. This is what makes offline mode possible without conditionals scattered across the UI.

**Rule 4 — All API URLs live in one place.**
`core/constants/api_endpoints.dart` in Flutter and `application.yml` in Spring Boot are the only places where URLs and paths are defined. Never hardcode `"/api/v1/vitals"` inside a screen or service class.

**Rule 5 — One feature, one developer (as much as possible).**
Assign ownership: one person owns `medication/` end-to-end (Flutter feature + Spring Boot feature), another owns `vitals/`, etc. This minimises merge conflicts and makes code review faster.

---

## 6. Git Branch Strategy

```
main                  ← Production-ready code only.
  └── dev             ← Integration branch.
        ├── feature/<backend-module>        backend slices (all merged)
        └── mobile                          Flutter foundation + team integration
              ├── feature/mobile/auth
              ├── feature/mobile/profile
              ├── feature/mobile/medications
              ├── feature/mobile/vitals
              └── feature/mobile/symptoms-activity
```

Frontend slices PR into `mobile`; `mobile` merges to `dev` at milestones. Only
the team lead merges `dev` → `main` after testing.

> **No branch is mechanically protected.** GitHub gates branch protection and
> rulesets behind a paid plan for private repositories, so the rules above are
> enforced by convention and code review, not by the platform. CI still runs
> on every PR into `mobile` and fails loudly on a boundary violation — the
> standing rule is that a red PR is never merged. Revisit if the repository
> ever goes public or onto GitHub Pro.

---

*Last updated: 14 April 2026. Update this document if the folder structure changes significantly — keeping it accurate avoids onboarding confusion for new contributors and supports the A2 Design Progress report.*
