# Backend Design — Slice 7 (Offline Sync Engine)

**Project:** Heart-Care App (UOW Capstone — Project 29)
**Date:** 2026-07-17
**Status:** Approved for implementation planning
**Scope of this spec:** Detailed design of **Slice 7 — Offline Sync Engine** (`POST /api/v1/sync`: batched, idempotent submission of records created on-device while offline). This is the **last backend slice** and the keystone every prior slice's `client_record_id` was laid down for. Builds on Slices 1–6; no new tables.

---

## 0. Requirements-approval caveat

`FUNCTIONAL_REQUIREMENTS.md §14 (Offline Capability)` is **not** marked "further discussion / approval waiting" — unlike §5–§9 — so this slice proceeds against the documented FRs as a settled spec. Two places where this design **knowingly departs** from the written docs are called out as **⚠️ DEVIATION** (Decisions 1 and 3) and need the project owner's sign-off on review. This slice computes no clinical value, so the clinical-thresholds sign-off gate does not apply.

---

## 1. Context & Goal

Slices 1–6 delivered auth, patient profile, medications + dose logs, vitals, symptoms, and activity. Every user-generated record already carries a device-generated `client_record_id` UUID, and every create path is already idempotent on it. **This slice spends that investment.**

The goal is narrow and precise: let a phone that has been offline for days hand the server a **single batched payload** of everything it recorded, and get back a **per-record verdict** it can act on — without duplicating data, without losing data, and without one bad record wedging the queue forever.

The offline-first constraint is the reason this app exists in its current shape. A patient in rural Ethiopia may install the app, add their medications, and log doses, vitals, and symptoms for a week before seeing connectivity. Every design decision below is subordinate to one rule: **never lose a patient's health data, and never silently duplicate it.**

### Requirements covered (`FUNCTIONAL_REQUIREMENTS.md §14`)

| FR | Description | Priority | This slice |
|---|---|---|---|
| FR-OFF-001 | Log vitals, symptoms, medications, activity with no internet | P1 | ✅ server side of the contract — all five create-shaped types accepted (§4) |
| FR-OFF-005 | Submit pending records in a **single batched API call** | P1 | ✅ (`POST /api/v1/sync`, up to 200 records) |
| FR-OFF-006 | Client-generated `client_record_id` prevents duplicate entries | P1 | ✅ enforced server-side; hardened against a concurrency race (§8) |
| FR-OFF-007 | Conflicts resolved **last-recorded-timestamp-wins per record** | P1 | ⚠️ **DEVIATION** — conflicts are *detected and reported*, not resolved by overwrite. See Decision 3. |
| FR-OFF-008 | Notify user if sync fails; **retain records for retry** | P1 | ✅ per-record `REJECTED` reasons + whole-batch 500 on transient failure (§7) |
| NFR-008 | Sync minimises data transfer volume | P1 | ✅ one call per ≤200 records; no envelope redundancy (Decision 9) |

### Client-side FRs — explicitly not this slice

FR-OFF-002 (local SQLite), FR-OFF-003 (`sync_queue` + `PENDING` marking), FR-OFF-004 (connectivity-triggered background sync), FR-OFF-009/-010/-011 (bundled content, local notifications, offline rendering) are **Flutter-side**. They are listed here only to bound the slice: the backend's entire contribution to offline capability is the one endpoint specified below.

### Deferred / out of scope (and where it lands)

- **Offline medication *edits*** (update / deactivate) — see Decision 7. Editing a medication requires connectivity.
- **Pull / server→device sync** — see Decision 2. Covered by existing `GET` endpoints.
- **Alert engine** (`alerts` table, FR-DEC/FR-NOT) — never slice-mapped; consumes the `flagged`/`overall_severity` values vitals and symptoms already produce.
- **Clinician cross-user access (FR-COM)** — being narrowed out; every endpoint here is patient-self-scoped via `@AuthenticationPrincipal`.

---

## 2. Design Decisions

Each decision records the choice, the rationale, and the rejected alternative.

