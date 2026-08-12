# Backend Design — Slice 6 (Activity Logging)

**Project:** Heart-Care App (UOW Capstone — Project 29)
**Date:** 2026-07-16
**Status:** Approved for implementation planning
**Scope of this spec:** Detailed design of **Slice 6 — Activity Logging** (patient logs a physical-activity session, activity history; migration `V7__create_activity_logs.sql`). Builds on the architecture and conventions established across Slices 1–5, most directly `2026-07-10-vitals-design.md` and `2026-07-13-symptoms-design.md`.

---

## 0. Requirements-approval caveat

`FUNCTIONAL_REQUIREMENTS.md §7 (Physical Activity Guidance)` carries the note **"further discussion and approval waiting."** Per the project owner's direction, this slice proceeds against the **documented** requirements as the working spec. Where the requirements are ambiguous, this design makes an explicit choice and marks it **⚠️ ASSUMPTION** so it is cheap to revisit on review. Unlike Slices 4–5, this slice computes **no clinical value**, so there are no clinical thresholds pending sign-off here.

---

## 1. Context & Goal

Slices 1–5 delivered auth, patient profile, medications + dose logs, vitals, and symptoms. Slice 6 adds the **fourth time-series log** feature: a physical-activity session the patient records over time. Like dose logs, vitals, and symptom check-ins, these rows are generated on-device (often offline) and reuse the `client_record_id` idempotency key that the Slice 7 sync engine will rely on.

Section 7 of the requirements splits into two very different kinds of work:

- **Static activity guidance** (FR-ACT-001 evidence-based guidelines, FR-ACT-002 "indications to terminate activity", FR-ACT-004 culturally-relevant Ethiopian suggestions, FR-ACT-005 fully-offline display) — reference content, not per-user data. It is bundled in the app and rendered client-side, exactly as Education content is handled (see [[scope-decisions]]). **Out of backend scope** — see §2 Decision 3.
- **The activity log** (FR-ACT-003 log type/duration/intensity, FR-ACT-006 history) — the per-user time-series data. **This is the whole of the backend slice.**

The backend's job here is the simplest of any log slice: **persist and serve** activity sessions. There is no `flagged` (vitals) or `severity` (symptoms) equivalent — logging a 30-minute walk is not a classification event — so this slice has **no server-computed truth value** and no assessment machinery.

### Requirements covered (`FUNCTIONAL_REQUIREMENTS.md §7`)

| FR | Description | Priority | This slice |
|---|---|---|---|
| FR-ACT-003 | Log daily physical activity (type, duration, intensity) | P2 | ✅ (`POST /activities`) |
| FR-ACT-006 | Display the patient's activity log history | P2 | ✅ (`GET /activities` with date filters) |
| FR-ACT-007 | Track progress toward personalised daily steps goal | P3 | ⚠️ **data only** — optional `steps` field is captured so the future dashboard/analytics slice can compute progress against the profile goal, but no progress is computed here. See §2 Decision 4. |
| FR-OFF-001 | Log activity with no internet connection | P1 | ✅ (server side of the sync contract; `client_record_id`) |

### Deferred / out of scope for this slice (and where it lands)

- **Activity guidance content** (FR-ACT-001 / -002 / -004 / -005) — static, offline, client-rendered reference content bundled in the app (like Education). Not a backend concern. See §2 Decision 3.
- **Steps-goal progress computation** (FR-ACT-007) — a computed read (sum of steps vs. the profile's daily goal) that belongs with the dashboard/analytics slice (also FR-DASH-006 today's summary, FR-GRAPH-005 7/30-day activity trend). This slice only stores the raw `steps` so that computation has data later without a migration.
- **Server alert engine / notifications** — not applicable; activity logs produce no severity to act on.
- **Clinician cross-user read access (FR-COM)** — later clinician-scope slice, and being narrowed out per [[scope-decisions]]; all endpoints here are patient-self-scoped.
- **Offline sync routing** — handled by the Slice 7 sync engine. This slice only lays down the idempotency key.

