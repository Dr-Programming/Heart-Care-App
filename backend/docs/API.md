# API Reference

**Base URL:** `/api/v1`
**Auth:** `Authorization: Bearer <JWT>` on protected routes.
**Response envelope (all endpoints):**
```json
{ "success": true, "data": {}, "message": "OK", "timestamp": "2026-06-30T10:00:00Z" }
```

## Auth

### POST `/auth/register` — public
Registers a patient and returns a JWT (auto-login).
Request: `{ "fullName": "Abebe", "email": "abe@example.com", "password": "min 8 chars" }`
`data`: `{ "token": "...", "userId": "...", "role": "PATIENT" }`
Errors: `409` email already registered · `400` validation.

### POST `/auth/login` — public
Request: `{ "email": "...", "password": "..." }`
`data`: `{ "token": "...", "userId": "...", "role": "PATIENT" }`
Errors: `401` invalid email or password.

### GET `/auth/me` — Bearer JWT
`data`: `{ "userId": "...", "fullName": "...", "email": "...", "role": "PATIENT" }`
Errors: `401` missing/invalid/expired token.

> JWT lifetime: 7 days. Logout is client-side (discard the token).

## Patient Profile

All endpoints require `Authorization: Bearer <JWT>`.

### GET `/patients/me` — Bearer JWT
Returns the authenticated patient's profile. If no profile has been saved yet, returns `200` with an all-null skeleton (`comorbidities` is `[]`, `goals` is `null`) — not a `404`.

`data`:
```json
{
  "userId": "...",
  "birthYear": 1975,
  "preferredLanguage": "am",
  "heightCm": 172,
  "chdStage": "Stage II",
  "diseaseHistory": "prior MI",
  "comorbidities": ["diabetes", "hypertension"],
  "managementPlan": "statin + aspirin",
  "goals": {
    "bpSystolic": 120, "bpDiastolic": 80, "totalCholesterol": 180,
    "stepsPerDay": 8000, "targetWeightKg": 70, "dietNote": "low salt"
  }
}
```
Errors: `401` missing/invalid/expired token.

### PUT `/patients/me` — Bearer JWT
Creates or replaces the authenticated patient's profile (full-replace upsert). Request body is the same shape as the response above minus `userId`; all fields optional — **any field omitted from the body is cleared to `null`**, so clients should send their complete profile on every call, not a partial diff.
Validation: `birthYear` 1900–2100 · `preferredLanguage` ∈ {`en`, `am`} · `heightCm` 50–250 · `chdStage` ≤ 50 chars.
`data`: the saved profile (same shape as `GET /patients/me`).
Errors: `400` validation · `401` missing/invalid/expired token.

## Medications & Dose Logs

All endpoints require `Authorization: Bearer <JWT>`. Base path `/api/v1`.
Operations on another user's records return `404` (never `403` — existence is not revealed).
`POST` creates are idempotent on `clientRecordId`: repeating a create with the same value
returns the existing row instead of duplicating.

### POST `/medications` — Bearer JWT
Create a medication.
Request: `{ name, doseMg, frequency, scheduleTimes[], active?, clientRecordId? }` where
`frequency` ∈ {`ONCE_DAILY`, `BID`, `TID`, `CUSTOM`} and each `scheduleTimes` entry is `HH:mm` (24-hour).
Validation: `name` required (≤ 255) · `doseMg` > 0 · `frequency` required · `scheduleTimes` entries `HH:mm`.
`data`: the created medication.
Errors: `400` validation/malformed body · `401` missing/invalid token.

### GET `/medications?includeInactive=false` — Bearer JWT
List the caller's medications, newest first. `includeInactive=true` also returns deactivated ones.
`data`: array of medications.
Errors: `401` missing/invalid token.

### PUT `/medications/{id}` — Bearer JWT
Full-replace of `name, doseMg, frequency, scheduleTimes, active`. `clientRecordId` is never changed.
`data`: the updated medication.
Errors: `400` validation · `401` missing/invalid token · `404` not owned.

### DELETE `/medications/{id}` — Bearer JWT
Soft-deactivate (sets `active: false`; dose history is preserved — never hard-deleted).
`data`: the deactivated medication.
Errors: `401` missing/invalid token · `404` not owned.

### POST `/medications/{id}/doses` — Bearer JWT
Log a dose against an owned medication.
Request: `{ status, scheduledDate, scheduledTime?, loggedAt?, note?, clientRecordId? }` where
`status` ∈ {`TAKEN`, `MISSED`, `SKIPPED`}. `scheduledDate` (`YYYY-MM-DD`) required; `loggedAt`
defaults to now (UTC) when omitted; `note` ≤ 500 chars.
`data`: the created dose log.
Errors: `400` validation/malformed body · `401` missing/invalid token · `404` medication not owned.