### Decision 1 — No server-side `sync_queue` table

**Choice:** Slice 7 ships **no migration**. The sync queue lives exclusively in Drift/SQLite on the device.

**Rationale:** The queue's job is tracking what *this device* still owes the server (`sync_status: PENDING | SYNCING | SYNCED`). That is device-local state by definition — a second device would have a different queue for the same patient. Once a record is committed to `vitals_logs`, a server-side row restating it is a duplicate whose only readers would be audit tooling nobody has asked for. Every log table already carries `client_record_id` with a `UNIQUE (user_id, client_record_id)` constraint, which is the entire deduplication mechanism. A server queue would add an unbounded-growth table and a second source of truth for zero functional gain.

**⚠️ DEVIATION:** `CLAUDE.md` lists `sync_queue` among the PostgreSQL tables. `ARCHITECTURE.md §7.1` lists it under **"Local Database Schema (Drift / SQLite)"**, alongside `patients_local`. These contradict; this design follows `ARCHITECTURE.md`, which matches the table's actual purpose. **`CLAUDE.md` must be corrected** (§10).

**Rejected alternative — server-side receipt log:** An append-only table of every submitted envelope, for field debugging. Real but speculative value, unbounded growth, and duplicates data already in the log tables. If sync bugs appear in the field, structured logging answers the same questions without a schema change.

**Rejected alternative — queue-as-write-path:** Records land in `sync_queue` as `PENDING`, and a processor later writes them into the log tables. Decouples ingest from processing, but buys eventual consistency and async machinery at a scale (one patient, ≤200 records) that does not need it.

### Decision 2 — Push-only

**Choice:** `/sync` accepts device→server records only. There is no pull direction.

**Rationale:** FR-OFF-003/-004/-005 describe only *submitting pending records*. Pull is already served by the existing history endpoints (`GET /vitals`, `/symptoms`, `/activities`, `/dose-logs`, `/medications`, `/patients/me`) — a fresh install restores by calling those. Adding a `changed-since` cursor to `/sync` would only matter if something other than this phone could write the patient's data; the clinician role is being dropped and the MVP is patient-only, so **the phone is the sole writer**. Cursor semantics plus clock-skew handling for a case that may never exist is speculative complexity.

**Rejected alternative — push + pull cursor:** Revisit if and only if multi-device support enters scope. The response envelope is an object (not a bare array), so a `serverChanges` field could be added later without breaking clients.

### Decision 3 — First-write-wins, with conflict detection and reporting

**Choice:** When a `client_record_id` already exists for that user, the **stored record always wins**. The incoming payload is never written. If the incoming payload *differs* from what is stored, the record's outcome is `CONFLICT` (rather than `DUPLICATE`), carrying the stored `serverId`, so the client can surface or log it.

**Rationale:** All six log tables are append-only and immutable — a design invariant Slices 3–6 were built on, and the right one for clinical history. Consider when a divergent payload could actually occur: it requires the user to edit a record that has *already synced*, then re-send it under the same id. The app does not offer editing of logged vitals/symptoms/activity/doses, and the phone is the only writer. **A genuine conflict is therefore close to structurally impossible; if one arrives, it signals a client bug reusing a UUID.** Silently returning the stored record would hide that bug forever. Reporting `CONFLICT` turns it into a visible, debuggable signal at the cost of one payload comparison, and keeps FR-OFF-007 traceable as *detected and reported*.

**⚠️ DEVIATION:** FR-OFF-007 specifies "last-recorded-timestamp-wins", and `ARCHITECTURE.md §7.3` elaborates: "treated as a server-side update if `recorded_at` is newer." This design does **not** overwrite. Both documents describe a mutable-record world that this schema deliberately is not. **Requires project-owner sign-off**; if overwrite is genuinely wanted, it needs an audit trail before it is defensible for health data (§11).

**Rejected alternative — true last-timestamp-wins:** Overwrite the row when incoming `recordedAt` is newer. Literal FR compliance, but it breaks the append-only invariant across four features and mutates clinical history with no audit trail. Rejected as clinically indefensible for the value it adds.