---

## 2. Design Decisions

Each decision records the choice, the rationale, and the rejected alternative.

### Decision 1 — One row per activity session, fields in JSONB

**Choice:** One `activity_logs` row represents **one logged activity session**. The fields (`type`, `durationMinutes`, `intensity`, optional `steps`/`distanceMeters`) live in a JSONB `data` map (§4). 

**Rationale:** Matches this codebase's established typed-column-beside-JSONB pattern (`vitals_logs.values`, `symptom_logs.data`, `patient_profiles.goals`) and lets the field set evolve (e.g. adding `distanceMeters`, `heartRateAvg`) without a migration. A session is a small heterogeneous bundle (two enums, an int duration, optional numerics) rather than one scalar reading, so a JSONB map fits better than typed columns.

**Rejected alternative — wide typed columns per field:** Nullable columns for every optional metric; every new metric is a migration. Rejected in favour of JSONB, consistent with the rest of the schema.

### Decision 2 — No server-computed value; pure persist-and-serve

**Choice:** The server does **not** compute any classification, flag, severity, or derived metric on write. It validates the input shape/ranges, persists the record verbatim, and serves it back. There is **no `assessment` column and no `overall_*` column** (contrast `vitals_logs.flagged`, `symptom_logs.assessment`/`overall_severity`).

**Rationale:** Unlike a vitals reading (which can be out-of-range) or a symptom check-in (which carries clinical urgency), a logged activity session has no per-record "clinical truth" the server must own. FR-ACT-002's "indications to terminate activity" is **guidance shown to the patient in the moment** (static content), not a retrospective classification of a completed log. Adding a computed value here would invent clinical logic the requirements don't ask for. This makes Slice 6 the leanest log slice: no assessment class, no thresholds, no clinical sign-off gate.

