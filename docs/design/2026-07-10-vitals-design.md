# Backend Design — Slice 4 (Health Vitals Tracking)

**Project:** Heart-Care App (UOW Capstone — Project 29)
**Date:** 2026-07-10
**Status:** Approved for implementation planning
**Scope of this spec:** Detailed design of **Slice 4 — Health Vitals Tracking** (log blood pressure, glucose, heart rate, weight/BMI, and cholesterol; server-computed clinical-threshold flag; full vitals history; migration `V5__create_vitals_logs.sql`). Builds on the architecture and conventions established in `2026-06-30-backend-foundation-auth-design.md`, `2026-07-04-patient-profile-design.md`, and `2026-07-09-medications-dose-logs-design.md`.

---

## 1. Context & Goal

Slices 1–3 delivered auth (register/login → JWT), the patient profile, and medications + dose logs. Slice 4 adds the second **time-series log** feature: the vital-sign readings a patient records over time. Like dose logs, these rows are generated on-device (often offline) and reuse the `client_record_id` idempotency key that the Slice 7 sync engine will rely on.

Per the offline-first architecture, the device is the source of truth for *when* and *what* was measured: it captures the reading and can flag it locally for instant feedback even when offline. The backend's job in this slice is to **persist and serve** vitals, and — unlike "today's dose status," which is purely a function of the device's local clock — to compute the two pieces of **clinical truth** that must not depend on a particular app version: the **threshold flag** (`FR-VIT-008`) and **BMI** (`FR-VIT-004`).

### Requirements covered (`FUNCTIONAL_REQUIREMENTS.md §9`)

| FR | Description | Priority | This slice |
|---|---|---|---|
| FR-VIT-001 | Log blood pressure (systolic & diastolic, mmHg) | P1 | ✅ |
| FR-VIT-002 | Log blood glucose (mmol/L) | P1 | ✅ |
| FR-VIT-003 | Log resting heart rate (bpm) | P1 | ✅ |
| FR-VIT-004 | Log weight (kg); auto-calculate BMI if profile height is stored | P1 | ✅ (server-computed BMI snapshot) |
| FR-VIT-005 | Record the timestamp each reading was taken | P1 | ✅ (`measured_at`) |
| FR-VIT-006 | View full vitals history | P1 | ✅ (`GET /vitals` with filters) |
| FR-VIT-007 | Stored locally first, synced when online | P1 | ✅ (server side of the sync contract; `client_record_id`) |
| FR-VIT-008 | Flag any reading exceeding clinical alert thresholds on entry | P1 | ✅ (server-authoritative flag) |
| FR-VIT-009 | Log cholesterol (LDL, HDL, total) when available | P2 | ✅ (included; JSONB made it cheap) |

### Deferred (out of scope for this slice)

- **Weight-trend alerts** — rapid weight gain (fluid retention, a real CHD signal) needs change-over-time logic and a notion of a baseline; belongs with the analytics/alert-engine slice. This slice flags weight only on an *acute BMI* basis. See §9.
- **Server alert engine & notifications (FR-DEC / FR-NOT)** — the `flagged` boolean here is stored data, not a push. The `alerts` table + WebSocket delivery is a separate later subsystem. This slice records *that* a reading breached a threshold; acting on it is deferred.
- **Clinician read access (FR-COM-001/004)** — cross-user access is a later clinician-scope slice; all endpoints here are patient-self-scoped.
- **Offline sync routing** — handled by the Slice 7 sync engine. This slice only lays down the idempotency key.

---

## 2. Design Decisions

Each decision records the choice, the rationale, and the rejected alternative, so a future change starts with full context.

### Decision 1 — Typed entry per metric, values in JSONB

**Choice:** One `vitals_logs` row represents **one metric reading**, discriminated by a `type` enum (`BLOOD_PRESSURE`, `GLUCOSE`, `HEART_RATE`, `WEIGHT`, `CHOLESTEROL`). The numbers live in a JSONB `values` map keyed by a documented, per-type key set (e.g. `{"systolic":120,"diastolic":80}`). A blood-pressure reading is one row; a weight reading is one row.