**Rejected alternative — silent first-write-wins:** Exactly today's behaviour; zero new code. Rejected because it discards the only signal that would reveal a client-side UUID bug.

### Decision 4 — Per-record outcomes, partial success

**Choice:** Each record is processed and committed independently. The response is `200` with a per-record result array keyed by `clientRecordId`. Valid records commit even when neighbours fail.

**Rationale:** The alternative is a poison pill. Under all-or-nothing, one malformed record — from a client bug, a truncated write, anything — permanently blocks *every* subsequent record for that patient. Their data silently stops syncing, forever, with no path to progress. On flaky rural connectivity with health data at stake, that failure mode is unacceptable. Per-record isolation also directly serves FR-OFF-008: the client marks the successes `SYNCED` and retains only the failures.

**Rejected alternative — all-or-nothing single transaction:** Simple and atomic, but see above.

**Rejected alternative — HTTP 207 Multi-Status:** More literal REST for mixed outcomes, but it breaks the `ApiResponse<T>` envelope every other endpoint returns and would need Dio special-casing on the client. Consistency wins; the per-record statuses already carry the information.

### Decision 5 — Dispatch via a handler registry, not direct service calls

**Choice:** A `SyncHandler` interface in `common/sync/` declares `entityType()` and `handle(userId, payload)`. Each feature ships its own implementation in its **own package** (e.g. `VitalsSyncHandler` in `com.heartcare.vitals`). `SyncService` injects `List<SyncHandler>` and indexes it by entity type at construction, failing fast on duplicates.

**Rationale:** Architectural rule #1 — *"Features never import from each other directly — only through `core/` interfaces or shared services."* A `SyncService` injecting `VitalsService`, `SymptomsService`, `ActivityService`, `DoseLogService` and `MedicationService` would violate it five ways and make `sync` depend on every feature in the app. With the registry, dependencies point strictly inward: features depend on `common`, `sync` depends on `common`, nothing depends on a feature. Adding a sixth entity type means adding one class inside that feature, with **no edit to `SyncService`**. `SyncService` is unit-testable against a fake handler with no feature code loaded.

**Cost accepted:** five thin adapter classes (~15 lines each). That is the price of the dependency rule.

**Rejected alternative — direct injection + `switch` on entityType:** Fewer files, obvious end-to-end flow, but violates rule #1 and centralises a switch that must be edited for every new type.

**Rejected alternative — Spring application events:** Fully decoupled, but async-by-default makes per-record outcomes awkward — the result is needed synchronously to build the response, so it fights the model for no gain.

### Decision 6 — One shared `IdempotentWriter`; fix the race on all five create paths

**Choice:** A single `IdempotentWriter` bean in `common/persistence/` performs the insert under `@Transactional(propagation = REQUIRES_NEW)`. Each feature's create method drops its own `@Transactional`, and follows find → try-insert → catch `DataIntegrityViolationException` → re-read (§8).

**Rationale:** `findByUserIdAndClientRecordId()` → `save()` is **not atomic**. Two concurrent requests with the same `client_record_id` both find nothing, both insert, and the loser hits the `UNIQUE` constraint → **500 where an idempotent 200 was the entire point**. `/sync` makes this far more likely: retry-on-flaky-connectivity means the client re-sends while the first request is still in flight — precisely the concurrent case. Fixing it in `common/` rather than per-feature removes four near-identical copies and, critically, **fixes the direct `POST /vitals` path too**, not just the sync path.

**Rejected alternative — duplicate the fix in each service:** Keeps features self-contained per package-by-feature, at the cost of five copies of subtle transaction-boundary logic that will drift.

**Rejected alternative — fix only in `SyncService`:** Smallest diff, but leaves a live 500 reachable from the endpoints the mobile app also calls directly.

### Decision 7 — Five create-shaped entity types; medication edits excluded

