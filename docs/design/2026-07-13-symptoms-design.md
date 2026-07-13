# Backend Design — Slice 5 (Symptom Monitoring)

**Project:** Heart-Care App (UOW Capstone — Project 29)
**Date:** 2026-07-13
**Status:** Approved for implementation planning
**Scope of this spec:** Detailed design of **Slice 5 — Symptom Monitoring** (daily symptom check-in capture, server-computed clinical severity assessment, check-in history; migration `V6__create_symptom_logs.sql`). Builds on the architecture and conventions established in `2026-06-30-backend-foundation-auth-design.md`, `2026-07-04-patient-profile-design.md`, `2026-07-09-medications-dose-logs-design.md`, and `2026-07-10-vitals-design.md`.

---

## 0. Requirements-approval caveat

`FUNCTIONAL_REQUIREMENTS.md §6 (Symptom Monitoring)` carries the note **"further discussion and approval waiting."** Per the project owner's direction, this slice proceeds against the **documented** requirements (FR-SYM-001…011) as the working spec. Every place where the requirements are ambiguous, this design makes an explicit assumption and marks it **⚠️ ASSUMPTION** so it is cheap to revisit if the requirements change on review. In particular, the **clinical severity rules in §4 require clinical sign-off** before this feature is considered production-ready; the code structures them as centralized, adjustable constants precisely so tuning them later touches one class.

---

## 1. Context & Goal

Slices 1–4 delivered auth, the patient profile, medications + dose logs, and vitals. Slice 5 adds the **third time-series log** feature: the daily symptom check-in a patient records over time. Like dose logs and vitals, these rows are generated on-device (often offline) and reuse the `client_record_id` idempotency key that the Slice 7 sync engine will rely on.

Per the offline-first architecture, the device is the source of truth for *when* and *what* was recorded. The backend's job in this slice is to **persist and serve** check-ins and — as with the vitals `flagged` value — to compute the piece of **clinical truth** that must not depend on a particular app version: the **severity assessment** (`FR-SYM-010`), a per-symptom and overall urgency classification.

### Requirements covered (`FUNCTIONAL_REQUIREMENTS.md §6`)

| FR | Description | Priority | This slice |
|---|---|---|---|
| FR-SYM-001 | Complete a daily symptom check-in | P1 | ✅ (`POST /symptoms`) |
| FR-SYM-002 | Capture chest pain (Yes/No + severity) | P1 | ✅ |
| FR-SYM-003 | Capture shortness of breath (None / Mild / Severe) | P1 | ✅ |
| FR-SYM-004 | Capture resting heart rate (bpm) | P1 | ✅ (self-contained snapshot; see §2 Decision 2) |
| FR-SYM-005 | Capture blood pressure (systolic / diastolic) | P1 | ✅ (self-contained snapshot; see §2 Decision 2) |
| FR-SYM-006 | Capture leg/ankle swelling (Yes/No) | P1 | ✅ |
| FR-SYM-007 | Capture energy/activity level (0–10) | P1 | ✅ |
| FR-SYM-008 | "Worse than yesterday?" per symptom | P2 | ✅ (client-reported field; server does not compute — see §2 Decision 5) |
| FR-SYM-009 | Store check-in history; review past entries | P1 | ✅ (`GET /symptoms` with date filters) |
| FR-SYM-010 | Clinical interpretation + recommended action per severity | P1 | ✅ (server-authoritative severity codes; action text rendered client-side — see §2 Decision 3) |
| FR-SYM-011 | Stored locally first, synced when online | P1 | ✅ (server side of the sync contract; `client_record_id`) |

### Deferred (out of scope for this slice)

- **Deterioration / trend computation** — "worse than yesterday" as a *computed* signal, and any multi-day symptom trend, needs a history/baseline lookup and windowing; belongs with the analytics/alert-engine slice. This slice stores the patient's own per-symptom "worse than yesterday" answer verbatim (P2) but computes nothing across days. See §2 Decision 5.
- **Server alert engine & notifications (FR-DEC / FR-NOT)** — the stored `overall_severity` is data, not a push. The `alerts` table + delivery is a separate later subsystem. This slice records *that* a check-in reached a severity; acting on it is deferred. FR-NOT-005 (daily check-in reminder) is a client/notification concern, not this slice.
- **Recommended-action wording & localization (FR-SYM-010 text)** — the server returns a severity *code*; the EN/AM action text is rendered client-side from a documented `level → action` mapping. See §2 Decision 4.
- **Clinician read access (FR-COM)** — cross-user access is a later clinician-scope slice; all endpoints here are patient-self-scoped.
- **Offline sync routing** — handled by the Slice 7 sync engine. This slice only lays down the idempotency key.