### GET `/dose-logs?from=&to=&medicationId=` — Bearer JWT
Return the caller's dose history, newest first (by `scheduledDate`, then `loggedAt`).
All filters optional: `from`/`to` bound `scheduledDate` inclusively (`YYYY-MM-DD`);
`medicationId` narrows to a single medication.
`data`: array of dose logs.
Errors: `401` missing/invalid token.

## Health Vitals

All under `/api/v1`. Each reading is one row of a given `type`; numeric values live in a JSON `values` map. The server computes `flagged` (clinical alert threshold, FR-VIT-008) and, for `WEIGHT`, `bmi` from the profile's `heightCm`. Append-only; idempotent on `clientRecordId`.

Per-type `values` keys (canonical units):
- `BLOOD_PRESSURE` — `systolic`, `diastolic` (mmHg; `systolic > diastolic`)
- `GLUCOSE` — `glucose` (mmol/L)
- `HEART_RATE` — `heartRate` (bpm)
- `WEIGHT` — `weight` (kg); response adds `bmi` when height is known
- `CHOLESTEROL` — `ldl`, `hdl`, `total` (mmol/L)

### POST `/vitals` — Bearer JWT
Request:
```json
{ "type": "BLOOD_PRESSURE", "values": { "systolic": 190, "diastolic": 100 },
  "measuredAt": "2026-07-10T08:15:00Z", "note": "felt dizzy", "clientRecordId": "..." }
```
`measuredAt`, `note`, `clientRecordId` optional; any client-sent `flagged`/`bmi` is ignored. Response `data`:
```json
{ "id": "...", "type": "BLOOD_PRESSURE", "values": { "systolic": 190, "diastolic": 100 },
  "flagged": true, "measuredAt": "2026-07-10T08:15:00Z", "note": "felt dizzy",
  "clientRecordId": "...", "createdAt": "2026-07-10T08:15:02Z" }
```
`400` on unknown `type`, missing/unknown `values` key, non-numeric or out-of-range value, or `systolic <= diastolic`.

### GET `/vitals?type=&from=&to=` — Bearer JWT
Optional `type` (enum), `from`/`to` (ISO dates, filter on `measuredAt`). Returns the user's readings, newest first.

## Symptom Check-ins

All under `/api/v1`. Each check-in is one row; the patient-entered fields live in a JSON `data`
map and the server computes a clinical severity `assessment` from them (FR-SYM-010) — any
client-sent `assessment` key is rejected as unknown. Append-only; idempotent on `clientRecordId`.

`data` keys (all required except `worseThanYesterday`):
- `chestPain` — `{ present: boolean, severity?: 0-10 }`; `severity` required when `present` is `true`
- `shortnessOfBreath` — one of `NONE` / `MILD` / `SEVERE`
- `heartRate` — integer, 20-300 (bpm)
- `bloodPressure` — `{ systolic: 40-300, diastolic: 40-300 }`; `systolic > diastolic`
- `swelling` — boolean
- `energyLevel` — integer, 0-10
- `worseThanYesterday` — optional `{ <symptomKey>: boolean, ... }`; keys must be one of the six above

### POST `/symptoms` — Bearer JWT
Request:
```json
{ "data": {
    "chestPain": { "present": true, "severity": 8 },
    "shortnessOfBreath": "MILD",
    "heartRate": 82,
    "bloodPressure": { "systolic": 165, "diastolic": 92 },
    "swelling": true,
    "energyLevel": 4
  }, "note": "tight chest", "clientRecordId": "..." }
```
`measuredAt`, `note`, `clientRecordId` optional; `measuredAt` defaults to now (UTC) when omitted.
The server computes `assessment` server-side — it is never accepted from the client (sending an
`assessment` key inside `data` is rejected as an unknown key). Response `data`:
```json
{ "id": "...", "data": { "chestPain": { "present": true, "severity": 8 }, "...": "..." },
  "assessment": { "overall": "EMERGENCY",
    "symptoms": { "chestPain": "EMERGENCY", "shortnessOfBreath": "MONITOR",
      "bloodPressure": "URGENT", "heartRate": "NONE", "swelling": "MONITOR", "energyLevel": "NONE" } },
  "measuredAt": "2026-07-10T08:15:00Z", "note": "tight chest",
  "clientRecordId": "...", "createdAt": "2026-07-10T08:15:02Z" }
```
`assessment.overall` is the maximum severity across all six per-symptom assessments
(`NONE` < `MONITOR` < `URGENT` < `EMERGENCY`).
`400` on missing/unknown `data` key, wrong type, out-of-range value, unrecognized
`shortnessOfBreath` value or `worseThanYesterday` symptom key, missing `chestPain.severity`
when `chestPain.present` is `true`, or `systolic <= diastolic`.