**Choice:** `/sync` accepts `VITAL`, `SYMPTOM`, `ACTIVITY`, `DOSE_LOG`, `MEDICATION` — every entity whose create path is already idempotent on `client_record_id`. Medication `update`/`deactivate` are **not** syncable.

**Rationale:** These five cover FR-OFF-001 ("vitals, symptoms, medications, and activity") in full. Medication edits are excluded for two compounding reasons: they key off a **server-generated `id`** the device may not have yet, and they **mutate**, which reopens exactly the last-write-wins problem Decision 3 closes. Supporting them properly needs an `op` field, entity resolution, intra-batch mutation ordering, and an edit-conflict policy — a slice of its own.

**Documented limitation:** editing a medication requires connectivity. Adding one does not.

**Rejected alternative — four append-only log types only:** Perfectly uniform, but drops "medications" from a P1 requirement — adding a med offline would fail.

**Rejected alternative — five types + `op: CREATE|UPDATE|DEACTIVATE`:** Full offline parity, substantially the largest option, and pulls mutation-conflict semantics back in.

### Decision 8 — Dose logs may reference a medication by `medicationClientRecordId`

**Choice:** A `DOSE_LOG` payload may carry **either** `medicationId` (server UUID) **or** `medicationClientRecordId`. `SyncService` processes `MEDICATION` envelopes **before** `DOSE_LOG` envelopes within a batch; the handler resolves the client id to the server id.

**Rationale:** This is the actual field scenario, not a hypothetical: a patient installs the app, adds their medications, and logs doses for days before connectivity. Every one of those dose logs points at a medication with **no server id yet**. Without this, the batch saves the medications and rejects every dose — silently gutting adherence tracking, which is much of the app's purpose. Intra-batch ordering makes it work in a **single round trip**, which matters on a connection that may not survive a second one.

**Rejected alternative — reject until the medication has synced:** Batch 1 saves the med and returns its `serverId`; the client patches its local row and re-queues the doses; batch 2 saves them. No new payload field, but needs two successful round trips and forces a retryable-vs-permanent distinction into `REJECTED` that nothing else needs.

### Decision 9 — No `recordedAt` on the envelope

**Choice:** The sync envelope carries `clientRecordId`, `entityType`, and `payload`. No `recordedAt`.

**Rationale:** `ARCHITECTURE.md §7.2` lists `recorded_at` and `created_locally_at`, but that section describes the **device** queue table — the device needs them for local ordering and retry bookkeeping. On the wire they have no consumer: Decision 3 removed the only reader of `recordedAt` (timestamp comparison for overwrite), and every payload already carries its own real timestamp (`measuredAt` / `takenAt`), which the feature services already validate. A second timestamp on the envelope would be redundant, and redundancy at 200 records/batch works against NFR-008. Server-side ordering is irrelevant: log rows are independent, and the one real dependency (dose → medication) is handled by Decision 8.

### Decision 10 — Batch cap of 200, configured not hardcoded

**Choice:** `app.sync.max-batch-size: 200` in `application.yml`, injected with `@Value("${app.sync.max-batch-size}")` to match the existing `JwtTokenProvider` convention. Over-cap batches are rejected `400`; the client chunks.

**Rationale:** Bounds request size and server memory against a device that has been offline for weeks (or a malicious client). 200 records comfortably covers realistic offline stretches — a patient logging vitals, symptoms, activity and doses daily accrues well under 200/week. Per architectural rule #4, config lives in `application.yml`, never hardcoded.

---

## 3. Schema

**No migration.** The schema was completed in Slice 6 (`V1`–`V7`). This slice adds no tables, columns, or indexes.

It **depends on** the `UNIQUE (user_id, client_record_id)` constraint present on `medications`, `dose_logs`, `vitals_logs`, `symptom_logs`, and `activity_logs` — that constraint is the deduplication mechanism and the thing §8's race handling catches on. Implementation must verify it exists on all five tables before relying on it.

---

## 4. The wire contract

### Request

```
POST /api/v1/sync
Authorization: Bearer <jwt>
Content-Type: application/json
```