---

## 2. Design Decisions

Each decision records the choice, the rationale, and the rejected alternative, so a future change starts with full context.

### Decision 1 — One row per check-in, fields in JSONB

**Choice:** One `symptom_logs` row represents **one complete daily check-in**. The heterogeneous symptom fields live in a JSONB `data` map (§3). A check-in is a single event, not several typed rows.

**Rationale:** A symptom check-in is inherently a *composite* — chest pain, shortness of breath, heart rate, blood pressure, swelling, and energy are captured together as one clinical snapshot, and the severity assessment (`FR-SYM-010`) is naturally computed over the whole set. This differs from vitals, where each row is one independent metric reading discriminated by `type`; there is no useful "type" discriminator for a check-in. JSONB matches this codebase's established typed-column-beside-JSONB pattern (`vitals_logs.values`, `medications.schedule_times`, `patient_profiles.goals`) and lets the field set evolve (e.g. new symptoms) without a migration.

**Rejected alternative — one typed row per symptom (the vitals shape):** Would shred a single check-in into ~6 rows sharing a check-in id, making "one check-in" a join and the overall-severity computation a cross-row aggregate. Awkward and unnatural for a composite event. Rejected.

**Rejected alternative — a wide column per symptom:** Nullable columns for every symptom field; every new symptom is a migration, and the nested shapes (chest pain = present + severity; BP = systolic + diastolic) don't map cleanly to flat columns. Rejected in favour of JSONB, consistent with the rest of the schema.

### Decision 2 — Heart rate & blood pressure are a self-contained snapshot

**Choice:** The check-in captures `heartRate` and `bloodPressure` (`FR-SYM-004/005`) as plain values **inside its own `data` JSONB**. The symptoms feature does **not** read from or write to `vitals_logs`, and takes **no dependency on the vitals feature**.

