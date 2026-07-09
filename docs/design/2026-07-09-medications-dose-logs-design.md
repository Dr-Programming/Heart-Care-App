# Backend Design — Slice 3 (Medications & Dose Logs)

**Project:** Heart-Care App (UOW Capstone — Project 29)
**Date:** 2026-07-09
**Status:** Approved for implementation planning
**Scope of this spec:** Detailed design of **Slice 3 — Medications & Dose Logs** (medication CRUD, per-dose logging, dose history; migrations `V3__create_medications.sql`, `V4__create_dose_logs.sql`). Builds on the architecture and conventions established in `2026-06-30-backend-foundation-auth-design.md` and `2026-07-04-patient-profile-design.md`.

---

## 1. Context & Goal

Slices 1–2 delivered auth (register/login → JWT) and the patient profile. Slice 3 adds the first **one-to-many** feature and the first **time-series log** table: a patient's medications and the individual doses they log against them. This is also the first slice whose rows are generated on-device in bulk while offline, so it introduces the sync idempotency key that the Slice 7 sync engine will rely on.

Per the offline-first architecture, the device is the source of truth: it holds the schedule, fires local reminders, and records dose actions locally. The backend's job in this slice is to **persist and serve** medications and dose logs so a freshly-installed device can pull the full history back — not to compute "what is due right now."

### Requirements covered (`FUNCTIONAL_REQUIREMENTS.md §4`)

| FR | Description | Priority | This slice |
|---|---|---|---|
| FR-MED-001 | Add medication: name, dose (mg), frequency (Once daily / BID / TID / Custom) | P1 | ✅ |
| FR-MED-002 | One or more scheduled times per day per medication | P1 | ✅ |
| FR-MED-003 | Log each dose as **Taken** / **Missed** / **Skipped** | P1 | ✅ |
| FR-MED-004 | Display med list with current dose status for the day | P1 | ✅ (data served; status computed client-side — see §2.2) |
| FR-MED-005 | Edit or deactivate a medication | P1 | ✅ (soft deactivate) |
| FR-MED-006 | Complete dose-log history with timestamps | P1 | ✅ |
| FR-MED-008 | Optional note per dose log | P3 | ✅ (column + field included; cheap) |
| FR-MED-010 | Medication data & dose logs stored locally for offline logging | P1 | ✅ (server side of the sync contract; `client_record_id`) |

### Deferred (out of scope for this slice)

- **FR-MED-007 — adherence % over 7 / 30 days (P2).** Requires computing *expected* doses from each medication's schedule over a window and comparing against logged doses. This belongs with the analytics/dashboard work (feeds FR-DASH-007, FR-GRAPH-006), not the CRUD/logging slice. See §10.
- **FR-DEC-001/002/003, FR-NOT-001…004 — reminders & adherence alerts.** Reminders fire locally on the device (FR-OFF-010); the server-side alert engine (`alerts` table, WebSocket push) is a separate subsystem in a later slice.
- **FR-MED-009 / FR-NOT-010 — caregiver missed-dose notifications (P3, marked "voided" in the FR sheet).**
- **Offline sync routing** — handled by the Slice 7 sync engine. This slice only lays down the idempotency key (§2, decision 4).

---

## 2. Design Decisions

Each decision records the choice, the rationale, and the alternative that was rejected, so a future change starts with full context.

### Decision 1 — Dose logs are an append-only event log

**Choice:** A `dose_logs` row exists **only when the patient acts**. Each row records the medication, the slot it was for (`scheduled_date` + `scheduled_time`), the `status` (`TAKEN`/`MISSED`/`SKIPPED`), the actual `logged_at` timestamp, and an optional note. "Missed" is an **explicit** status the client writes (typically after its local reminder window lapses), not a server-derived state.

**Rationale:** Fits offline-first and device-as-source-of-truth. No server-side scheduler or nightly job is needed to pre-create rows. The device already owns the schedule and reminders, so it is the natural author of every log, including "missed."