### GET `/symptoms?from=&to=` — Bearer JWT
Optional `from`/`to` (`YYYY-MM-DD`) bound `measuredAt` by UTC calendar day, inclusive on both
ends (internally a half-open `[from 00:00Z, to+1day 00:00Z)` range). Returns the user's
check-ins, newest first.

**Severity → recommended action** (client-rendered, EN/AM; FR-SYM-010). These thresholds and
actions are documented defaults pending clinical sign-off (spec §0):

| Severity | Recommended action (rendered client-side, EN/AM) |
|----------|--------------------------------------------------|
| NONE | No action; keep monitoring |
| MONITOR | Self-care; watch for changes |
| URGENT | Contact your clinician today |
| EMERGENCY | Call your emergency contact now |

## Activity Logs

All under `/api/v1`. Each logged session is one row; the patient-entered fields live in a JSON
`data` map. Unlike vitals/symptoms, the server computes **no** classification, flag, or severity
for an activity log — it is pure persist-and-serve. Append-only; idempotent on `clientRecordId`.

`data` keys:

| Key | Type | Required |
|---|---|---|
| `type` | enum: `WALKING` / `JOGGING` / `CYCLING` / `HOUSEHOLD` / `FARMING` / `STRETCHING` / `OTHER` | ✅ |
| `durationMinutes` | int, 1-1440 | ✅ |
| `intensity` | enum: `LIGHT` / `MODERATE` / `VIGOROUS` | ✅ |
| `steps` | int, 0-100000 | ❌ |
| `distanceMeters` | number, 0-100000 | ❌ |

`type` and `intensity` are language-neutral codes; the client renders localized EN/AM labels
(same approach as `Severity`). There is no server-computed field on an activity log.

### POST `/activities` — Bearer JWT
Request:
```json
{
  "data": {
    "type": "WALKING",
    "durationMinutes": 30,
    "intensity": "MODERATE",
    "steps": 3200,
    "distanceMeters": 2400
  },
  "measuredAt": "2026-07-16T06:30:00Z",
  "note": "morning walk to the market",
  "clientRecordId": "…uuid…"
}
```
`measuredAt`, `note`, `clientRecordId` optional; `measuredAt` defaults to now (UTC) when omitted;
`note` ≤ 500 chars. Response `data`:
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
`400` on missing/unknown `data` key, unrecognized `type`/`intensity` enum value, wrong field
type, or out-of-range `durationMinutes`/`steps`/`distanceMeters`.

### GET `/activities?from=&to=` — Bearer JWT
Optional `from`/`to` (ISO dates) bound `measuredAt` by UTC calendar day, inclusive on both ends
(internally a half-open `[from 00:00Z, to+1day 00:00Z)` range). Returns the user's activity
history, newest first (`measuredAt` desc).

## Sync

`POST /api/v1/sync` — Bearer JWT. Submits a batch of records created offline and gets back a
per-record verdict. Push-only: there is no pull direction — a fresh install (or a second device)
restores by calling the existing `GET` endpoints (`/vitals`, `/symptoms`, `/activities`,
`/dose-logs`, `/medications`, `/patients/me`). Patient-self-scoped: `userId` comes from the JWT,
never the payload.

`payload` is verbatim each feature's existing request DTO shape — `VITAL` payloads are
`VitalLogRequest`, `SYMPTOM` payloads are `SymptomLogRequest`, `ACTIVITY` payloads are
`ActivityLogRequest`, `MEDICATION` payloads are `MedicationRequest` — so the validation rules
documented above for each feature apply unchanged here. `DOSE_LOG` is the one sync-only shape
(below), because the direct dose endpoint takes the medication from the URL path and a
never-synced device has no server id to put there. Any `clientRecordId` inside `payload` is
ignored; the envelope's `clientRecordId` is the sole idempotency key.

Within a batch, `MEDICATION` records are always processed before `DOSE_LOG` records regardless of
request order, so a dose can reference a medication created in the **same** batch — see
`medicationClientRecordId` below. `results` preserves request order even though processing order
differs.

### Request

```
POST /api/v1/sync
Authorization: Bearer <jwt>
Content-Type: application/json
```