```json
{
  "records": [
    { "clientRecordId": "9f1c…", "entityType": "MEDICATION", "payload": { "name": "Atorvastatin", "doseMg": 20, "frequency": "DAILY", "scheduleTimes": ["08:00"] } },
    { "clientRecordId": "2b7e…", "entityType": "DOSE_LOG",   "payload": { "medicationClientRecordId": "9f1c…", "status": "TAKEN", "takenAt": "2026-07-16T08:05:00+03:00" } },
    { "clientRecordId": "44d0…", "entityType": "VITAL",      "payload": { "type": "BLOOD_PRESSURE", "values": { "systolic": 128, "diastolic": 82 }, "measuredAt": "2026-07-16T08:10:00+03:00" } }
  ]
}
```

`payload` is **verbatim the feature's existing request DTO shape**. `VITAL` payloads are `VitalLogRequest`, `ACTIVITY` payloads are `ActivityLogRequest`, and so on. This is deliberate: validation rules, JSONB contracts, and range checks stay defined in exactly one place per feature, and `/sync` reuses them rather than restating them. The sole addition anywhere is `DOSE_LOG.medicationClientRecordId` (Decision 8).

**Bean Validation must be invoked explicitly — it does not come for free.** The request DTOs carry Jakarta constraints (`MedicationRequest.name` is `@NotBlank`, `doseMg` is `@Positive`; `DoseLogRequest.status` is `@NotNull`). On the direct `POST` endpoints those fire because the controller parameter is annotated `@Valid`. A handler that deserializes a `JsonNode` into the same record **bypasses them completely**, so a medication with a blank name would reach the database. `SyncPayloadMapper` (§6) therefore deserializes *and* runs `jakarta.validation.Validator` over the result, mapping violations to `BadRequestException` → `REJECTED`, with the same `field: message; field: message` formatting `GlobalExceptionHandler` produces for `MethodArgumentNotValidException`. Unknown enum values and malformed JSON surface from the same seam: Jackson throws `InvalidFormatException`, which the mapper converts to `BadRequestException`.

**The envelope's `clientRecordId` is authoritative.** The feature request DTOs each carry their own optional `clientRecordId` field; inside a sync payload it is **ignored and overwritten** by the envelope's value. It is not validated for agreement and a mismatch is not an error — one key, one source of truth, no third failure mode to specify.

### Response

`200 OK`, wrapped in the standard `ApiResponse<T>` envelope:

```json
{
  "success": true,
  "message": "Sync processed",
  "data": {
    "results": [
      { "clientRecordId": "9f1c…", "status": "SAVED",     "serverId": "a3…" },
      { "clientRecordId": "2b7e…", "status": "DUPLICATE", "serverId": "b7…" },
      { "clientRecordId": "44d0…", "status": "CONFLICT",  "serverId": "c1…" },
      { "clientRecordId": "81aa…", "status": "REJECTED",  "reason": "durationMinutes is out of range" }
    ]
  }
}
```

`results` preserves request order. No summary counts — the client derives them trivially, and they would be a second source of truth for the same facts.

### Statuses

| Status | Meaning | `serverId` | Client action |
|---|---|---|---|
| `SAVED` | New record committed | ✅ | Mark `SYNCED`, store `serverId` |
| `DUPLICATE` | `client_record_id` already stored, payload matches | ✅ | Mark `SYNCED`, store `serverId` |
| `CONFLICT` | `client_record_id` already stored, payload **differs** | ✅ | Mark `SYNCED`; surface/log — indicates a client bug (Decision 3) |
| `REJECTED` | Payload invalid or unknown `entityType`; **will never succeed** | ✗ | Do **not** retry; flag for the user (FR-OFF-008) |

`SAVED`, `DUPLICATE`, and `CONFLICT` all mean *the server holds this record* — the client marks all three `SYNCED` and records `serverId`. That `serverId` is what lets a later batch reference a medication by server id.

---

## 5. Endpoint

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `POST` | `/api/v1/sync` | Bearer JWT | Submit a batch of offline-created records |

