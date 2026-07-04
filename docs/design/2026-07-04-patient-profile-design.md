# Backend Design — Slice 2 (Patient Profile)

**Project:** Heart-Care App (UOW Capstone — Project 29)
**Date:** 2026-07-04
**Status:** Approved for implementation planning
**Scope of this spec:** Detailed design of **Slice 2 — Patient Profile** (`GET/PUT /patients/me`, profile fields + goals JSONB, migration `V2__patients`). Builds on the architecture and conventions established in `2026-06-30-backend-foundation-auth-design.md`.

---

## 1. Context & Goal

Slice 1 delivered the auth foundation (register/login → JWT, secured `/auth/me`). Slice 2 adds the first patient feature module: a personal profile that the patient can read and update. Per the offline-first architecture, the device is the source of truth; this endpoint persists the profile the device syncs up and lets a freshly-installed device pull it back.

This slice implements the P1 personal-profile requirements plus the goals blob:

| FR | Field(s) | Priority |
|---|---|---|
| FR-PROF-001 | birth **year** (year only, per requirement annotation), preferred language | P1 |
| FR-PROF-002 | disease history, CHD diagnosis stage | P1 |
| FR-PROF-003 | comorbidities (list) | P1 |
| FR-PROF-005 | current management plan (free text) | P1 |
| FR-VIT-004 | height (cm) — stored here so BMI can be derived in the Vitals slice | P1 (implied) |
| FR-PROF-006 | goals: BP, cholesterol, steps/day, weight, diet | P2 (included per build sequence) |
| FR-PROF-007 | update profile at any time → the `PUT` endpoint | P1 |

**Deferred (out of scope for this slice):**
- FR-PROF-004 — lab results (P2).
- FR-PROF-009 — family member / caregiver contact (P3).

---

## 2. Key Design Decisions