**Rationale:** Matches this codebase's established pattern of a typed enum column beside a JSONB payload (`medications.frequency` + `schedule_times`; `patient_profiles.comorbidities`/`goals`). Per-type history and charting (`FR-VIT-006`, future `FR-GRAPH`) is a simple `WHERE type = ?`. Multi-number vitals (BP's two values, cholesterol's three) and future vital types need **no migration** — only a new enum value and its documented key set. Per-reading flagging is natural because each row is a single clinical event.

**Rejected alternative — wide row per reading event:** One row with a nullable column per metric (`systolic`, `diastolic`, `glucose`, `heart_rate`, `weight_kg`, `bmi`, `ldl`, `hdl`, `total`). Most columns are NULL on any given row (sparse), per-metric flagging is awkward when several metrics share a row, and every new vital type is a migration. Rejected.

**Rejected alternative — fixed typed value columns (`value_primary/secondary/tertiary`):** Avoids JSONB but the positional columns are opaque (`value_primary` = systolic *or* glucose *or* LDL depending on `type`) and still cap the number of values. JSONB with documented keys is self-describing and unbounded. Rejected in favour of JSONB, consistent with the rest of the schema.

### Decision 2 — `flagged` is computed server-side and is authoritative

**Choice:** On every write the server recomputes `flagged` from a documented threshold table (§4) for the reading's `type`, and stores the result. Any `flagged` value in the request body is **ignored** (overwritten).

**Rationale:** Clinical thresholds are *truth*, not a per-device opinion. A clinician viewing the data later (or the future alert engine) must trust the flag regardless of which app version wrote the row. Unlike "today's dose status" (Slice 3), threshold checks are **static constants with no clock/timezone dependency**, so computing them server-side does *not* reintroduce the server-knows-"now" problem that Slice 3 avoided. The device can still flag locally for instant offline UX using the same documented values; the server value is the authoritative one that persists.

**Rejected alternative — client sends `flagged`, server persists it verbatim:** Minimal server code, but the server cannot verify it, two app versions could disagree, and thresholds are baked into the client. Rejected: unacceptable for a health flag that clinicians and the alert engine will rely on.

**Rejected alternative — defer flagging to the alert-engine slice:** Would leave a P1 (`FR-VIT-008`) unmet this slice. The check is cheap (a handful of range comparisons), so there is no reason to defer. Rejected.

### Decision 3 — BMI is a server-computed snapshot on the weight entry

**Choice:** When a `WEIGHT` reading is logged, the server computes `bmi = weight_kg / (height_m)²` (rounded to 1 decimal) using the patient profile's `height_cm`, and injects it into that row's `values` (`{"weight":72.0,"bmi":23.5}`). If `height_cm` is null, `bmi` is simply absent. The stored BMI is a **snapshot**: a past reading keeps the BMI it had when logged, even if the patient later edits their height.

**Rationale:** BMI is a derived clinical value; computing it server-side is consistent with Decision 2 and means every consumer sees the same number. Snapshot semantics fit the append-only log — history should reflect what was true at measurement time, not retroactively shift when a profile field changes. `height_cm` already exists on `patient_profiles` (Slice 2, nullable INTEGER).

**Rejected alternative — compute BMI on read from current profile height:** Would retroactively rewrite historical BMI whenever height is corrected, and couples every history read to a profile lookup. Rejected in favour of a write-time snapshot.

**Rejected alternative — client sends BMI:** Same trust problem as Decision 2. Rejected.

### Decision 4 — Append-only, immutable readings