**Rationale:** Keeps the symptoms feature fully standalone (honours CLAUDE.md rule #1 — features don't import each other) and keeps the check-in an atomic, self-describing record. The check-in's HR/BP is contextual to that check-in (captured to inform the symptom assessment), conceptually distinct from a deliberate standalone vitals reading.

**Rejected alternative — the check-in also spawns `vitals_logs` rows:** Would keep vitals history/charts "complete" but introduces a cross-feature write dependency on `VitalsService`, plus flagging and idempotency concerns for the spawned rows, and blurs the ownership boundary. Rejected as unnecessary coupling for this slice. (If a unified HR/BP timeline is wanted later, it belongs in the analytics/dashboard slice, which can read both tables.)

**⚠️ ASSUMPTION:** the check-in's HR/BP are not surfaced in the vitals history endpoint; the two datasets are independent.

### Decision 3 — Severity assessment is computed server-side and is authoritative

**Choice:** On every write the server computes, from documented rules (§4): a **severity code per symptom** and an **overall** level = the maximum across symptoms. It stores the full assessment (snapshot) and returns it. Any assessment supplied in the request body is **ignored** (overwritten).

**Rationale:** Clinical interpretation is *truth*, not a per-device opinion — identical reasoning to the vitals `flagged` value (vitals design Decision 2). A clinician viewing the data later (or the future alert engine) must trust the classification regardless of which app version wrote the row. The rules are static constants with no clock/timezone dependency, so server-side computation does not reintroduce the "server knows now" problem. The device can still classify locally for instant offline UX using the same documented rules; the server value is the authoritative one that persists.

**Rejected alternative — client sends the severity, server persists verbatim:** Server cannot verify it, two app versions could disagree, and clinical rules are baked into the client. Rejected — unacceptable for a health classification clinicians and the alert engine will rely on.

### Decision 4 — Server returns severity *codes*; action text is rendered client-side

**Choice:** The assessment carries only enum **codes** (`NONE` / `MONITOR` / `URGENT` / `EMERGENCY`). The **recommended-action text** (`FR-SYM-010`, e.g. "Severe chest pain → call emergency contact") is a documented `level → action` mapping the client renders, localized EN/AM.

**Rationale:** The app is bilingual (English & Amharic) and this codebase keeps localization on the client (`easy_localization`). Storing English action text server-side would either be English-only or force the server to take on localization it otherwise doesn't own. A stable code is language-neutral, snapshot-friendly, and lets the wording be refined without a data migration. The mapping is documented in `API.md`.

**Rejected alternative — server returns/stores action text:** Couples the server to presentation and language. Rejected.

### Decision 5 — "Worse than yesterday" is client-reported, not computed

**Choice:** `FR-SYM-008` (P2) is stored as the patient's own per-symptom answer inside `data.worseThanYesterday`. The server does **not** derive deterioration by comparing to prior check-ins.

**Rationale:** Computing deterioration requires a per-symptom baseline and a "yesterday" lookup — trend logic that belongs with the analytics/alert-engine slice, not a write-time classification. Storing the patient's self-report satisfies the P2 requirement now without that machinery. Consistent with the vitals decision to defer rate-of-change alerts.

**Rejected alternative — server computes "worse than yesterday" from history:** Adds a history read and baseline definition to every write for a P2 field. Rejected — deferred to analytics.

### Decision 6 — Append-only, immutable check-ins

**Choice:** No update or delete endpoints. A check-in is an immutable event; a correction is a new row. Mirrors `vitals_logs` and `dose_logs`.

**Rationale:** Fits offline-first and preserves the audit trail. No mutable server state to reconcile on sync.

**⚠️ ASSUMPTION:** `FR-SYM-001` says "daily" check-in; this is treated as a *cadence*, not a uniqueness constraint. The server does **not** enforce one-check-in-per-day (offline devices may legitimately produce more than one, and enforcing a per-day unique key fights the append-only/idempotency model). Duplicate suppression is handled only by `client_record_id`.

### Decision 7 — `client_record_id` idempotency, reused from Slices 3–4

**Choice:** `symptom_logs` carries a nullable `client_record_id` with `UNIQUE (user_id, client_record_id)`. A `POST` whose `client_record_id` already exists for the user returns the existing row unchanged (idempotent), exactly as `vitals_logs` and `dose_logs`.

**Rationale:** Offline devices generate rows in bulk and may re-send on flaky links; the key deduplicates. Same contract the Slice 7 sync engine will use.

---

## 3. Migration

### `V6__create_symptom_logs.sql`

```sql
CREATE TABLE symptom_logs (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    data              JSONB NOT NULL,
    assessment        JSONB NOT NULL,
    overall_severity  VARCHAR(20) NOT NULL,
    measured_at       TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_symptom_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_symptom_user_measured ON symptom_logs(user_id, measured_at);
CREATE INDEX idx_symptom_user_severity ON symptom_logs(user_id, overall_severity);
```

- `data` — the check-in fields the patient entered (§4 contract).
- `assessment` — the server-computed `{ overall, symptoms: {...} }` snapshot (§4). Stored so history never drifts if the rules are later tuned (same snapshot rationale as vitals `flagged`/`bmi`).
- `overall_severity` — `assessment.overall` duplicated into a queryable column (mirrors how vitals splits the `flagged` column from the `values` JSONB). Enables cheap severity filtering for the future risk dashboard (`FR-DASH`) and alert engine without indexing into JSONB.
- Consistent with `vitals_logs`: `ON DELETE CASCADE`, `client_record_id` idempotency, a `(user_id, measured_at)` index for history reads, plus `(user_id, overall_severity)` for severity queries.

---

## 4. The `data` contract, `Severity`, and assessment rules

### 4.1 Check-in `data` keys

| Key | Type | Required | FR |
|---|---|---|---|
| `chestPain` | object `{ "present": bool, "severity": int 0–10 }` — `severity` required **iff** `present` is true; omitted/ignored when false | ✅ | SYM-002 |
| `shortnessOfBreath` | enum string: `NONE` \| `MILD` \| `SEVERE` | ✅ | SYM-003 |
| `heartRate` | int, bpm | ✅ | SYM-004 |
| `bloodPressure` | object `{ "systolic": int, "diastolic": int }`, mmHg (`systolic > diastolic`) | ✅ | SYM-005 |
| `swelling` | bool | ✅ | SYM-006 |
| `energyLevel` | int, 0–10 | ✅ | SYM-007 |
| `worseThanYesterday` | object, optional per-symptom booleans, e.g. `{ "chestPain": true, "shortnessOfBreath": false }`; **client-reported** | ❌ (P2) | SYM-008 |

**⚠️ ASSUMPTION:** all P1 fields are **required** in a check-in, reading "the check-in *shall capture* X" literally. This forces HR/BP entry even without a home device — a real UX concern flagged for the pending requirements review. If review relaxes this, the affected fields become optional and their severity contribution is skipped when absent.

**Input-sanity ranges** (reject typos/garbage, distinct from the §4.3 clinical rules): `heartRate` 20–300; `bloodPressure.systolic`/`diastolic` 40–300; `chestPain.severity` 0–10; `energyLevel` 0–10. Out-of-range → 400.

### 4.2 `Severity` enum

`NONE` < `MONITOR` < `URGENT` < `EMERGENCY` — a 4-level ordinal scale. The overall level is the **maximum** severity across the individual symptom classifications. The client maps each level to localized recommended-action text (documented in `API.md`), e.g. `EMERGENCY → "Call your emergency contact now"`.

### 4.3 Per-symptom assessment rules (documented defaults — ⚠️ require clinical sign-off)

These are **adopted documented defaults**, structured for adjustment. They live in a single `SymptomAssessment` class, each symptom's mapping expressed as small documented constants — the deliberate seam for later change (promotable to `@ConfigurationProperties` without touching the classification logic), exactly like `VitalThresholds`.

| Symptom | Rule → level |
|---|---|
| `chestPain` | not present → `NONE`; severity 1–3 → `MONITOR`; 4–6 → `URGENT`; 7–10 → `EMERGENCY` |
| `shortnessOfBreath` | `NONE` → `NONE`; `MILD` → `MONITOR`; `SEVERE` → `URGENT` |
| `bloodPressure` | systolic ≥ 180 → `EMERGENCY`; systolic ≥ 160 or ≤ 90, or diastolic ≥ 100 or ≤ 60 → `URGENT`; else `NONE` |
| `heartRate` | < 40 or > 120 → `URGENT`; else `NONE` |
| `swelling` | true → `MONITOR`; false → `NONE` |
| `energyLevel` | ≤ 2 → `MONITOR`; else `NONE` |

`overall = max(all of the above)`.

**Clinical basis:** severe chest pain and hypertensive crisis are the emergency triggers (`FR-SYM-010`'s worked example is "severe chest pain → emergency"); severe dyspnoea, brady/tachycardia, and moderately deranged BP warrant an urgent review; swelling (fluid retention) and low energy are monitor-level soft signals. **These bounds are defaults pending the §0 clinical sign-off**, not settled clinical policy.

**Intentional duplication:** the HR/BP bounds resemble the vitals thresholds, but `SymptomAssessment` keeps its **own** constants and does not import from the vitals feature (CLAUDE.md rule #1). If a single source of clinical constants is later wanted, the refactor is to lift them into `core/` — noted, not done in this slice.

---

## 5. Endpoints (base `/api/v1`)

All require a Bearer JWT; all are scoped to the authenticated user (`UserPrincipal.userId()`); all responses use the shared `ApiResponse<T>` envelope. Same conventions as Slices 3–4.

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/symptoms` | Log a check-in. Server computes `assessment`, returns the persisted entry. Idempotent on `clientRecordId`. |
| `GET` | `/symptoms?from=&to=` | Check-in history for the user; optional `from`/`to` (ISO dates, filter on `measured_at`). Ordered by `measured_at` desc. |

There is no `type` filter (a check-in isn't typed, unlike vitals).

### Date filtering (reused from vitals)

`from`/`to` are ISO calendar dates bucketed by **UTC day** via a half-open range `[from 00:00Z, day-after-to 00:00Z)` — the exact pattern established in `VitalsService` (commit `3e51c22`). `from` null → open lower bound; `to` null → open upper bound (sentinel instants). The repository query compares `measured_at >= :fromTs AND measured_at < :toTs`.

### Request / response shapes

**`POST /symptoms` request (`SymptomLogRequest`):**
```json
{
  "data": {
    "chestPain": { "present": true, "severity": 8 },
    "shortnessOfBreath": "MILD",
    "heartRate": 82,
    "bloodPressure": { "systolic": 165, "diastolic": 92 },
    "swelling": true,
    "energyLevel": 4,
    "worseThanYesterday": { "chestPain": true }
  },
  "measuredAt": "2026-07-13T07:30:00Z",   // optional; defaults to now (UTC)
  "note": "woke up with tight chest",      // optional, ≤ 500 chars
  "clientRecordId": "…uuid…"               // optional
}
```
Any `assessment` supplied by the client is ignored.

**Response (`SymptomLogResponse`):**
```json
{
  "id": "…uuid…",
  "data": {
    "chestPain": { "present": true, "severity": 8 },
    "shortnessOfBreath": "MILD",
    "heartRate": 82,
    "bloodPressure": { "systolic": 165, "diastolic": 92 },
    "swelling": true,
    "energyLevel": 4,
    "worseThanYesterday": { "chestPain": true }
  },
  "assessment": {
    "overall": "EMERGENCY",
    "symptoms": {
      "chestPain": "EMERGENCY",
      "shortnessOfBreath": "MONITOR",
      "bloodPressure": "URGENT",
      "heartRate": "NONE",
      "swelling": "MONITOR",
      "energyLevel": "NONE"
    }
  },
  "measuredAt": "2026-07-13T07:30:00Z",
  "note": "woke up with tight chest",
  "clientRecordId": "…uuid…",
  "createdAt": "2026-07-13T07:30:02Z"
}
```

---

## 6. Package layout (package-by-feature)

```
com.heartcare.symptoms/
├── SymptomsController.java       # POST /symptoms, GET /symptoms
├── SymptomsService.java          # assessment computation, idempotency, ownership scope, date-bounds conversion
├── SymptomsRepository.java       # findByUserIdAndClientRecordId; findHistory(userId, fromTs, toTs)
├── SymptomAssessment.java        # documented clinical rules + assess(data) -> Assessment
├── model/
│   ├── SymptomLog.java           # @Entity; @JdbcTypeCode(SqlTypes.JSON) data + assessment (Map/JsonNode)
│   └── Severity.java             # enum NONE < MONITOR < URGENT < EMERGENCY
└── dto/
    ├── SymptomLogRequest.java    # data, measuredAt?, note?, clientRecordId?
    └── SymptomLogResponse.java   # id, data, assessment, measuredAt, note, clientRecordId, createdAt
```

Reuses shared infrastructure: `common.response.ApiResponse`, `common.security.UserPrincipal`, `common.exception.GlobalExceptionHandler` (401/404/400/malformed-body incl. the Slice 4 `BadRequestException→400`). **No cross-feature dependency** (contrast vitals' profile-height read).

**Entity JSONB mapping** reuses the established `@JdbcTypeCode(SqlTypes.JSON)` approach. `data` holds heterogeneous, nested shapes (nested objects, mixed value types), so — unlike vitals' flat `Map<String, BigDecimal>` — it is mapped as a nested `Map<String, Object>` (or Jackson `JsonNode`); the plan step confirms the exact type that round-trips cleanly on Postgres under `ddl-auto=validate`. `assessment` is likewise a small nested map. The service validates the structured shape explicitly (§4/§7) rather than relying on the map type.

---

## 7. Validation

Returns `400` via the existing `GlobalExceptionHandler` (reuses the Slice 3/4 `@Valid` + `BadRequestException` handling).

- **`data`** — required; **structural validation in the service**: exactly the required keys present (§4.1), each of the correct shape/type, each numeric field within its input-sanity range.
- **`chestPain`** — `present` required boolean; if `present` is true, `severity` (0–10) required; if false, `severity` is ignored.
- **`shortnessOfBreath`** — required; must be a known `NONE`/`MILD`/`SEVERE` (unknown → 400).
- **`bloodPressure`** — `systolic`/`diastolic` required, in range, `systolic > diastolic` (else 400) — same cross-field rule as vitals BP.
- **`heartRate`, `energyLevel`, `swelling`** — required; type/range checked.
- **`worseThanYesterday`** — optional; if present, an object of booleans keyed by known symptom names (unknown keys → 400).
- **`measuredAt`** — optional; defaults to `OffsetDateTime.now(ZoneOffset.UTC)` when null.
- **`note`** — optional, `@Size(max = 500)`.
- **`clientRecordId`** — optional UUID.
- **`assessment`** — ignored if present (server owns it).

The input-sanity ranges (reject typos/garbage) are distinct from the §4.3 clinical rules (which set severity on physiologically-valid but dangerous entries). A check-in can be valid-but-`EMERGENCY` (chest pain severity 9) or rejected-as-invalid (heartRate 900).

---

## 8. Testing strategy (TDD)

- **`SymptomAssessmentTest`** (unit, no Spring): for each symptom — a not-flagged input yields `NONE`; each threshold edge yields the documented level (chest-pain severity 3/4/6/7 boundaries; SOB MILD/SEVERE; BP 160/180 and 90/60 edges; HR 40/120 edges; swelling true; energy 2/3). `overall` = max across symptoms (e.g. one `EMERGENCY` symptom drives overall `EMERGENCY`; all-benign → `NONE`).
- **`SymptomsServiceTest`** (unit, mocked repository): server computes `assessment` and `overall_severity`; idempotent create returns the existing row when `clientRecordId` repeats; `measuredAt` defaults when null; client-sent `assessment` ignored; history delegates to the repository with the correct UTC `[fromTs, toTs)` bounds (mirrors `VitalsServiceTest`); invalid `data` shapes throw `BadRequestException`.
- **`SymptomsControllerIntegrationTest`** (`@SpringBootTest` + Testcontainers Postgres, MockMvc; reuses `AbstractIntegrationTest`; a test user registers through the real auth endpoint, black-box):
  - unauthenticated → 401;
  - POST a full check-in, then read it back via `GET /symptoms`; nested JSONB `data`/`assessment` persists/reloads on real Postgres;
  - `from`/`to` UTC-day filtering (including the midnight-boundary bucketing case, as in vitals);
  - idempotent re-POST with the same `clientRecordId` returns one row;
  - 400 on missing/unknown `data` key, wrong type, out-of-range value, bad `shortnessOfBreath` enum, and `systolic ≤ diastolic`;
  - an `EMERGENCY`-level check-in (chest pain severity 9) persists `overall_severity = EMERGENCY` and the per-symptom map; an all-benign check-in persists `NONE`.

---

## 9. Documentation updates (end of slice)

- `backend/README.md` — flip Slice 5 to ✅ in the build-progress table.
- `backend/docs/API.md` — add the two symptom endpoints (auth, request/response envelope, `data` keys, server-computed `assessment`, and the documented `Severity → recommended-action` client mapping for `FR-SYM-010`).
- `backend/docs/DATABASE.md` — add the `symptom_logs` table and the `V6` migration-log entry.

---

## 10. "Done" criteria

- `mvn spring-boot:run` boots; Flyway applies `V6` on top of `V5`.
- A logged-in patient can submit a daily check-in, receive a server-computed per-symptom + overall `assessment`, and read back the full history filtered by date range — end-to-end; unauthenticated → 401; invalid input → 400.
- Repeated `POST` with the same `client_record_id` yields exactly one row (idempotency verified on real Postgres).
- Severity classification matches the §4.3 table; rules are centralized in `SymptomAssessment` and adjustable without touching classification logic.
- `mvn test` green (unit + integration; nested JSONB `data`/`assessment` and assessment logic validated on real Postgres).
- README progress + `API.md` + `DATABASE.md` reflect Slice 5.

---

## 11. Out of scope for Slice 5 (and where it lands)

- **Symptom trend / deterioration computation** — analytics/alert-engine slice; needs baselines and windows. This slice stores the patient's self-reported "worse than yesterday" only.
- **Server alert engine & push (FR-DEC / FR-NOT)** — `alerts` table + delivery; a later subsystem. The `overall_severity` here is the input, not the notification. FR-NOT-005 daily reminder is a client concern.
- **Recommended-action wording / localization** — client renders EN/AM from the documented `level → action` mapping; the server returns codes only.
- **Clinician cross-user read access (FR-COM)** — later clinician-scope slice.
- **Clinical-rule externalization to `application.yml`** — `SymptomAssessment` is structured for it, but the config binding itself is deferred until there's a need to tune without a redeploy. The §4.3 defaults still require clinical sign-off (§0).
- **Sync routing (Slice 7)** — this slice only provides the idempotency key and idempotent create.
- **Unified HR/BP timeline across symptoms + vitals** — a dashboard/analytics concern that can read both tables; not done here (Decision 2).