**Rejected alternative — pre-materialized dose instances:** Generate one row per expected dose occurrence with `status = PENDING`, updated later to taken/missed/skipped. This needs a generation job, a notion of a server "clock," and conflicts with the device being the source of truth (the server would be inventing rows the device didn't create). Heavier for no offline benefit.

### Decision 2 — "Today's status" (FR-MED-004) is computed client-side

**Choice:** The backend serves raw `medications` (including their `schedule_times`) and `dose_logs`. The **device** derives the "what's due / taken / missed today" view locally.

**Rationale:** Keeps the server stateless about "now," so the same data drives the UI whether the device is online or offline. The server never has to reason about the device's local date/timezone.

**Rejected alternative — a server `GET /medications/today` endpoint:** Would require the server to know the device's local date and reminder windows, duplicating logic the device must have anyway for offline operation.

### Decision 3 — Schedule times as a JSONB array on `medications`

**Choice:** `schedule_times JSONB NOT NULL DEFAULT '[]'` holding `"HH:mm"` strings (e.g. `["08:00","20:00"]`), alongside a typed `frequency` enum column.

**Rationale:** Consistent with the Slice 2 precedent of JSONB for small unstructured lists (`comorbidities`). A medication has at most a handful of times; a child table and its join buy nothing here. `frequency` is kept as an explicit column because FR-MED-001 stores it directly and it is convenient for display/filtering; the two are intentionally *not* cross-validated for count (see §6).

**Rejected alternative — child `medication_schedule_times` table:** Normal-form overkill for ≤ ~4 short values; adds a join and a second write path for no query benefit at this scale.

### Decision 4 — `client_record_id` (unique per user) on both tables, now

**Choice:** Add a nullable `client_record_id UUID`, unique per `user_id`, to **both** `medications` and `dose_logs` in this slice. On `POST`, if a `client_record_id` already exists for that user, return the existing row instead of inserting a duplicate (idempotent create).

**Rationale:** These are the first records a device generates in bulk while offline. The `sync_queue` design (CLAUDE.md) already uses `client_record_id` as its idempotency key. Adding the column and the idempotent-create behavior now means a replayed offline `POST` (common on flaky connectivity) is a no-op rather than a duplicate. Retrofitting a uniqueness key onto a table that already has data is far more painful.

**Rejected alternative — add it in Slice 7:** Defers a cheap column to a point where the tables already hold un-keyed rows, forcing a backfill/dedup migration.

### Decision 5 — Soft deactivate, never hard delete

**Choice:** `DELETE /medications/{id}` sets `active = false`. Dose logs are retained. `GET /medications` returns only active medications unless `?includeInactive=true`.

**Rationale:** FR-MED-005 says "edit or deactivate," and FR-MED-006 requires a *complete* dose-log history. Hard-deleting a medication would orphan or cascade-delete its dose history, violating FR-MED-006.

**Rejected alternative — SQL DELETE:** Loses history; breaks FR-MED-006.

---

## 3. Migrations

Two migrations, one per table, matching the one-table-per-migration pattern of `V1`/`V2`.

### `V3__create_medications.sql`

```sql
CREATE TABLE medications (
    id                UUID PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name              VARCHAR(255) NOT NULL,
    dose_mg           NUMERIC(8,2) NOT NULL,
    frequency         VARCHAR(20) NOT NULL,
    schedule_times    JSONB NOT NULL DEFAULT '[]'::jsonb,
    active            BOOLEAN NOT NULL DEFAULT TRUE,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_medications_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_medications_user ON medications(user_id);
```

### `V4__create_dose_logs.sql`

```sql
CREATE TABLE dose_logs (
    id                UUID PRIMARY KEY,
    medication_id     UUID NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scheduled_date    DATE NOT NULL,
    scheduled_time    TIME,
    status            VARCHAR(10) NOT NULL,
    logged_at         TIMESTAMPTZ NOT NULL,
    note              TEXT,
    client_record_id  UUID,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_dose_logs_user_client_record UNIQUE (user_id, client_record_id)
);

CREATE INDEX idx_dose_logs_user_date ON dose_logs(user_id, scheduled_date);
CREATE INDEX idx_dose_logs_medication ON dose_logs(medication_id);
```

Notes:
- `id` is app-assigned (Hibernate UUID strategy), matching `users`/`patient_profiles`.
- `NUMERIC(8,2)` for `dose_mg` allows fractional doses (e.g. `2.50`); maps to Java `BigDecimal`.
- `scheduled_time` is nullable to allow ad-hoc / unscheduled dose logging.
- The `UNIQUE (user_id, client_record_id)` constraint treats a `NULL` `client_record_id` as non-conflicting (standard SQL NULL semantics), so server-originated rows without a client id are fine.
- `user_id` is denormalized onto `dose_logs` so patient-scoped history queries and ownership checks don't require a join through `medications`.

---

## 4. Endpoints (base `/api/v1`)

All require `Authorization: Bearer <JWT>` and return the `ApiResponse<T>` envelope. Every operation is scoped to the authenticated `userId`; a medication or dose not owned by the caller returns **404** (not 403 — we don't reveal existence).

| Method | Path | Request | Response (`data`) | FR |
|---|---|---|---|---|
| POST | `/medications` | medication body | created medication | FR-MED-001/002 |
| GET | `/medications?includeInactive=false` | — | list of medications | FR-MED-004 |
| PUT | `/medications/{id}` | medication body | updated medication | FR-MED-005 |
| DELETE | `/medications/{id}` | — | deactivated medication (the row with `active:false`) | FR-MED-005 |
| POST | `/medications/{id}/doses` | dose-log body | created dose log | FR-MED-003 |
| GET | `/dose-logs?from=&to=&medicationId=` | — | list of dose logs | FR-MED-006 |

- `POST` create is **idempotent on `client_record_id`**: if the caller supplies a `client_record_id` that already exists for them, the existing row is returned (200) instead of a duplicate insert.
- `PUT /medications/{id}` has full-replace semantics over the editable fields (`name`, `dose_mg`, `frequency`, `schedule_times`, `active`).
- `DELETE` performs the soft-deactivate from Decision 5.
- `GET /dose-logs` filters are all optional: `from`/`to` bound `scheduled_date` (inclusive), `medicationId` narrows to one medication. Default (no params) returns the caller's full history, newest first.

### Request / response shapes

**Medication**
```json
{
  "id": "…uuid…",
  "name": "Aspirin",
  "doseMg": 100,
  "frequency": "BID",
  "scheduleTimes": ["08:00", "20:00"],
  "active": true,
  "clientRecordId": "…uuid… (optional, echoed back)",
  "createdAt": "…", "updatedAt": "…"
}
```
The `POST`/`PUT` body is the same object minus server-owned fields (`id`, `active` on create defaults true, timestamps). `clientRecordId` is optional on input and echoed on output.

**Dose log**
```json
{
  "id": "…uuid…",
  "medicationId": "…uuid…",
  "scheduledDate": "2026-07-10",
  "scheduledTime": "08:00",
  "status": "TAKEN",
  "loggedAt": "2026-07-10T08:05:00Z",
  "note": "took with food",
  "clientRecordId": "…uuid… (optional)",
  "createdAt": "…"
}
```
`medicationId` on a dose-log `POST` comes from the path (`/medications/{id}/doses`), not the body. `scheduledTime` and `note` are optional.

---

## 5. Package layout (package-by-feature)

```
com.heartcare.medication
├── MedicationController.java     POST/GET/PUT/DELETE /medications
├── DoseLogController.java        POST /medications/{id}/doses, GET /dose-logs
├── MedicationService.java        CRUD + soft-deactivate + idempotent create
├── DoseLogService.java           log dose (idempotent) + history query
├── MedicationRepository.java     extends JpaRepository<Medication, UUID>
├── DoseLogRepository.java        extends JpaRepository<DoseLog, UUID>
├── model/
│   ├── Medication.java           @Entity; schedule_times via @JdbcTypeCode(SqlTypes.JSON)
│   ├── DoseLog.java              @Entity
│   ├── Frequency.java            enum ONCE_DAILY, BID, TID, CUSTOM
│   └── DoseStatus.java           enum TAKEN, MISSED, SKIPPED
└── dto/
    ├── MedicationRequest.java    inbound (Bean Validation)
    ├── MedicationResponse.java   outbound
    ├── DoseLogRequest.java       inbound (Bean Validation)
    └── DoseLogResponse.java      outbound
```

Follows Slice 1/2 conventions: Java `record` DTOs, constructor-injected `@Service`, controller resolves `userId` from `@AuthenticationPrincipal UserPrincipal`, DTOs stay inside the feature package, no import of `auth`. `frequency`/`status` are stored as `VARCHAR` and mapped with JPA `@Enumerated(EnumType.STRING)`.

---

## 6. Validation

Bean Validation (Jakarta) on the request records; violations → `400` via the existing `GlobalExceptionHandler`.

**MedicationRequest**
- `name` — `@NotBlank`, `@Size(max = 255)`.
- `doseMg` — `@NotNull`, `@Positive` (`BigDecimal`).
- `frequency` — `@NotNull`; enum-bound (deserialization of an unknown value → 400).
- `scheduleTimes` — each element matches `^([01]\d|2[0-3]):[0-5]\d$` (validated element-wise); the list may be empty but not contain nulls.
- `clientRecordId` — optional UUID.

**DoseLogRequest**
- `status` — `@NotNull`; enum-bound.
- `scheduledDate` — `@NotNull`.
- `scheduledTime` — optional.
- `note` — optional (`@Size` cap, e.g. 500).
- `clientRecordId` — optional UUID.

**Deliberately not enforced:** the count of `scheduleTimes` is *not* cross-validated against `frequency` (e.g. BID = 2). `CUSTOM` allows any count, and rigid coupling would be brittle; the client owns that UX. Documented here so it's a known, intentional gap.

---

## 7. Testing strategy (TDD)

- **`MedicationServiceTest`** (unit, mocked repositories):
  - create returns the saved medication; idempotent create returns the existing row when `clientRecordId` repeats;
  - update replaces editable fields; deactivate flips `active` and preserves the row;
  - operating on another user's medication is rejected (not found).
- **`DoseLogServiceTest`** (unit, mocked repositories):
  - logging a dose against an owned medication succeeds; against a non-owned/absent medication → not found;
  - idempotent log on repeated `clientRecordId`;
  - history query applies `from`/`to`/`medicationId` filters.
- **`MedicationControllerIntegrationTest`** (`@SpringBootTest` + Testcontainers Postgres, MockMvc):
  - unauthenticated → 401;
  - full CRUD round-trip incl. `schedule_times` JSONB persisting/reloading on real Postgres;
  - `includeInactive` behavior; soft-deactivate leaves the row queryable;
  - 404 on another user's medication; 400 on invalid body.
- **`DoseLogControllerIntegrationTest`**:
  - log a dose then read it back via `/dose-logs`;
  - date-range and `medicationId` filtering;
  - idempotent re-POST with same `clientRecordId` returns one row;
  - 400 on invalid status/missing date; 404 logging against a non-owned medication.

Reuses the Slice 1 `AbstractIntegrationTest` Testcontainers base. Registration for a test user goes through the real auth endpoint (black-box; no auth classes imported), as in Slice 2.

---

## 8. Documentation updates (end of slice)

- `backend/README.md` — flip Slice 3 to ✅ in the build-progress table.
- `backend/docs/API.md` — add the six medication/dose-log endpoints (auth, request/response envelope).
- `backend/docs/DATABASE.md` — add the `medications` and `dose_logs` tables and the `V3`/`V4` migration-log entries.

---

## 9. "Done" criteria

- `mvn spring-boot:run` boots; Flyway applies `V3` and `V4` on top of `V2`.
- A logged-in patient can add a medication, edit it, deactivate it, log Taken/Missed/Skipped doses, and read back the full dose history — end-to-end; unauthenticated access returns 401; another user's records return 404; invalid input returns 400.
- Repeated `POST` with the same `client_record_id` yields exactly one row (idempotency verified on real Postgres).
- `mvn test` green (unit + integration, JSONB and enums validated on real Postgres).
- README progress + `API.md` + `DATABASE.md` reflect Slice 3.

---

## 10. Out of scope for Slice 3 (and where it lands)

- **Adherence % (FR-MED-007, P2)** — computed expected-vs-actual over 7/30 days; lands with the analytics/dashboard slice (feeds FR-DASH-007, FR-GRAPH-006). The `dose_logs` schema here is sufficient input.
- **Reminders & alerts (FR-DEC-001/002/003, FR-NOT-001…004)** — device-local notifications plus the server alert engine (`alerts` table + WebSocket); later slice.
- **Caregiver notifications (FR-MED-009 / FR-NOT-010, P3, voided).**
- **Sync routing (FR-OFF/Slice 7)** — this slice only provides the idempotency key and idempotent create; the sync-queue processor is Slice 7.