**Choice:** No update or delete endpoints. A reading is an immutable event; a correction is a new row (optionally superseding an old one at the client's discretion). Mirrors `dose_logs`.

**Rationale:** Fits offline-first and preserves the audit trail clinicians need. No mutable server state to reconcile on sync.

**Rejected alternative — editable/deletable rows:** Adds mutable-state complexity and conflict handling for no offline benefit, and erodes the audit trail. Rejected.

### Decision 5 — No `unit` column; units are canonical per type

**Choice:** Units are fixed per `type` (§4 table) and documented, not stored per row. The response contract carries the canonical unit implicitly (documented in `API.md`).

**Rationale:** Storing `"mmHg"` on every BP row is redundant free-text that could drift or be spoofed. One canonical unit per type is simpler and unambiguous.

**Rejected alternative — a `unit` column:** Redundant and a validation surface for no gain. Rejected.

### Decision 6 — `client_record_id` idempotency, reused from Slice 3

**Choice:** `vitals_logs` carries a nullable `client_record_id` with `UNIQUE (user_id, client_record_id)`. A `POST` whose `client_record_id` already exists for the user returns the existing row unchanged (idempotent), exactly as `dose_logs`.

**Rationale:** Offline devices generate rows in bulk and may re-send on flaky links; the idempotency key deduplicates. Same contract the Slice 7 sync engine will use.

---

## 3. Migration

### `V5__create_vitals_logs.sql`

```sql
CREATE TABLE vitals_logs (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type              VARCHAR(20) NOT NULL,
    values            JSONB NOT NULL,
    flagged           BOOLEAN NOT NULL DEFAULT FALSE,
    measured_at       TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_vitals_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_vitals_user_measured ON vitals_logs(user_id, measured_at);
CREATE INDEX idx_vitals_user_type     ON vitals_logs(user_id, type);
```

Consistent with `dose_logs`: `ON DELETE CASCADE`, `client_record_id` idempotency, a `(user_id, measured_at)` index for history reads, plus `(user_id, type)` for per-type queries/charts.

---

## 4. The `type` enum, `values` contract, and thresholds

`VitalType`: `BLOOD_PRESSURE`, `GLUCOSE`, `HEART_RATE`, `WEIGHT`, `CHOLESTEROL`.

Per-type `values` keys, canonical units, and the **flag-when** conditions:

| Type | `values` keys | Unit | Flag when |
|------|--------------|------|-----------|
| `BLOOD_PRESSURE` | `systolic`, `diastolic` (both required; `systolic > diastolic`) | mmHg | systolic ≥ 180 **or** ≤ 90, **or** diastolic ≥ 120 **or** ≤ 60 |
| `GLUCOSE` | `glucose` | mmol/L | < 4.0 **or** > 11.1 |
| `HEART_RATE` | `heartRate` (integer) | bpm | < 40 **or** > 120 |
| `WEIGHT` | `weight` (+ server-added `bmi` when height known) | kg | BMI ≥ 30 **or** < 18.5 (only when BMI computable; unflagged if no height) |
| `CHOLESTEROL` | `ldl`, `hdl`, `total` (all required) | mmol/L | LDL ≥ 4.9 **or** total ≥ 7.5 **or** HDL < 1.0 |

**Threshold basis:** hypertensive crisis / hypotension (BP), hypo-/hyperglycemia (glucose), brady-/tachycardia at rest (heart rate), obese/underweight (BMI), very-high lipids / low HDL (cholesterol). These are **adopted documented defaults** — standard urgent-alert bounds, confirmable against a clinical source and adjustable later.

**Adjustability requirement:** thresholds live in a single `VitalThresholds` class, each type's bounds expressed as a small per-type threshold record (e.g. a `record Range(BigDecimal low, BigDecimal high)` per key). This is the deliberate seam for later change: the class can be promoted to `@ConfigurationProperties` bound from `application.yml` **without touching the flag logic**. Externalizing to config is out of scope for this slice (no immediate need); the class boundary is the "adjust later" contract.

**BMI:** `bmi = weight_kg / (height_m)²`, `height_m = height_cm / 100`, rounded to 1 decimal (`BigDecimal`, `HALF_UP`). Injected into the `WEIGHT` row's `values` at write time; absent when `height_cm` is null.

---

## 5. Endpoints (base `/api/v1`)

All require a Bearer JWT; all are scoped to the authenticated user (`UserPrincipal.userId()`); all responses use the shared `ApiResponse<T>` envelope. Same conventions as Slice 3.

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/vitals` | Log a reading. Server computes `flagged` (and `bmi` for weight), returns the persisted entry. Idempotent on `client_record_id`. |
| `GET` | `/vitals?type=&from=&to=` | Full vitals history for the user; optional `type` (enum), `from`/`to` (ISO dates, filter on `measured_at`). Ordered by `measured_at` desc. |

### Request / response shapes

**`POST /vitals` request (`VitalLogRequest`):**
```json
{
  "type": "BLOOD_PRESSURE",
  "values": { "systolic": 190, "diastolic": 100 },
  "measuredAt": "2026-07-10T08:15:00Z",   // optional; defaults to now (UTC)
  "note": "felt dizzy",                     // optional, ≤ 500 chars
  "clientRecordId": "…uuid…"                // optional
}
```
Any `flagged` or `bmi` supplied by the client is ignored.

**Response (`VitalLogResponse`):**
```json
{
  "id": "…uuid…",
  "type": "BLOOD_PRESSURE",
  "values": { "systolic": 190, "diastolic": 100 },
  "flagged": true,
  "measuredAt": "2026-07-10T08:15:00Z",
  "note": "felt dizzy",
  "clientRecordId": "…uuid…",
  "createdAt": "2026-07-10T08:15:02Z"
}
```
A `WEIGHT` response with a stored height returns `"values": {"weight": 72.0, "bmi": 23.5}`.

---

## 6. Package layout (package-by-feature)

```
com.heartcare.vitals/
├── VitalsController.java        # POST /vitals, GET /vitals
├── VitalsService.java           # flag + BMI computation, idempotency, ownership scope
├── VitalsRepository.java        # findByUserIdAndClientRecordId; findHistory(userId, type, from, to)
├── VitalThresholds.java         # documented clinical constants + flag(type, values) logic
├── model/
│   ├── VitalLog.java            # @Entity; @JdbcTypeCode(SqlTypes.JSON) Map<String,BigDecimal> values
│   └── VitalType.java           # enum
└── dto/
    ├── VitalLogRequest.java     # type, values, measuredAt?, note?, clientRecordId?
    └── VitalLogResponse.java    # id, type, values, flagged, measuredAt, note, clientRecordId, createdAt
```

Reuses shared infrastructure: `common.response.ApiResponse`, `common.security.UserPrincipal`, `common.exception.GlobalExceptionHandler` (401/404/400/malformed-body), and the Slice 3 profile-lookup for height (read via the existing patient-profile repository/JPA within the vitals feature boundary — see §8).

**Entity JSONB mapping** reuses the exact Slice 3 approach: `@JdbcTypeCode(SqlTypes.JSON)` on the `values` field (typed as `Map<String, BigDecimal>`), verified round-tripping on real Postgres.

---

## 7. Validation

Returns `400` via the existing `GlobalExceptionHandler` (reuses Slice 3's `@Valid` + malformed-body handling).

- **`type`** — required; must be a known `VitalType` (unknown → 400, like invalid `frequency` in Slice 3).
- **`values`** — required; **per-type structural validation in the service**: exactly the required keys for the type, all numeric, each within a sane physiological range (`systolic`/`diastolic` 40–300, `glucose` 0–50, `heartRate` 20–300, `weight` 0–500, cholesterol keys 0–30). Missing keys, unknown keys, or non-numeric values → 400.
- **`BLOOD_PRESSURE`** — cross-field: `systolic > diastolic` (else 400).
- **`measuredAt`** — optional; defaults to `OffsetDateTime.now(ZoneOffset.UTC)` when null (same pattern as `dose_logs.logged_at`).
- **`note`** — optional, `@Size(max = 500)`.
- **`clientRecordId`** — optional UUID.
- **`flagged` / `bmi`** — ignored if present (server owns them).

The physiological ranges are *input sanity* bounds (reject typos/garbage); they are distinct from the §4 *clinical alert* thresholds (which set `flagged` on physiologically-valid but dangerous readings). A reading can be valid-but-flagged (e.g. systolic 190) or rejected-as-invalid (e.g. systolic 900).

---

## 8. Cross-feature access (height for BMI)

BMI needs the patient's `height_cm` from `patient_profiles` (Slice 2). Per the architectural rule "features never import each other's internals," `VitalsService` reads height through the patient feature's **repository/JPA interface**, not its DTOs or service internals — a narrow, read-only dependency on `height_cm`. If the profile or height is absent, BMI is simply omitted (no error). This is the first cross-feature read in the backend; the design keeps it to a single well-defined lookup.

> Implementation note for the plan: prefer injecting the existing `PatientProfileRepository` (or a minimal height-lookup method on it) over reaching into profile DTOs/services. The plan step should confirm the exact Slice 2 repository name and method.

---

## 9. Testing strategy (TDD)

- **`VitalThresholdsTest`** (unit, no Spring): for each type — a just-inside-bounds reading is not flagged; at/over each bound (both high and low edges) is flagged; BMI-based weight flag (≥30 and <18.5); a weight reading with no computable BMI is never flagged.
- **`VitalsServiceTest`** (unit, mocked repositories): server computes `flagged`; BMI injected from profile height; BMI absent when height null; idempotent create returns the existing row when `clientRecordId` repeats; `measuredAt` defaults when null; client-sent `flagged`/`bmi` ignored; history delegates to the repository with `type`/`from`/`to` filters.
- **`VitalsControllerIntegrationTest`** (`@SpringBootTest` + Testcontainers Postgres, MockMvc; reuses the Slice 1 `AbstractIntegrationTest`; a test user registers through the real auth endpoint, black-box):
  - unauthenticated → 401;
  - POST each of the five types, then read them back via `GET /vitals`; JSONB `values` persists/reloads on real Postgres;
  - `type` and `from`/`to` filtering;
  - idempotent re-POST with the same `clientRecordId` returns one row;
  - 400 on invalid type, missing/unknown `values` key, non-numeric value, and `systolic ≤ diastolic`;
  - a flagged reading (e.g. systolic 190) persists `flagged = true`; an in-range reading persists `flagged = false`;
  - a `WEIGHT` reading for a user whose profile has a height returns a computed `bmi`; for a user with no height, `bmi` is absent.

---

## 10. Documentation updates (end of slice)

- `backend/README.md` — flip Slice 4 to ✅ in the build-progress table.
- `backend/docs/API.md` — add the two vitals endpoints (auth, request/response envelope, per-type `values` keys, server-computed `flagged`/`bmi`).
- `backend/docs/DATABASE.md` — add the `vitals_logs` table and the `V5` migration-log entry.

---

## 11. "Done" criteria

- `mvn spring-boot:run` boots; Flyway applies `V5` on top of `V4`.
- A logged-in patient can log all five vital types, receive server-computed `flagged` (and `bmi` for weight), and read back the full history filtered by type and date range — end-to-end; unauthenticated → 401; invalid input → 400.
- Repeated `POST` with the same `client_record_id` yields exactly one row (idempotency verified on real Postgres).
- Threshold flagging matches the §4 table; thresholds are centralized in `VitalThresholds` and adjustable without touching flag logic.
- `mvn test` green (unit + integration; JSONB `values` and threshold/BMI logic validated on real Postgres).
- README progress + `API.md` + `DATABASE.md` reflect Slice 4.

---

## 12. Out of scope for Slice 4 (and where it lands)

- **Weight-trend / rate-of-change alerts** — analytics/alert-engine slice; needs baselines and windows. This slice flags weight only on acute BMI.
- **Server alert engine & push (FR-DEC / FR-NOT)** — `alerts` table + WebSocket; a later subsystem. The `flagged` boolean here is the input, not the notification.
- **Clinician cross-user read access (FR-COM)** — later clinician-scope slice.
- **Threshold externalization to `application.yml`** — the `VitalThresholds` class is structured for it, but the config binding itself is deferred until there's a need to tune without a redeploy.
- **Sync routing (Slice 7)** — this slice only provides the idempotency key and idempotent create.