Patient-self-scoped: `userId` comes from `@AuthenticationPrincipal UserPrincipal`, never from the payload. A record cannot be written on another user's behalf, and a `client_record_id` collision across users is impossible by construction — the `UNIQUE` constraint is on `(user_id, client_record_id)`.

---

## 6. Package layout (package-by-feature)

```
com.heartcare.common.sync/
  SyncHandler.java              interface — entityType(), handle(userId, clientRecordId, payload)
  SyncStatus.java               enum SAVED | DUPLICATE | CONFLICT | REJECTED
  SyncOutcome.java              handler verdict: status + serverId
  SyncPayloadMapper.java        JsonNode -> DTO + Bean Validation (§4)
com.heartcare.common.persistence/
  IdempotentWriter.java         @Transactional(REQUIRES_NEW) insert (§8)

com.heartcare.sync/
  SyncController.java           POST /api/v1/sync
  SyncService.java              ordering, dispatch, per-record isolation
  dto/SyncRequest.java          { List<SyncRecord> records }
  dto/SyncRecord.java           { clientRecordId, entityType, payload }
  dto/SyncResponse.java         { List<SyncResult> results }
  dto/SyncResult.java           { clientRecordId, status, serverId, reason }

com.heartcare.vitals/VitalsSyncHandler.java
com.heartcare.symptoms/SymptomsSyncHandler.java
com.heartcare.activity/ActivitySyncHandler.java
com.heartcare.medication/MedicationSyncHandler.java
com.heartcare.medication/DoseLogSyncHandler.java
```

**Naming note:** `CLAUDE.md` specifies `core/sync/` for the sync processor, but **no `core/` package exists** — shared code has always lived in `common/` (`common/config`, `common/security`, `common/exception`, `common/response`). This design follows the code. `CLAUDE.md` must be corrected (§10).

**No feature service changes its public API.** Handlers adapt to the existing methods, so every existing controller and test keeps working unchanged. The only edits inside feature packages are the `@Transactional` relocation required by §8.

---

## 7. Validation & error handling

Errors are split by **whether a retry could ever succeed** — the distinction the client's queue depends on.

### Envelope-level → `400`, whole batch

Client bugs, independent of record content:

- `records` null or empty
- `records.size()` > `heartcare.sync.max-batch-size`
- any record missing `clientRecordId` — **unrecoverable by design**: without it there is no key to correlate a result back to, so it cannot be reported per-record
- any record missing `entityType` or `payload`

Enforced by Bean Validation on `SyncRequest`/`SyncRecord`, surfaced by the existing `GlobalExceptionHandler`.

### Record-level → `REJECTED`, batch continues

Content problems, including **unknown `entityType`** (`reason: "unknown entityType: FOO"`). An unknown type is record data, not envelope structure, so it must not wedge the batch. Feature `BadRequestException` and `ResourceNotFoundException` (e.g. dose log naming a medication that does not exist) map to `REJECTED` with the exception message as `reason`.

This tier also covers everything `SyncPayloadMapper` raises (§4): Bean Validation violations, malformed payload JSON, and unknown enum values. All three are per-record data problems that must not fail the batch.

### Transient failure → `500`, whole batch

Anything that is **not** `BadRequestException`/`ResourceNotFoundException` — database unavailable, an unexpected `NullPointerException` — propagates to `GlobalExceptionHandler` and fails the whole batch.

This is deliberate and is the most important error decision in the slice. If the database is down and every record came back `REJECTED`, a client correctly treating `REJECTED` as permanent would **delete a patient's unsynced health data** over a transient outage. A `500` instead tells the client: keep everything queued, retry later — exactly FR-OFF-008.

**Whole-batch retry is safe because of idempotency.** Records committed before the failure return `DUPLICATE` on the retry. Per-record commits plus `client_record_id` make the batch re-runnable, so no `FAILED` status and no partial-progress bookkeeping are needed.

### Transaction boundaries

`SyncService` is **not** `@Transactional`. Each handler call crosses a bean boundary into a feature service, so each record gets its own transaction; a rollback of record 7 leaves records 1–6 committed.