```json
{
  "records": [
    { "clientRecordId": "9f1c2b7e-0000-0000-0000-000000000001", "entityType": "MEDICATION",
      "payload": { "name": "Atorvastatin", "doseMg": 20, "frequency": "ONCE_DAILY",
                   "scheduleTimes": ["08:00"] } },
    { "clientRecordId": "2b7edc44-0000-0000-0000-000000000002", "entityType": "DOSE_LOG",
      "payload": { "medicationClientRecordId": "9f1c2b7e-0000-0000-0000-000000000001",
                   "status": "TAKEN", "scheduledDate": "2026-07-16",
                   "loggedAt": "2026-07-16T08:05:00+03:00" } },
    { "clientRecordId": "44d0a3b1-0000-0000-0000-000000000003", "entityType": "VITAL",
      "payload": { "type": "BLOOD_PRESSURE", "values": { "systolic": 128, "diastolic": 82 },
                   "measuredAt": "2026-07-16T08:10:00+03:00" } }
  ]
}
```

`entityType` ∈ {`VITAL`, `SYMPTOM`, `ACTIVITY`, `MEDICATION`, `DOSE_LOG`}. Medication *edits*
(update/deactivate) are not syncable — adding a medication offline works, editing one requires
connectivity. `DOSE_LOG.payload` takes exactly one of `medicationId` (server UUID) or
`medicationClientRecordId`, plus `status` (`TAKEN`/`MISSED`/`SKIPPED`), `scheduledDate`
(required, `YYYY-MM-DD`), and optional `scheduledTime`, `loggedAt`, `note`.

### Response

`200 OK`, wrapped in the standard `ApiResponse<T>` envelope:

```json
{
  "success": true,
  "message": "Sync processed",
  "data": {
    "results": [
      { "clientRecordId": "9f1c2b7e-0000-0000-0000-000000000001", "status": "SAVED",     "serverId": "a3f1..." },
      { "clientRecordId": "2b7edc44-0000-0000-0000-000000000002", "status": "SAVED",     "serverId": "b7de..." },
      { "clientRecordId": "44d0a3b1-0000-0000-0000-000000000003", "status": "DUPLICATE", "serverId": "c19a..." },
      { "clientRecordId": "81aa5e02-0000-0000-0000-000000000004", "status": "REJECTED",  "reason": "durationMinutes is out of range" }
    ]
  }
}
```

`results` preserves request order. There are no summary counts — the client derives them
trivially from the array.

### Statuses

| Status | Meaning | `serverId` | Client action |
|---|---|---|---|
| `SAVED` | New record committed | ✅ | mark `SYNCED`, store `serverId` |
| `DUPLICATE` | `clientRecordId` already stored, payload matches | ✅ | mark `SYNCED`, store `serverId` |
| `CONFLICT` | `clientRecordId` already stored, payload **differs** — the stored record always wins; the incoming payload is never written | ✅ | mark `SYNCED`; surface/log — a genuine conflict signals a client bug reusing a UUID, not a data merge |
| `REJECTED` | Payload invalid, or unknown `entityType`; will never succeed | ✗ (`reason` instead) | do **not** retry; flag for the user |

`SAVED`, `DUPLICATE`, and `CONFLICT` all mean the server now holds this record under that
`clientRecordId` — the client marks all three `SYNCED`. That `serverId` is what lets a later
batch reference a medication by server id instead of `medicationClientRecordId`.

### Errors

- **`400`, whole batch rejected before any record is processed** — `records` missing/empty,
  `records.size()` over the configured cap (`app.sync.max-batch-size`, 200 by default; the client
  chunks larger batches), or any record missing `clientRecordId`, `entityType`, or `payload`.
  These are envelope-structure problems the client caused, not record content, so nothing is
  processed and there is no partial result to report.
- **Per-record `REJECTED` inside a `200`** — the record's own content is the problem: unknown
  `entityType`, a Bean Validation failure on the mapped DTO (e.g. a blank medication name),
  malformed payload JSON, an unrecognized enum value, or a `DOSE_LOG` whose
  `medicationId`/`medicationClientRecordId` doesn't resolve to an owned medication. One bad
  record never blocks its neighbours — the rest of the batch still commits.
- **`500`, whole batch fails** — a transient failure not tied to any record's content (database
  unavailable, an unexpected error). The client must keep **every** record queued and retry the
  whole batch later; do not treat this like `REJECTED`. Retrying is safe because of idempotency —
  records already committed on the failed attempt come back `DUPLICATE` on the retry, so nothing
  double-saves.