**Rejected alternative — compute an "intensity/adequacy" flag (e.g. met/under daily goal):** That is exactly the FR-ACT-007 goal-progress read, which is cross-record (needs the profile goal + a day's worth of logs) and belongs in the dashboard/analytics slice, not a write-time per-row computation. Rejected — deferred (Decision 4).

### Decision 3 — Guidance content is client-side static, out of backend scope

**Choice:** FR-ACT-001 (guidelines), FR-ACT-002 (termination indications), FR-ACT-004 (Ethiopian-context suggestions), and FR-ACT-005 (offline display) are **not** served by the backend. They are static reference content bundled in the app and rendered client-side.

**Rationale:** These are the same shape as Education content, which [[scope-decisions]] already settled as client-bundled reference material (no backend CMS; FR-EDU backend content updates voided/stretch). FR-ACT-005 explicitly requires this content **fully offline** — bundling it in the app is the direct way to guarantee that and avoids a server round-trip the offline-first architecture is designed to eliminate. No per-user state is involved, so there is nothing for the server to persist.

**Rejected alternative — backend endpoints serving guidance content:** Adds a server dependency to P1 content that must work offline, and a content-management surface the project has explicitly deprioritised. Rejected.

### Decision 4 — `steps` is captured but goal-progress is not computed

**Choice:** The log captures an **optional** `steps` field (and optional `distanceMeters`). The server does **not** compute FR-ACT-007 progress toward the patient's daily steps goal.

**Rationale:** Goal progress is a cross-record read (sum of a day's `steps` ÷ the goal stored in `patient_profiles.goals`) that naturally belongs with the dashboard/analytics slice alongside FR-DASH-006 (today's activity summary) and FR-GRAPH-005 (7/30-day trend). Capturing the raw `steps` now means that slice — and the trend graphs — have data to work with **without a later migration**. FR-ACT-007 is P3; computing it now would pull profile-goal coupling and windowing into a simple write path.

**Rejected alternative — compute and return progress on each write:** Introduces a read of `patient_profiles` (cross-feature coupling, like vitals' height read) plus a same-day aggregation, for a P3 field. Rejected — deferred to analytics.

### Decision 5 — Append-only, immutable logs

**Choice:** No update or delete endpoints. An activity log is an immutable event; a correction is a new row. Mirrors `vitals_logs`, `symptom_logs`, and `dose_logs`.

**Rationale:** Fits offline-first and preserves the record trail. No mutable server state to reconcile on sync.

**⚠️ ASSUMPTION:** FR-ACT-003 says "daily" activity; treated as a *cadence*, not a uniqueness constraint. The server does **not** enforce one-log-per-day (a patient may legitimately log a morning walk and an evening one). Duplicate suppression is handled only by `client_record_id`.

### Decision 6 — `client_record_id` idempotency, reused from Slices 3–5

**Choice:** `activity_logs` carries a nullable `client_record_id` with `UNIQUE (user_id, client_record_id)`. A `POST` whose `client_record_id` already exists for the user returns the existing row unchanged (idempotent), exactly as the prior log tables.

**Rationale:** Offline devices generate rows in bulk and may re-send on flaky links; the key deduplicates. Same contract the Slice 7 sync engine will use.

### Decision 7 — `type` and `intensity` are curated enums

**Choice:** `type` is a fixed enum — `WALKING`, `JOGGING`, `CYCLING`, `HOUSEHOLD`, `FARMING`, `STRETCHING`, `OTHER` — and `intensity` is `LIGHT` / `MODERATE` / `VIGOROUS`. Unknown values → 400.

**Rationale:** A curated picklist is low-literacy- and offline-friendly, localizes cleanly EN/AM (client maps the enum to translated labels, same approach as `Severity`), aggregates well for the future trend graphs, and pairs naturally with the FR-ACT-004 culturally-relevant suggestions (which can nudge toward `WALKING`/`HOUSEHOLD`/`FARMING`). `OTHER` plus the optional free-text `note` covers the long tail. `LIGHT/MODERATE/VIGOROUS` is the standard CHD exercise-guidance intensity scale.

**Rejected alternative — free-text `type`:** No validation, harder to localize and aggregate, worse for low-literacy users. Rejected.

**⚠️ ASSUMPTION:** the `type` enum set above is a reasonable starting list for the Ethiopian context; it is trivial to extend (enum + client translations) and needs no migration since `type` lives in JSONB.

---

## 3. Migration

### `V7__create_activity_logs.sql`

```sql
CREATE TABLE activity_logs (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    data              JSONB NOT NULL,
    measured_at       TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_activity_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_activity_user_measured ON activity_logs(user_id, measured_at);
```

- `data` — the session fields the patient entered (§4 contract).
- **No `assessment` / `overall_*` columns** — this slice computes nothing (Decision 2). This is the one structural difference from `symptom_logs`.
- `measured_at` — when the activity happened (device-reported; defaults to now on the server if omitted).
- Consistent with the prior log tables: `ON DELETE CASCADE`, `client_record_id` idempotency, a `(user_id, measured_at)` index for history reads. No severity index (nothing to filter on).

---

## 4. The `data` contract

### 4.1 `data` keys

| Key | Type | Required | FR |
|---|---|---|---|
| `type` | enum string: `WALKING` \| `JOGGING` \| `CYCLING` \| `HOUSEHOLD` \| `FARMING` \| `STRETCHING` \| `OTHER` | ✅ | ACT-003 |
| `durationMinutes` | int, minutes | ✅ | ACT-003 |
| `intensity` | enum string: `LIGHT` \| `MODERATE` \| `VIGOROUS` | ✅ | ACT-003 |
| `steps` | int | ❌ | ACT-007 (data only) |
| `distanceMeters` | number | ❌ | ACT-006 / GRAPH-005 |

**Input-sanity ranges** (reject typos/garbage): `durationMinutes` 1–1440 (max one day); `steps` 0–100000; `distanceMeters` 0–100000. Out-of-range → 400. Unknown `type`/`intensity` enum values → 400.

`note` is a top-level optional field (its own column, ≤ 500 chars), not part of `data` — consistent with the prior log tables.

---

## 5. Endpoints (base `/api/v1`)

All require a Bearer JWT; all are scoped to the authenticated user (`UserPrincipal.userId()`); all responses use the shared `ApiResponse<T>` envelope. Same conventions as Slices 3–5.

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/activities` | Log an activity session. Persists and returns the entry. Idempotent on `clientRecordId`. |
| `GET` | `/activities?from=&to=` | Activity history for the user; optional `from`/`to` (ISO dates, filter on `measured_at`). Ordered by `measured_at` desc. |

### Date filtering (reused from vitals/symptoms)

`from`/`to` are ISO calendar dates bucketed by **UTC day** via a half-open range `[from 00:00Z, day-after-to 00:00Z)` — the exact pattern established in `VitalsService`/`SymptomsService`. `from` null → open lower bound; `to` null → open upper bound. The repository query compares `measured_at >= :fromTs AND measured_at < :toTs`.

### Request / response shapes

**`POST /activities` request (`ActivityLogRequest`):**
```json
{
  "data": {
    "type": "WALKING",
    "durationMinutes": 30,
    "intensity": "MODERATE",
    "steps": 3200,
    "distanceMeters": 2400
  },
  "measuredAt": "2026-07-16T06:30:00Z",   // optional; defaults to now (UTC)
  "note": "morning walk to the market",    // optional, ≤ 500 chars
  "clientRecordId": "…uuid…"               // optional
}
```

**Response (`ActivityLogResponse`):**
```json
{
  "id": "…uuid…",
  "data": {
    "type": "WALKING",
    "durationMinutes": 30,
    "intensity": "MODERATE",
    "steps": 3200,
    "distanceMeters": 2400
  },
  "measuredAt": "2026-07-16T06:30:00Z",
  "note": "morning walk to the market",
  "clientRecordId": "…uuid…",
  "createdAt": "2026-07-16T06:30:02Z"
}
```

---

## 6. Package layout (package-by-feature)

```
com.heartcare.activity/
├── ActivityController.java       # POST /activities, GET /activities
├── ActivityService.java          # validation, idempotency, ownership scope, date-bounds conversion
├── ActivityRepository.java       # findByUserIdAndClientRecordId; findHistory(userId, fromTs, toTs)
├── model/
│   ├── ActivityLog.java          # @Entity; @JdbcTypeCode(SqlTypes.JSON) data (Map<String,Object>)
│   ├── ActivityType.java         # enum WALKING|JOGGING|CYCLING|HOUSEHOLD|FARMING|STRETCHING|OTHER
│   └── Intensity.java            # enum LIGHT|MODERATE|VIGOROUS
└── dto/
    ├── ActivityLogRequest.java   # data, measuredAt?, note?, clientRecordId?
    └── ActivityLogResponse.java  # id, data, measuredAt, note, clientRecordId, createdAt
```

Reuses shared infrastructure: `common.response.ApiResponse`, `common.security.UserPrincipal`, `common.exception.GlobalExceptionHandler` (401/404/400/malformed-body incl. `BadRequestException→400`). **No cross-feature dependency** (contrast vitals' profile-height read). **No assessment/rules class** (contrast `SymptomAssessment`) — Decision 2.

**Entity JSONB mapping** reuses the established `@JdbcTypeCode(SqlTypes.JSON)` approach with a `Map<String, Object> data`, mirroring `SymptomLog`. The service validates the structured shape explicitly (§4/§7) rather than relying on the map type. `type` and `intensity` are validated against their enums during that structural check (parsed to the enums for validation, stored as their string values in `data`).

---

## 7. Validation

Returns `400` via the existing `GlobalExceptionHandler` (reuses the Slice 3–5 `@Valid` + `BadRequestException` handling).

- **`data`** — required; **structural validation in the service**: exactly the required keys present (§4.1), each of the correct shape/type, each numeric field within its input-sanity range, optional keys validated when present.
- **`type`** — required; must be a known `ActivityType` (unknown → 400).
- **`durationMinutes`** — required int, 1–1440.
- **`intensity`** — required; must be a known `Intensity` (unknown → 400).
- **`steps`** — optional int, 0–100000 when present.
- **`distanceMeters`** — optional number, 0–100000 when present.
- **`measuredAt`** — optional; defaults to `OffsetDateTime.now(ZoneOffset.UTC)` when null.
- **`note`** — optional, `@Size(max = 500)`.
- **`clientRecordId`** — optional UUID.

---

## 8. Testing strategy (TDD)

- **`ActivityServiceTest`** (unit, mocked repository): server persists the validated record; idempotent create returns the existing row when `clientRecordId` repeats; `measuredAt` defaults when null; history delegates to the repository with the correct UTC `[fromTs, toTs)` bounds (mirrors `VitalsServiceTest`/`SymptomsServiceTest`); invalid `data` shapes throw `BadRequestException` (missing required key, unknown `type`/`intensity`, out-of-range `durationMinutes`/`steps`/`distanceMeters`).
- **`ActivityControllerIntegrationTest`** (`@SpringBootTest` + Testcontainers Postgres, MockMvc; reuses `AbstractIntegrationTest`; a test user registers through the real auth endpoint, black-box):
  - unauthenticated → 401;
  - POST a full activity log, then read it back via `GET /activities`; `data` JSONB (incl. optional `steps`/`distanceMeters`) persists/reloads on real Postgres;
  - POST a minimal log (only required `type`/`durationMinutes`/`intensity`, no optionals) round-trips;
  - `from`/`to` UTC-day filtering (including the midnight-boundary bucketing case, as in vitals/symptoms);
  - idempotent re-POST with the same `clientRecordId` returns one row;
  - 400 on missing required key, unknown `type` enum, unknown `intensity` enum, out-of-range `durationMinutes` (0 / 1441) and `steps`, and wrong field type.

---

## 9. Documentation updates (end of slice)

- `backend/README.md` — flip Slice 6 to ✅ in the build-progress table.
- `backend/docs/API.md` — add the two activity endpoints (auth, request/response envelope, `data` keys, `ActivityType`/`Intensity` enums). Note the client-side EN/AM label mapping for the enums.
- `backend/docs/DATABASE.md` — add the `activity_logs` table and the `V7` migration-log entry.

---

## 10. "Done" criteria

- `mvn spring-boot:run` boots; Flyway applies `V7` on top of `V6`.
- A logged-in patient can log a physical-activity session and read back the full history filtered by date range — end-to-end; unauthenticated → 401; invalid input → 400.
- Repeated `POST` with the same `client_record_id` yields exactly one row (idempotency verified on real Postgres).
- `mvn test` green (unit + integration; `data` JSONB round-trips on real Postgres).
- README progress + `API.md` + `DATABASE.md` reflect Slice 6.

---

## 11. Out of scope for Slice 6 (and where it lands)

- **Activity guidance content** (FR-ACT-001 / -002 / -004 / -005) — client-side static/offline reference content, bundled in the app like Education. Not a backend concern.
- **Steps-goal progress + today's summary + trend graphs** (FR-ACT-007 / FR-DASH-006 / FR-GRAPH-005) — dashboard/analytics slice; needs the profile goal and same-day/windowed aggregation. This slice only stores raw `steps`/`distanceMeters`.
- **Clinician cross-user read access (FR-COM)** — later clinician-scope slice (being narrowed out per [[scope-decisions]]).
- **Sync routing (Slice 7)** — this slice only provides the idempotency key and idempotent create.