---

## 8. Concurrency: the check-then-insert race

**The bug (present in all five create paths today):** `findByUserIdAndClientRecordId()` → `save()` is not atomic. Two concurrent requests carrying the same `client_record_id` both find nothing, both insert, and the loser violates `UNIQUE (user_id, client_record_id)` → `DataIntegrityViolationException` → **500**, where an idempotent `200` was the whole point. The client, having been told the sync failed, retries — and the data is already there.

**Why `/sync` makes it matter:** retry-on-flaky-connectivity means the client re-sends while the first request is still in flight. That is the concurrent case, and it is the normal case on the connectivity this app targets.

**The JPA trap:** the fix is *not* simply wrapping the save in a try/catch. Once a constraint violation occurs, Hibernate **poisons the persistence context and marks the transaction rollback-only**. Catching the exception and re-reading *inside the same transaction* fails too. **The catch must sit outside the failed transaction.**

**The fix:** the insert moves into a shared bean under `REQUIRES_NEW`, so its failure rolls back only the inner transaction, leaving the caller free to re-read:

```java
// common/persistence/IdempotentWriter.java
@Component
public class IdempotentWriter {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public <T> T insert(JpaRepository<T, ?> repo, T entity) {
        return repo.saveAndFlush(entity);   // saveAndFlush: surface the violation here, not at commit
    }
}
```

```java
// each feature service — note: no @Transactional on this method
public VitalLogResponse log(UUID userId, VitalLogRequest req) {
    var existing = repo.findByUserIdAndClientRecordId(userId, req.clientRecordId());
    if (existing.isPresent()) return toResponse(existing.get());
    try {
        return toResponse(writer.insert(repo, build(userId, req)));
    } catch (DataIntegrityViolationException e) {
        // Lost the race: the winner's row is committed and visible now.
        return toResponse(repo.findByUserIdAndClientRecordId(userId, req.clientRecordId())
                              .orElseThrow(() -> e));   // not our constraint — rethrow
    }
}
```

`saveAndFlush` (not `save`) forces the INSERT to execute inside `insert()`, so the violation surfaces where it can be caught rather than at transaction commit. The `orElseThrow(() -> e)` matters: if the re-read finds nothing, the violation came from some *other* constraint and must not be swallowed as an idempotent hit.

`clientRecordId` is nullable on the direct `POST` endpoints (it is optional there) — the existing null guard is retained; a null id skips straight to insert.

### Accepted race on the outcome label

In a handler, between its `find` and `service.log()`, a concurrent insert can land; `log()` then returns the stored row and the outcome is reported `SAVED` where `DUPLICATE` was truer. **The persisted data is correct either way, and the client's action is identical for both** (mark `SYNCED`, store `serverId`). Accepted and documented rather than paying for a lock.

---

## 9. Testing strategy (TDD)

Written test-first, per the convention across Slices 3–6. Integration tests extend `AbstractIntegrationTest` (Testcontainers, `postgres:16-alpine`) so constraints are real.

### The race test — write this first, watch it fail

Two threads, same `client_record_id`, released together by a `CountDownLatch`, against real Postgres. **This test must fail against current `main` before the fix**, proving the bug is real and not theoretical: today the loser gets a 500. After the fix: both callers get the same record, same `serverId`, exactly one row exists, neither throws. Run against all five create paths.

### `SyncServiceTest` — unit, fake handlers, no Spring context

- dispatches each `entityType` to the right handler
- unknown `entityType` → `REJECTED`, batch continues
- `BadRequestException` → `REJECTED` with the message as `reason`
- `ResourceNotFoundException` → `REJECTED`
- unexpected `RuntimeException` → **propagates** (does not become `REJECTED`)
- `MEDICATION` records processed before `DOSE_LOG` records regardless of request order
- `results` preserve request order even though processing order differs
- duplicate `entityType` registration → fails fast at construction

### Handler tests (×5)

