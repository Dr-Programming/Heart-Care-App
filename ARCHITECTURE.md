# Heart-Care App — System Architecture

**Project:** Heart-Care App (UOW Capstone — Project 29)  
**Client:** Tesema Etefa Birhanu (UOW PhD Student)  
**Supervisors:** Dr Elena Vlahu-Gjorgievska, Prof. Khin Than Win  
**Document Owner:** Developing Team  
**Last Updated:** 14 April 2026

---

## Table of Contents

1. [Project Context & Constraints](#1-project-context--constraints)
2. [Tech Stack Overview](#2-tech-stack-overview)
3. [Technology Justifications](#3-technology-justifications)
4. [System Architecture](#4-system-architecture)
5. [Component Breakdown](#5-component-breakdown)
6. [Connection & Data Flow](#6-connection--data-flow)
7. [Offline-First Architecture](#7-offline-first-architecture)
8. [Authentication & Role-Based Access](#8-authentication--role-based-access)
9. [Real-Time Communication Flow](#9-real-time-communication-flow)
10. [Database Design Overview](#10-database-design-overview)
11. [API Design Principles](#11-api-design-principles)
12. [Deployment Architecture](#12-deployment-architecture)

---

## 1. Project Context & Constraints

The Heart-Care App is designed for adults in Ethiopia living with coronary heart disease (CHD). The app provides medication tracking, symptom monitoring, health education, and patient-clinician communication.

The following constraints directly drive every architectural decision:

| Constraint | Impact on Architecture |
|---|---|
| **Offline-first** — Ethiopia has limited, intermittent connectivity | All features must work without internet; data syncs when connected |
| **Low-end Android devices** — Budget smartphones are dominant | Native performance is critical; no heavy JavaScript bridges |
| **Low digital literacy** — Users range widely in tech experience | Simple UI, minimal steps per action, local language (Amharic) support |
| **Free / Open-source stack** — No paid licenses or services | All chosen technologies are free and open-source |
| **Cross-platform** — Must target both Android and iOS | Single codebase required; no separate native apps |
| **Healthcare data sensitivity** — Patient vitals and records | Role-based access, JWT auth, encrypted local storage |
| **Real-time alerts** — Clinician notifications, abnormal reading alerts | WebSocket support required in backend |

---

## 2. Tech Stack Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                             │
│                                                                 │
│   Flutter (Dart)  ─────────────────────────────────────────    │
│   ├── Drift (SQLite)          [Local offline database]         │
│   ├── flutter_local_notifications  [Offline reminders]        │
│   ├── fl_chart                [Trend graphs / dashboards]      │
│   ├── flutter_secure_storage  [Encrypted token storage]        │
│   └── dio + connectivity_plus [HTTP client + sync manager]    │
└─────────────────────────┬───────────────────────────────────────┘
                          │  REST API (HTTPS)
                          │  WebSocket (STOMP over WS)
┌─────────────────────────▼───────────────────────────────────────┐
│                       SERVER LAYER                              │
│                                                                 │
│   Spring Boot (Java)  ─────────────────────────────────────    │
│   ├── Spring Security + JWT   [Auth & role-based access]       │
│   ├── Spring Data JPA         [ORM / database abstraction]     │
│   ├── Spring WebSocket/STOMP  [Real-time communication]        │
│   └── Spring Validation       [Request validation]             │
└─────────────────────────┬───────────────────────────────────────┘
                          │  JDBC
┌─────────────────────────▼───────────────────────────────────────┐
│                      DATABASE LAYER                             │
│                                                                 │
│   PostgreSQL  ─────────────────────────────────────────────    │
│   └── Hosted on Railway (free tier, managed PostgreSQL)        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Technology Justifications

### 3.1 Flutter (Mobile Frontend)

**Chosen over React Native.**

Flutter compiles Dart code directly to native ARM machine code. There is no JavaScript bridge between the app and the device's native components — this is the critical difference. On budget Android phones commonly used in Ethiopia, this translates to noticeably smoother scrolling, faster form rendering, and lower battery usage compared to React Native's bridge-based architecture.

Flutter also has a more mature and consistent offline data story. Libraries like Drift (type-safe SQLite) and Hive (NoSQL key-value store) are purpose-built for Flutter and integrate deeply with Dart's type system. This matters for an offline-first app that writes health data locally before syncing.

From a team perspective, Dart is straightforward for developers with any object-oriented background and can typically be learned in 1–2 weeks. The single codebase deploys to both Android and iOS with no platform-specific code required for the features this app needs.

**Key Flutter packages used:**

| Package | Purpose |
|---|---|
| `drift` | Type-safe SQLite ORM for local offline database |
| `flutter_local_notifications` | Medication reminders that fire without internet |
| `fl_chart` | BP, weight, glucose trend charts (7-day / 30-day) |
| `flutter_secure_storage` | Encrypted storage for JWT tokens |
| `dio` | HTTP client for REST API calls |
| `connectivity_plus` | Detect network state to trigger sync |
| `provider` / `riverpod` | State management across the app |
| `easy_localization` | Amharic + English language support |

---

### 3.2 Spring Boot (Backend)

**Chosen over Node.js + NestJS** because the backend developer has strong existing Java and Spring Boot experience. For a capstone with a fixed deadline, developer familiarity is the single most important factor — a developer who knows their framework deeply ships faster and makes fewer architectural mistakes than one learning a new stack under time pressure.

Spring Boot is also well-suited to this project's requirements independently of familiarity:

- **Spring Security** provides production-grade JWT authentication and role-based access control (PATIENT / CLINICIAN / ADMIN) with minimal configuration.
- **Spring Data JPA + Hibernate** handles the relational health data model (patients, medications, vitals, appointments) cleanly with type-safe repository patterns.
- **Spring WebSocket with STOMP** is a battle-tested solution for real-time messaging — used here for live clinician alerts and abnormal reading notifications.
- **Spring Validation** enforces data integrity at the API boundary, important for health records where bad data has real consequences.

---

### 3.3 PostgreSQL (Database)

PostgreSQL is the right database for structured, relational health data. Patient records, medication schedules, symptom logs, and vital signs all have clear relationships that benefit from foreign key constraints, JOIN queries, and transactional integrity. A NoSQL database like MongoDB would make it harder to enforce data consistency across related health records.

PostgreSQL is free, open-source, and has a strong free tier on Railway (the chosen hosting platform). It also supports JSONB columns, which are useful for storing flexible data like personalized goals or custom medication schedules without requiring schema migrations.

---

### 3.4 Why NOT the alternatives

| Technology | Why not chosen |
|---|---|
| React Native | JS bridge reduces performance on low-end Android; less mature offline libraries |
| Node.js + NestJS | Team's backend developer knows Spring Boot — no advantage to switching |
| MySQL | PostgreSQL has better JSON support and more advanced query features |
| Firebase | Proprietary, not truly open-source, offline sync is harder to control, free tier is restrictive |
| MongoDB | Relational health data (patients → medications → doses → logs) fits PostgreSQL better |
| SQLite (server) | Not suitable for a multi-user server; fine for local device storage only |

---

## 4. System Architecture

### High-Level Architecture

```
 ┌──────────────────────────────────────────────────────────┐
 │                   FLUTTER MOBILE APP                     │
 │                                                          │
 │  ┌────────────────┐        ┌────────────────────────┐   │
 │  │  UI Layer      │        │   Local Data Layer     │   │
 │  │  (Screens,     │◄──────►│   Drift / SQLite       │   │
 │  │   Widgets)     │        │   (offline database)   │   │
 │  └───────┬────────┘        └───────────┬────────────┘   │
 │          │                             │                 │
 │  ┌───────▼─────────────────────────────▼────────────┐   │
 │  │              Service / Repository Layer           │   │
 │  │   MedicationService │ VitalsService │ SyncService│   │
 │  └───────────────────────────┬───────────────────────┘   │
 │                              │                           │
 │  ┌───────────────────────────▼───────────────────────┐   │
 │  │              Network Layer (Dio)                  │   │
 │  │   ConnectivityPlus → triggers SyncService        │   │
 │  └───────────────────────────┬───────────────────────┘   │
 └──────────────────────────────┼───────────────────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │ REST API (HTTPS)  │  WebSocket (STOMP) │
            └───────────────────┼───────────────────┘
                                │
 ┌──────────────────────────────▼───────────────────────────┐
 │                  SPRING BOOT BACKEND                     │
 │                                                          │
 │  ┌────────────────────────────────────────────────────┐  │
 │  │                  Controller Layer                  │  │
 │  │  /auth  /patients  /medications  /vitals  /sync   │  │
 │  │  /symptoms  /appointments  /education  /alerts    │  │
 │  └───────────────────────┬────────────────────────────┘  │
 │                          │                               │
 │  ┌───────────────────────▼────────────────────────────┐  │
 │  │                  Service Layer                     │  │
 │  │  Business logic, validation, sync conflict         │  │
 │  │  resolution, alert threshold evaluation           │  │
 │  └───────────────────────┬────────────────────────────┘  │
 │                          │                               │
 │  ┌───────────────────────▼────────────────────────────┐  │
 │  │               Repository Layer                     │  │
 │  │  Spring Data JPA Repositories (type-safe queries) │  │
 │  └───────────────────────┬────────────────────────────┘  │
 │                          │                               │
 │  ┌───────────────────────▼────────────────────────────┐  │
 │  │              Spring Security Layer                 │  │
 │  │  JWT filter, role extraction, request gating      │  │
 │  └────────────────────────────────────────────────────┘  │
 └──────────────────────────┬───────────────────────────────┘
                            │ JDBC
 ┌──────────────────────────▼───────────────────────────────┐
 │                     POSTGRESQL                           │
 │  patients │ medications │ vitals │ symptoms │ logs       │
 │  appointments │ education_content │ alerts │ users       │
 └──────────────────────────────────────────────────────────┘
```

---

## 5. Component Breakdown

### 5.1 Flutter App — Modules

| Module | Screens | Local DB Tables |
|---|---|---|
| **Auth** | Login, Register, Role select | `users_local` |
| **Personal Profile** | Profile view/edit, Goals | `patient_profile`, `goals` |
| **Education** | CHD Facts, Quizzes, Diet guide | Bundled assets (no DB needed) |
| **Medication Manager** | Med list, Add med, Log dose, Reminders | `medications`, `dose_logs` |
| **Symptom Monitor** | Daily check-in, Symptom history | `symptom_logs` |
| **Physical Activity** | Activity log, Guidance | `activity_logs` |
| **Vitals Tracker** | Log BP/glucose/weight/HR, Dashboard | `vitals_logs` |
| **Trend Charts** | 7-day/30-day graphs | Queried from `vitals_logs` |
| **Appointments** | Upcoming visits, Reminders | `appointments` |
| **Clinician View** | Patient list, Data review, Alerts | `shared_data` (clinician role) |
| **Sync Engine** | Background sync, Conflict resolution | `sync_queue` |

### 5.2 Spring Boot — API Modules

| Module | Responsibility |
|---|---|
| `AuthController` | Register, login, JWT issue/refresh |
| `PatientController` | CRUD for patient profiles |
| `MedicationController` | Medication schedules, dose records |
| `VitalsController` | BP, glucose, weight, HR logs |
| `SymptomController` | Symptom check-in records |
| `SyncController` | Receive batched offline sync payloads |
| `AlertController` | Threshold-based alert evaluation |
| `AppointmentController` | Follow-up scheduling and reminders |
| `EducationController` | Content management (future CMS hook) |
| `WebSocketController` | Real-time alert broadcasting via STOMP |

---

## 6. Connection & Data Flow

### 6.1 Normal Online Flow (User has connectivity)

```
User Action (e.g., logs BP reading)
         │
         ▼
Flutter UI (VitalsScreen)
         │
         ▼
VitalsService.logVital(reading)
         │
         ├──► Write to local Drift/SQLite DB immediately
         │    (instant UI feedback, no waiting for network)
         │
         └──► HTTP POST /api/vitals  →  Spring Boot VitalsController
                                              │
                                              ▼
                                     Spring VitalsService
                                     (validate + check thresholds)
                                              │
                                    ┌─────────┴──────────┐
                                    │                    │
                                    ▼                    ▼
                              Save to                 Alert threshold
                              PostgreSQL              exceeded?
                                                           │
                                                           ▼
                                                    WebSocket STOMP
                                                    broadcast to
                                                    clinician app
```

### 6.2 Offline Flow (No connectivity — most common in Ethiopia)

```
User Action (e.g., logs medication dose)
         │
         ▼
Flutter UI (MedicationScreen)
         │
         ▼
MedicationService.logDose(dose)
         │
         ├──► Write to local Drift/SQLite DB
         │    (app works normally — user sees no difference)
         │
         └──► Mark record as sync_status = PENDING
              in sync_queue table
              (server call skipped — no connectivity)

[Later, when connectivity returns]

ConnectivityPlus detects network → triggers SyncService
         │
         ▼
SyncService.syncPendingRecords()
         │
         ▼
Reads all records where sync_status = PENDING
         │
         ▼
HTTP POST /api/sync  (batched payload)
         │
         ▼
Spring Boot SyncController
         │
         ▼
For each record:
  ├── Check idempotency (client_record_id already exists?)
  │      └── YES: skip (no duplicate)
  │      └── NO: insert into PostgreSQL
  │
  └── Return sync result (success / conflict list)
         │
         ▼
Flutter marks synced records as sync_status = SYNCED
```

### 6.3 App Startup Flow

```
App Launch
    │
    ▼
Check flutter_secure_storage for JWT token
    │
    ├── Token exists & valid → Load home screen
    │        └── Trigger background sync (if online)
    │
    └── No token / expired → Show login screen
             │
             ▼
         User logs in → POST /api/auth/login
             │
             ▼
         Spring Security validates credentials
             │
             ▼
         JWT issued (contains userId + role)
             │
             ▼
         Token stored in flutter_secure_storage
             │
             ▼
         Home screen loaded
```

---

## 7. Offline-First Architecture

This is the most critical architectural concern for the Heart-Care app. All features must work without any internet connection.

### 7.1 Local Database Schema (Drift / SQLite)

Every user-generated record is stored locally first. Key tables:

```
patients_local       - Profile, goals, disease stage
medications          - Med name, dose, frequency, times
dose_logs            - Each recorded dose (taken/missed)
symptom_logs         - Daily symptom check-ins
vitals_logs          - BP, glucose, weight, HR readings
activity_logs        - Physical activity records
appointments         - Follow-up appointments + reminders
sync_queue           - Records pending server sync
```

### 7.2 Sync Queue Design

Every locally-created record carries:

```
client_record_id   UUID  (generated on device — prevents duplicates)
entity_type        STRING (e.g., "VITAL", "DOSE_LOG", "SYMPTOM")
payload            JSON  (the full record data)
recorded_at        TIMESTAMP (when user actually recorded it)
sync_status        ENUM: PENDING | SYNCING | SYNCED | CONFLICT
created_locally_at TIMESTAMP (for ordering)
```

### 7.3 Conflict Resolution Strategy

For health logs (vitals, dose logs, symptoms), the rule is **last recorded timestamp wins per record**. Since each record has a unique `client_record_id`, true duplicates are simply skipped on the server. Conflicts only arise if the same `client_record_id` arrives with different data — treated as a server-side update if `recorded_at` is newer.

> ⚠️ **As-built deviation (Slice 7), pending owner sign-off.** The implemented sync engine does **not** overwrite. Log tables are append-only/immutable, so a divergent payload under an existing `client_record_id` is *detected and reported* as a per-record `CONFLICT` — the first-stored record wins and is returned unchanged. With the phone as the sole writer and no edit path for logged records, a genuine conflict signals a client bug reusing a UUID rather than a legitimate later edit; overwriting clinical history would need an audit trail to be defensible. See `docs/design/2026-07-17-sync-design.md`, Decision 3.

### 7.4 Offline Notifications

Medication reminders are scheduled using `flutter_local_notifications`, which runs entirely on the device with no server dependency. When a user adds a medication with a schedule (e.g., 8 AM daily), the app schedules local notifications for the next 30 days. These fire regardless of connectivity.

### 7.5 Bundled Content Strategy

Education content (CHD facts, Ethiopian diet guide, physical activity guidance, symptom explanations) is bundled directly into the app as JSON/Markdown assets at build time. This content never requires a network call. The server can push content updates on next sync, but the app always has a complete working set built in.

---

## 8. Authentication & Role-Based Access

### 8.1 User Roles

| Role | Access |
|---|---|
| `PATIENT` | Own profile, own health logs, education content, appointments |
| `CLINICIAN` | Assigned patients' data, alerts, shared care plan updates |
| `ADMIN` | User management, content management (future scope) |

### 8.2 JWT Flow

```
POST /api/auth/login
  { email, password }
         │
         ▼
Spring Security AuthenticationManager
  └── BCrypt password validation
         │
         ▼
JWT generated:
  {
    sub: userId,
    role: "PATIENT",
    exp: 7 days
  }
         │
         ▼
Stored in flutter_secure_storage (encrypted on device)
         │
         ▼
Every subsequent API request:
  Authorization: Bearer <token>
         │
         ▼
Spring Security JwtAuthFilter (intercepts all requests)
  └── Validates token → extracts userId + role
  └── Attaches to SecurityContext
         │
         ▼
Controller receives pre-authenticated request
  └── @PreAuthorize("hasRole('CLINICIAN')") annotations gate access
```

---

## 9. Real-Time Communication Flow

Used for: abnormal reading alerts to clinicians, missed dose warnings, care plan updates.

### 9.1 WebSocket Connection (STOMP over WebSocket)

```
Flutter App                          Spring Boot
    │                                     │
    ├── WS connect to /ws endpoint ──────►│
    │                                     │
    ├── STOMP CONNECT (with JWT) ────────►│
    │                            Spring Security validates JWT
    │                                     │
    ◄── CONNECTED ───────────────────────┤
    │                                     │
    ├── SUBSCRIBE /user/queue/alerts ────►│
    │   (user-specific alert channel)     │
    │                                     │

[Patient logs critical symptom or vital via REST API]

    │                                     │
    │              Spring AlertService evaluates threshold
    │                                     │
    ◄── STOMP MESSAGE /user/queue/alerts ─┤
    │   { type: "CRITICAL_VITAL",          │
    │     message: "BP > 180/110",         │
    │     patientId: "...",                │
    │     timestamp: "..." }              │
    │                                     │
Flutter shows alert notification
```

### 9.2 Alert Threshold Rules (Spring AlertService)

| Metric | Alert Condition | Severity |
|---|---|---|
| Blood Pressure | Systolic > 180 or Diastolic > 110 | CRITICAL |
| Blood Pressure | Systolic > 140 or Diastolic > 90 | WARNING |
| Heart Rate | > 120 bpm or < 50 bpm | WARNING |
| Blood Glucose | < 3.9 or > 15.0 mmol/L | WARNING |
| Missed Doses | ≥ 2 consecutive doses missed | ADHERENCE ALERT |
| Missed Dose + Symptoms | Any missed dose + reported chest pain/SOB | CRITICAL |
| Chest Pain | Any reported "Severe" | CRITICAL |

---

## 10. Database Design Overview

### Core Tables (PostgreSQL)

```sql
-- User accounts (patients and clinicians)
users
  id UUID PRIMARY KEY
  email VARCHAR UNIQUE
  password_hash VARCHAR
  role ENUM('PATIENT', 'CLINICIAN', 'ADMIN')
  created_at TIMESTAMP

-- Patient profile
patients
  id UUID PRIMARY KEY
  user_id UUID REFERENCES users(id)
  full_name VARCHAR
  date_of_birth DATE
  disease_stage VARCHAR
  comorbidities JSONB        -- flexible: diabetes, hypertension, etc.
  personalized_goals JSONB   -- BP target, weight target, steps/day
  preferred_language VARCHAR DEFAULT 'am' -- 'am' = Amharic, 'en' = English
  created_at TIMESTAMP

-- Medications
medications
  id UUID PRIMARY KEY
  patient_id UUID REFERENCES patients(id)
  name VARCHAR
  dose_mg DECIMAL
  frequency VARCHAR          -- 'DAILY', 'BID', 'TID', 'CUSTOM'
  scheduled_times JSONB      -- ["08:00", "20:00"]
  is_active BOOLEAN
  started_at DATE

-- Dose logs (each individual dose event)
dose_logs
  id UUID PRIMARY KEY
  client_record_id UUID UNIQUE  -- idempotency key from device
  medication_id UUID REFERENCES medications(id)
  scheduled_at TIMESTAMP
  recorded_at TIMESTAMP
  status ENUM('TAKEN', 'MISSED', 'SKIPPED')
  notes VARCHAR

-- Vitals logs
vitals_logs
  id UUID PRIMARY KEY
  client_record_id UUID UNIQUE
  patient_id UUID REFERENCES patients(id)
  systolic_bp INTEGER
  diastolic_bp INTEGER
  heart_rate INTEGER
  blood_glucose DECIMAL
  weight_kg DECIMAL
  recorded_at TIMESTAMP

-- Symptom check-ins
symptom_logs
  id UUID PRIMARY KEY
  client_record_id UUID UNIQUE
  patient_id UUID REFERENCES patients(id)
  chest_pain ENUM('NONE','MILD','MODERATE','SEVERE')
  shortness_of_breath ENUM('NONE','MILD','SEVERE')
  swelling BOOLEAN
  energy_level INTEGER        -- 0-10 scale
  notes VARCHAR
  recorded_at TIMESTAMP

-- Appointments
appointments
  id UUID PRIMARY KEY
  patient_id UUID REFERENCES patients(id)
  clinician_id UUID REFERENCES users(id)
  scheduled_at TIMESTAMP
  type VARCHAR
  notes VARCHAR
  status ENUM('UPCOMING', 'COMPLETED', 'MISSED')
```

---

## 11. API Design Principles

All REST endpoints follow these conventions:

- **Base URL:** `https://heartcare-api.railway.app/api/v1`
- **Auth header:** `Authorization: Bearer <JWT>` on all protected routes
- **Response envelope:**
  ```json
  {
    "success": true,
    "data": { ... },
    "message": "OK",
    "timestamp": "2026-04-14T10:00:00Z"
  }
  ```
- **Sync endpoint accepts batched payloads** — the Flutter app posts all pending offline records in a single call to minimize connection overhead on slow networks
- **Idempotent writes** — all POST endpoints that create records accept a `clientRecordId` field; duplicate submissions with the same ID are silently ignored

### Key Endpoints

| Method | Endpoint | Role | Description |
|---|---|---|---|
| POST | `/auth/login` | Public | Login, returns JWT |
| POST | `/auth/register` | Public | Register new user |
| GET | `/patients/me` | PATIENT | Own profile |
| PUT | `/patients/me` | PATIENT | Update profile/goals |
| GET | `/medications` | PATIENT | List medications |
| POST | `/medications` | PATIENT | Add medication |
| POST | `/dose-logs` | PATIENT | Log a dose taken/missed |
| POST | `/vitals` | PATIENT | Log vital signs |
| POST | `/symptoms` | PATIENT | Log symptom check-in |
| POST | `/sync` | PATIENT | Batch sync offline records |
| GET | `/clinician/patients` | CLINICIAN | List assigned patients |
| GET | `/clinician/patients/{id}/vitals` | CLINICIAN | View patient vitals |
| GET | `/clinician/alerts` | CLINICIAN | View pending alerts |

---

## 12. Deployment Architecture

```
Developer Machine
      │
      ├── Flutter app → Google Play Store (Android)
      │                → Apple App Store (iOS)
      │
      └── Spring Boot JAR → Railway.app
                                │
                                └── PostgreSQL (Railway managed DB)
                                    (automatic backups, free tier)
```

### Environment Configuration

| Environment | Flutter Config | Spring Boot Config |
|---|---|---|
| **Development** | `localhost:8080` | `application-dev.yml` (local PostgreSQL) |
| **Production** | `heartcare-api.railway.app` | `application-prod.yml` (Railway PostgreSQL, env vars for secrets) |

### Security Notes for Production

- JWT secret stored as Railway environment variable (never in source code)
- PostgreSQL credentials injected via Railway environment variables
- HTTPS enforced on all API endpoints (Railway provides SSL by default)
- `flutter_secure_storage` uses Android Keystore / iOS Keychain for token encryption on device

---

*This document should be treated as a living reference. Update when architectural decisions change, and ensure supervisors and the client are informed of any significant changes to the technology choices or data flows.*