1. **Profile is decoupled from `auth`.** The `patient` feature never imports `auth` classes (architectural rule #1). The authenticated `userId` arrives via the JWT (`UserPrincipal`); the profile stores and returns only profile-specific fields plus `userId`. Full name and email remain owned by `users` (Slice 1) and are read via `/auth/me`. The DB foreign key `patient_profiles.user_id → users.id` is a schema-level relationship only, not a code dependency.

2. **1:1 profile, keyed by `user_id`.** `patient_profiles.user_id` is simultaneously the primary key and the FK to `users`, structurally guaranteeing exactly one profile per patient.

3. **Lazy creation via upsert.** No profile row is created at registration (that would couple the patient feature to auth's register flow). `GET /patients/me` returns a `200` all-null profile skeleton until the first `PUT`; `PUT` creates-or-updates. This gives the offline-first client a consistent shape to bind to whether or not a profile has been saved.

4. **JSONB for `comorbidities` and `goals`.** Comorbidities (a list of strings) and goals (a small nested object) are stored as JSONB — flexible, avoids extra tables, mapped in Hibernate with `@JdbcTypeCode(SqlTypes.JSON)`. The remaining fields are typed columns.

---

## 3. Migration `V2__create_patient_profiles.sql`

```sql
CREATE TABLE patient_profiles (
    user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    birth_year         INTEGER,
    preferred_language VARCHAR(5),
    height_cm          INTEGER,
    chd_stage          VARCHAR(50),
    disease_history    TEXT,
    comorbidities      JSONB NOT NULL DEFAULT '[]'::jsonb,
    management_plan    TEXT,
    goals              JSONB,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- `ON DELETE CASCADE` — deleting a user removes their profile.
- `birth_year` / `height_cm` use `INTEGER` (not `SMALLINT`) so they map cleanly to Java `Integer` under `spring.jpa.hibernate.ddl-auto=validate`.
- `comorbidities` defaults to an empty JSON array so reads never return SQL `NULL` for the list.
- All clinical fields are nullable; a patient may fill the profile incrementally.

---

## 4. Endpoints (base `/api/v1`)

| Method | Path | Auth | Request | Response (`data`) | Req |
|---|---|---|---|---|---|
| GET | `/patients/me` | Bearer JWT | — | full profile; all-null skeleton if never saved (**200**, not 404) | FR-PROF-001/002/003/005 |
| PUT | `/patients/me` | Bearer JWT | full profile | updated profile | FR-PROF-007 |

- All responses use the `ApiResponse<T>` envelope from Slice 1.
- Both routes require authentication; unauthenticated → `401` (existing `JwtAuthenticationEntryPoint`).
- `PUT` has full-replace semantics over the profile fields; every field is optional, so a partial body clears omitted fields to null. This keeps the contract simple and matches the client sending its full local profile on sync.

### Response / request body shape

```json
{
  "userId": "…uuid…",
  "birthYear": 1975,
  "preferredLanguage": "am",
  "heightCm": 172,
  "chdStage": "Stage II",
  "diseaseHistory": "…",
  "comorbidities": ["diabetes", "hypertension"],
  "managementPlan": "…",
  "goals": {
    "bpSystolic": 120,
    "bpDiastolic": 80,
    "totalCholesterol": 180,
    "stepsPerDay": 8000,
    "targetWeightKg": 70,
    "dietNote": "low salt"
  }
}
```

The `PUT` request body is the same object minus `userId` (taken from the token). `goals` is a small shared value object (`model/Goals`, a record) reused by the entity and both DTOs; all its fields are optional.

---

## 5. Package layout (package-by-feature)

```
com.heartcare.patient
├── PatientController.java            GET/PUT /patients/me
├── PatientService.java               getProfile(userId) / upsertProfile(userId, req)
├── PatientProfileRepository.java     extends JpaRepository<PatientProfile, UUID>
├── model/
│   ├── PatientProfile.java           @Entity; comorbidities/goals via @JdbcTypeCode(SqlTypes.JSON)
│   └── Goals.java                    shared JSONB value object (record); reused by entity + DTOs
└── dto/
    ├── PatientProfileRequest.java    inbound (Bean Validation constraints)
    └── PatientProfileResponse.java   outbound
```

Follows Slice 1 conventions: Java `record` DTOs, constructor-based entity, service returns response DTOs, controller resolves `userId` from the `UserPrincipal`.

---

## 6. Validation

Bean Validation (Jakarta) on `PatientProfileRequest`:

- `birthYear` — `@Min(1900)` and `≤` current year (custom check in service or `@Max` with a constant ceiling); nullable.
- `preferredLanguage` — one of `en`, `am` (pattern or enum); nullable.
- `heightCm` — `@Min(50) @Max(250)`; nullable.
- `chdStage` — `@Size(max = 50)`; nullable.
- `goals` numeric fields — non-negative where present.

Constraint violations → `400 Bad Request` wrapped by the existing `GlobalExceptionHandler`.

---

## 7. Testing strategy (TDD)

- **`PatientServiceTest`** (unit, mocked `PatientProfileRepository`):
  - `getProfile` returns an empty/skeleton profile when no row exists;
  - `upsertProfile` creates a row on first call, updates it on the second;
  - `comorbidities` and `goals` round-trip through the mapper.
- **`PatientControllerIntegrationTest`** (`@SpringBootTest` + Testcontainers PostgreSQL, MockMvc):
  - `GET /patients/me` without token → 401;
  - `GET` with token, no profile yet → 200 with all-null skeleton;
  - `PUT` with token → 200 updated; a subsequent `GET` reflects the change;
  - `PUT` with invalid data (bad language / height out of range) → 400;
  - JSONB (`comorbidities`, `goals`) persists and reloads on real Postgres (validates `V2`).

Reuses the Slice 1 `AbstractIntegrationTest` Testcontainers base.

---

## 8. Documentation updates (end of slice)

- `backend/README.md` — flip Slice 2 to ✅ in the build-progress table.
- `backend/docs/API.md` — add `GET/PUT /patients/me` (auth, request/response envelope).
- `backend/docs/DATABASE.md` — add the `patient_profiles` table and the `V2` migration-log entry.

---

## 9. "Done" criteria

- `mvn spring-boot:run` boots; Flyway applies `V2` on top of `V1`.
- A logged-in patient can `PUT` then `GET` their profile end-to-end; unauthenticated access returns 401; invalid input returns 400.
- `mvn test` green (unit + integration, JSONB validated on real Postgres).
- README progress + `API.md` + `DATABASE.md` reflect Slice 2.

---

## 10. Out of scope for Slice 2

- Lab results (FR-PROF-004, P2) and caregiver contact (FR-PROF-009, P3).
- Medications / management-plan structured records — the plan is free text here; structured meds arrive in Slice 3.
- Offline sync routing of profile updates — handled by the Slice 7 sync engine.