`SAVED` on new, `DUPLICATE` on identical re-send, `CONFLICT` on divergent payload. Each explicitly covers the **`+03:00` vs `Z` instant-equality** case: `2026-07-17T08:30+03:00` and `2026-07-17T05:30Z` are the same instant and must compare **equal**. `OffsetDateTime.equals()` is offset-sensitive and would report `CONFLICT` on every record an Ethiopian phone sends — `matches()` compares `toInstant()`.

`DoseLogSyncHandlerTest` additionally covers resolution by `medicationClientRecordId`, by `medicationId`, and rejection when neither resolves.

### `SyncControllerIntegrationTest` — end-to-end

- unauthenticated → `401`
- mixed batch returning all four statuses in one call
- batch over cap → `400`; record missing `clientRecordId` → `400`
- `MEDICATION` + `DOSE_LOG`-by-`medicationClientRecordId` in one batch → both `SAVED`, dose correctly linked
- whole batch re-sent → every record `DUPLICATE`, no duplicate rows (the transient-retry path)
- a record for another user's `client_record_id` → unaffected (cross-user isolation)

---

## 10. Documentation updates (end of slice)

- `backend/docs/API.md` — the `/sync` contract, statuses, error levels
- `backend/docs/DATABASE.md` — note that no migration was added; `sync_queue` is device-side
- `backend/README.md` — Build Progress table: Slice 7 complete
- **`CLAUDE.md` — two corrections this slice proves wrong:**
  - remove `sync_queue` from the PostgreSQL table list (device-side per Decision 1)
  - `core/sync/` → `common/sync/`; no `core/` package exists
- **`CLAUDE.md` — pre-existing staleness worth fixing while here:** it claims the repo "is in planning/architecture phase" with "no source code yet" (six slices are merged); says migrations `V1__`–`V10__` (there are `V1`–`V7`); lists a `patients` table (it is `patient_profiles`); omits `activity_logs`; lists `alerts` (never built)
- `FUNCTIONAL_REQUIREMENTS.md` — annotate FR-OFF-007 with the Decision 3 deviation
- `ARCHITECTURE.md §7.3` — annotate that conflicts are detected and reported, not overwritten

---

## 11. "Done" criteria

- [ ] `POST /api/v1/sync` accepts a batch of ≤200 records and returns per-record outcomes
- [ ] All five entity types round-trip: `VITAL`, `SYMPTOM`, `ACTIVITY`, `DOSE_LOG`, `MEDICATION`
- [ ] Dose logs resolve a medication created in the **same batch** via `medicationClientRecordId`
- [ ] Re-sending an identical batch yields all `DUPLICATE` and creates no duplicate rows
- [ ] A divergent payload under an existing `client_record_id` yields `CONFLICT`, and the stored row is unchanged
- [ ] One invalid record does not prevent its neighbours from committing
- [ ] The concurrency race test passes on all five create paths (and demonstrably failed before the fix)
- [ ] Transient failures surface as `500`, never as `REJECTED`
- [ ] `SyncService` imports no feature package
- [ ] Batch cap read from `application.yml`, not hardcoded
- [ ] Full suite green (158 existing + new); `mvn clean install` passes
- [ ] Docs updated per §10
- [ ] **Project owner has signed off on the two ⚠️ DEVIATIONs** (Decisions 1 and 3)

---

## 12. Out of scope for Slice 7 (and where it lands)

- **Offline medication edits** — needs `op` semantics + edit-conflict policy (Decision 7). Own slice if wanted.
- **Pull / `changed-since` cursor** — only if multi-device enters scope (Decision 2).
- **Server-side sync audit log** — structured logging first; revisit only if field bugs demand it (Decision 1).
- **Alert engine** (`alerts`, FR-DEC/FR-NOT) — consumes `flagged`/`overall_severity`; never slice-mapped.
- **Clinician cross-user access (FR-COM)** — being narrowed out; all endpoints patient-self-scoped.
- **The entire Flutter side of offline** (FR-OFF-002/-003/-004/-009/-010/-011) — the larger remaining half of the project.
