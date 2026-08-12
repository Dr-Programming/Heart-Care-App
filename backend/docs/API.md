# API Reference

Complete reference for the Heart-Care backend REST API. Every endpoint, request/response shape,
validation rule, and error code below was verified against the controllers and DTOs in
`backend/src/main/java/com/heartcare/`.

- [Conventions](#conventions) · [Errors](#error-handling) · [Limits](#limits-and-quotas)
- [Auth](#1-auth) · [Patient Profile](#2-patient-profile) · [Medications](#3-medications) ·
  [Dose Logs](#4-dose-logs) · [Vitals](#5-health-vitals) · [Symptoms](#6-symptom-check-ins) ·
  [Activity](#7-activity-logs) · [Sync](#8-sync)
- [Enum reference](#enum-reference)

---

## Conventions

### Base URL

| Environment | Base URL |
|---|---|
| Local dev | `http://localhost:8080/api/v1` |
| Production | `https://<railway-host>/api/v1` |

Every path below is written in full relative to that base, e.g. `POST /api/v1/vitals`.

### Authentication

All endpoints require a bearer token **except** `POST /api/v1/auth/register` and
`POST /api/v1/auth/login`.

```
Authorization: Bearer <jwt>
```

The token is an HS256 JWT with a **7-day** lifetime carrying the user id as `sub` and a `role`
claim. There is no refresh token and no server-side revocation — logout is client-side (discard
the token). `userId` is always taken from the token, never from a request body or path, so no
endpoint can act on another user's data.

### Response envelope

Every response — success **and** error — uses the same envelope:

```json
{
  "success": true,
  "data": { },
  "message": "OK",
  "timestamp": "2026-07-19T10:00:00Z"
}
```

| Field | Type | Notes |
|---|---|---|
| `success` | boolean | `false` on every 4xx/5xx |
| `data` | object \| array \| null | Always `null` on an error |
| `message` | string | `"OK"` unless the endpoint sets one; the error text on failure |
| `timestamp` | ISO-8601 UTC | Server time the response was built |

An error therefore looks like:

```json
{
  "success": false,
  "data": null,
  "message": "doseMg must be greater than 0",
  "timestamp": "2026-07-19T10:00:00Z"
}
```

### Dates and times

| Kind | Format | Example |
|---|---|---|
| Timestamp (`measuredAt`, `loggedAt`, `createdAt`) | ISO-8601 with offset | `2026-07-16T08:05:00+03:00` |
| Calendar date (`scheduledDate`, `from`, `to`) | `YYYY-MM-DD` | `2026-07-16` |
| Time of day (`scheduledTime`, `scheduleTimes`) | `HH:mm` 24-hour | `08:00` |

Timestamps are stored as `timestamptz` and returned in UTC. `from`/`to` query filters are
interpreted as **UTC calendar days, inclusive on both ends** (internally a half-open
`[from 00:00Z, to+1day 00:00Z)` range).

### Idempotency

Every log-type `POST` accepts an optional `clientRecordId` (a UUID the device generates). Repeating
a create with the same `clientRecordId` returns the **existing** record instead of duplicating it,
enforced by a `UNIQUE (user_id, client_record_id)` database constraint rather than an
application-level check — so it holds under concurrent retries.

Omitting `clientRecordId` disables deduplication for that call: two identical requests create two
rows. Offline-first clients should always send one.

---

## Error handling

### Status codes

| Code | Meaning | When |
|---|---|---|
| `200 OK` | Success | All successful calls, including creates (no `201` is used) |
| `400 Bad Request` | Invalid input | Body validation failure, malformed JSON, bad enum/date/UUID in a query param, missing required query param |
| `401 Unauthorized` | Not authenticated | Missing, malformed, expired, or badly-signed token |
| `404 Not Found` | Absent or not owned | Unknown route, or a record that does not exist **or belongs to another user** |
| `405 Method Not Allowed` | Wrong verb | e.g. `GET /api/v1/medications/{id}` (only `PUT`/`DELETE` exist) |
| `409 Conflict` | Duplicate | Registering a phone that already exists |
| `413 Payload Too Large` | Body over cap | Request body exceeds 2 MB |
| `423 Locked` | Account locked | Five consecutive failed logins; the account is unavailable for 15 minutes |
| `500 Internal Server Error` | Transient/unexpected | Database unavailable or an unhandled fault. Details are never leaked — the response is always `"An unexpected error occurred"` |

### `404` vs `403`

Operating on a record owned by another user returns **`404`, never `403`**. This is deliberate:
a `403` would confirm the record exists. Clients cannot distinguish "no such record" from "not
yours", by design.

### Validation error format

Body validation failures return every violated field in one message, `field: message` joined by
`; ` and sorted:

```json
{
  "success": false,
  "data": null,
  "message": "doseMg: doseMg must be greater than 0; name: name is required",
  "timestamp": "2026-07-19T10:00:00Z"
}
```

Sync applies the identical format per record (in `results[].reason`), so a validation failure reads
the same whether it arrived via a direct `POST` or a sync batch.

### Retry semantics

`400`, `404`, `405`, `409`, and `413` are **permanent** — the request can never succeed as written,
so a client must not retry it. `401` is permanent until re-authentication. `423` is temporary but
must not be retried on a timer — it clears only after the 15-minute lockout window. Only `500` is
transient and worth retrying. This distinction matters for the offline queue: retrying a
permanently-failed record forever would block the queue behind it.

---

## Limits and quotas

| Limit | Value | Configured by | Exceeding it |
|---|---|---|---|
| Request body size | 2 MB | `app.sync.max-body-bytes` | `413` |
| Sync batch size | 200 records | `app.sync.max-batch-size` | `400`, whole batch |
| PIN length | Exactly 4 digits | `RegisterRequest` / `LoginRequest` | `400` |
| Failed logins per account | 5, then a 15-minute lock | `app.auth.lockout.*` | `423` |
| `note` field | 500 chars | per-DTO `@Size` | `400` |
| Medication `name` | 255 chars | `MedicationRequest` | `400` |
| Token lifetime | 7 days | `app.jwt.expiration-ms` | `401` |

Apart from the per-account login lockout above, there is **no rate limiting** on any endpoint — no
per-IP or global throttle.

---

## 1. Auth

### `POST /api/v1/auth/register` — public

Registers a patient and returns a token plus the user (auto-login). Role is always `PATIENT`; it
cannot be set by the client. Registration is identity only — medical details are set later through
`PUT /api/v1/patients/me`.

**Request**

```json
{
  "phone": "+251911234567",
  "pin": "1234",
  "name": "Abebe Bekele",
  "preferredLanguage": "am"
}
```

| Field | Type | Required | Rules |
|---|---|---|---|
| `phone` | string | ✅ | `+251` followed by exactly 9 digits |
| `pin` | string | ✅ | Exactly 4 digits |
| `name` | string | ✅ | Not blank, ≤ 255 characters |
| `preferredLanguage` | string | ✅ | `en` or `am` |

> The PIN is stored only as a BCrypt hash and is never returned or logged. Four digits is
> defensible only because login is lockout-limited — see below.

**Response** `200 OK`

```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "user": {
      "id": "3f2a9c1e-5b7d-4e8a-9f01-2c3d4e5f6a7b",
      "name": "Abebe Bekele",
      "phone": "+251911234567",
      "preferredLanguage": "am",
      "role": "PATIENT"
    }
  },
  "message": "Registered",
  "timestamp": "2026-08-06T10:00:00Z"
}
```

**Errors**

| Code | Cause |
|---|---|
| `400` | Malformed phone, PIN that is not exactly 4 digits, blank name, unsupported language |
| `409` | `"Phone already registered"` |

> Registration reveals whether a phone is already in use. Login deliberately does not.

---

### `POST /api/v1/auth/login` — public

**Request**

```json
{ "phone": "+251911234567", "pin": "1234" }
```

**Response** `200 OK` — same `data` shape as register; `message` is `"Logged in"`.

**Errors**

| Code | Cause |
|---|---|
| `400` | Malformed phone or PIN |
| `401` | `"Invalid phone or PIN"` |
| `423` | `"Too many failed attempts. Try again in N minutes."` |

> The `401` message is identical for an unknown phone and a wrong PIN, so login cannot be used to
> enumerate accounts.

**Lockout.** Five consecutive failed attempts lock that account for 15 minutes. While locked, every
login returns `423` — including one with the correct PIN, which is what makes the limit real. Any
successful login resets the counter, and the counter also resets once the window elapses. The limit
is per account, held in the `users` row; there is no IP-based or global rate limit.

Clients must treat `423` as "wait", not "wrong PIN": re-prompting immediately just burns the
window. The message carries the remaining minutes.

---

### `GET /api/v1/auth/me` — authenticated

Returns the current user.

**Response** `200 OK`

```json
{
  "success": true,
  "data": {
    "id": "3f2a9c1e-5b7d-4e8a-9f01-2c3d4e5f6a7b",
    "name": "Abebe Bekele",
    "phone": "+251911234567",
    "preferredLanguage": "am",
    "role": "PATIENT"
  },
  "message": "OK",
  "timestamp": "2026-08-06T10:00:00Z"
}
```

**Errors:** `401` missing/invalid/expired token · `404` user no longer exists (deleted account with
a still-valid token).

---

## 2. Patient Profile

One profile per user, keyed by user id. There is no create step — `PUT` upserts.

### `GET /api/v1/patients/me` — authenticated

Returns the profile. If none has been saved, returns `200` with an **all-null skeleton** (with
`comorbidities: []` and `goals: null`) — **not** a `404`. Clients never need to special-case a
first run.

**Response** `200 OK`

```json
{
  "success": true,
  "data": {
    "userId": "3f2a9c1e-5b7d-4e8a-9f01-2c3d4e5f6a7b",
    "birthYear": 1975,
    "preferredLanguage": "am",
    "heightCm": 172,
    "chdStage": "Stage II",
    "diseaseHistory": "prior MI in 2021",
    "comorbidities": ["diabetes", "hypertension"],
    "managementPlan": "statin + aspirin daily",
    "goals": {
      "bpSystolic": 120,
      "bpDiastolic": 80,
      "totalCholesterol": 180,
      "stepsPerDay": 8000,
      "targetWeightKg": 70,
      "dietNote": "low salt"
    }
  },
  "message": "OK",
  "timestamp": "2026-07-19T10:00:00Z"
}
```

**Errors:** `401`.

---

### `PUT /api/v1/patients/me` — authenticated

Creates or replaces the profile. **Full-replace, not a patch: any field omitted from the body is
cleared to `null`.** Clients must send the complete profile on every call.

**Request** — same shape as the response above, minus `userId`. All fields are optional.

```json
{
  "birthYear": 1975,
  "preferredLanguage": "am",
  "heightCm": 172,
  "chdStage": "Stage II",
  "diseaseHistory": "prior MI in 2021",
  "comorbidities": ["diabetes", "hypertension"],
  "managementPlan": "statin + aspirin daily",
  "goals": {
    "bpSystolic": 120, "bpDiastolic": 80, "totalCholesterol": 180,
    "stepsPerDay": 8000, "targetWeightKg": 70, "dietNote": "low salt"
  }
}
```

| Field | Type | Rules |
|---|---|---|
| `birthYear` | int | 1900–2100 |
| `preferredLanguage` | string | `en` or `am` |
| `heightCm` | int | 50–250 |
| `chdStage` | string | ≤ 50 chars |
| `diseaseHistory` | string | Unbounded |
| `comorbidities` | string[] | `null` is stored as `[]` |
| `managementPlan` | string | Unbounded |
| `goals.*` (numeric) | int | Must not be negative |
| `goals.dietNote` | string | Unbounded |

**Response** `200 OK` — the saved profile, `message: "Profile saved"`.

**Errors:** `400` validation · `401`.

> `heightCm` is not cosmetic: it is what lets `POST /vitals` compute BMI for `WEIGHT` readings.
> With no height on the profile, `bmi` is simply omitted.

---

## 3. Medications

Idempotent on `clientRecordId`. Medications are **never hard-deleted** — `DELETE` deactivates, so
dose history stays intact.

### `POST /api/v1/medications` — authenticated

**Request**

```json
{
  "name": "Atorvastatin",
  "doseMg": 20,
  "frequency": "ONCE_DAILY",
  "scheduleTimes": ["08:00"],
  "active": true,
  "clientRecordId": "9f1c2b7e-0000-0000-0000-000000000001"
}
```

| Field | Type | Required | Rules |
|---|---|---|---|
| `name` | string | ✅ | Not blank, ≤ 255 chars |
| `doseMg` | number | ✅ | > 0 |
| `frequency` | enum | ✅ | `ONCE_DAILY` · `BID` · `TID` · `CUSTOM` |
| `scheduleTimes` | string[] | ❌ | Each entry `HH:mm` 24-hour; `null` → `[]` |
| `active` | boolean | ❌ | Defaults to `true` |
| `clientRecordId` | UUID | ❌ | Idempotency key |

**Response** `200 OK`, `message: "Medication created"`

```json
{
  "success": true,
  "data": {
    "id": "a3f1b2c4-1111-2222-3333-444455556666",
    "name": "Atorvastatin",
    "doseMg": 20.00,
    "frequency": "ONCE_DAILY",
    "scheduleTimes": ["08:00"],
    "active": true,
    "clientRecordId": "9f1c2b7e-0000-0000-0000-000000000001",
    "createdAt": "2026-07-19T10:00:00Z",
    "updatedAt": "2026-07-19T10:00:00Z"
  },
  "message": "Medication created",
  "timestamp": "2026-07-19T10:00:00Z"
}
```

**Errors:** `400` validation or malformed body · `401`.

---

### `GET /api/v1/medications` — authenticated

**Query parameters**

| Param | Type | Default | Notes |
|---|---|---|---|
| `includeInactive` | boolean | `false` | `true` also returns deactivated medications |

**Response** `200 OK` — array of medication objects, newest first (`createdAt` desc). `data` is
`[]` when there are none.

**Errors:** `400` non-boolean `includeInactive` · `401`.

---

### `PUT /api/v1/medications/{id}` — authenticated

Full replace of `name`, `doseMg`, `frequency`, `scheduleTimes`, `active`. `clientRecordId` is
never changed. Omitting `active` leaves it unchanged (unlike the other fields).

**Path:** `id` — medication UUID.
**Request:** same shape as `POST`.
**Response** `200 OK` — the updated medication, `message: "Medication updated"`.

**Errors:** `400` validation or non-UUID `id` · `401` · `404` unknown or owned by another user.

---

### `DELETE /api/v1/medications/{id}` — authenticated

Soft-deactivates (`active: false`). Idempotent — deactivating twice is fine.

**Response** `200 OK` — the deactivated medication, `message: "Medication deactivated"`.

**Errors:** `400` non-UUID `id` · `401` · `404` unknown or not owned.

> Dose logs are **not** deleted or detached. History for a deactivated medication remains queryable
> via `GET /dose-logs`.

---

## 4. Dose Logs

Append-only: there is no update or delete. Idempotent on `clientRecordId`.

### `POST /api/v1/medications/{medicationId}/doses` — authenticated

Logs a dose against an owned medication.

**Path:** `medicationId` — must belong to the caller.

**Request**

```json
{
  "status": "TAKEN",
  "scheduledDate": "2026-07-16",
  "scheduledTime": "08:00",
  "loggedAt": "2026-07-16T08:05:00+03:00",
  "note": "taken with breakfast",
  "clientRecordId": "2b7edc44-0000-0000-0000-000000000002"
}
```

| Field | Type | Required | Rules |
|---|---|---|---|
| `status` | enum | ✅ | `TAKEN` · `MISSED` · `SKIPPED` |
| `scheduledDate` | date | ✅ | `YYYY-MM-DD` |
| `scheduledTime` | time | ❌ | `HH:mm` |
| `loggedAt` | timestamp | ❌ | Defaults to now (UTC) |
| `note` | string | ❌ | ≤ 500 chars |
| `clientRecordId` | UUID | ❌ | Idempotency key |

**Response** `200 OK`, `message: "Dose logged"`

```json
{
  "success": true,
  "data": {
    "id": "b7de1122-aaaa-bbbb-cccc-ddddeeeeffff",
    "medicationId": "a3f1b2c4-1111-2222-3333-444455556666",
    "scheduledDate": "2026-07-16",
    "scheduledTime": "08:00",
    "status": "TAKEN",
    "loggedAt": "2026-07-16T05:05:00Z",
    "note": "taken with breakfast",
    "clientRecordId": "2b7edc44-0000-0000-0000-000000000002",
    "createdAt": "2026-07-16T05:05:02Z"
  },
  "message": "Dose logged",
  "timestamp": "2026-07-16T05:05:02Z"
}
```

**Errors:** `400` validation, unknown `status`, malformed body, non-UUID `medicationId` · `401` ·
`404` medication unknown or not owned.

---

### `GET /api/v1/dose-logs` — authenticated

Dose history, newest first (`scheduledDate` desc, then `loggedAt` desc).

**Query parameters** — all optional

| Param | Type | Notes |
|---|---|---|
| `from` | date | Lower bound on `scheduledDate`, inclusive |
| `to` | date | Upper bound on `scheduledDate`, inclusive |
| `medicationId` | UUID | Narrow to one medication |

**Example:** `GET /api/v1/dose-logs?from=2026-07-01&to=2026-07-31&medicationId=a3f1b2c4-...`

**Response** `200 OK` — array of dose logs (shape above). `[]` when nothing matches.

**Errors:** `400` unparseable date or non-UUID `medicationId` · `401`.

> An unknown but well-formed `medicationId` returns `200` with `[]`, not `404` — the filter matches
> nothing rather than asserting the medication exists.

---

## 5. Health Vitals

Each reading is one row of a given `type`, with numeric values in a `values` map. Append-only;
idempotent on `clientRecordId`.

Two fields are **server-owned** and silently ignored if a client sends them:

- `flagged` — whether any value breached a clinical alert threshold (FR-VIT-008)
- `bmi` — computed for `WEIGHT` readings from the profile's `heightCm`; omitted when unknown

### `values` keys by type

| `type` | Required keys | Units | Sanity range (reject outside) |
|---|---|---|---|
| `BLOOD_PRESSURE` | `systolic`, `diastolic` | mmHg | 40–300 each; `systolic > diastolic` |
| `GLUCOSE` | `glucose` | mmol/L | 0–50 |
| `HEART_RATE` | `heartRate` | bpm | 20–300 |
| `WEIGHT` | `weight` | kg | 0–500 |
| `CHOLESTEROL` | `ldl`, `hdl`, `total` | mmol/L | 0–30 each |

`values` must contain **exactly** the required keys — a missing key and an extra key are both
`400`. Sanity ranges reject typos and garbage; they are much wider than the clinical flag
thresholds below.

### Flag thresholds

`flagged` is `true` when **any** value breaches its bound (`≤ low` or `≥ high`):

| Key | Low | High |
|---|---|---|
| `systolic` | 90 | 180 |
| `diastolic` | 60 | 120 |
| `glucose` | 4.0 | 11.1 |
| `heartRate` | 40 | 120 |
| `bmi` | 18.5 | 30 |
| `ldl` | — | 4.9 |
| `total` | — | 7.5 |
| `hdl` | 1.0 | — |

> These are documented defaults **pending clinical sign-off**, not clinically approved values.

### `POST /api/v1/vitals` — authenticated

**Request**

```json
{
  "type": "BLOOD_PRESSURE",
  "values": { "systolic": 190, "diastolic": 100 },
  "measuredAt": "2026-07-10T08:15:00Z",
  "note": "felt dizzy",
  "clientRecordId": "44d0a3b1-0000-0000-0000-000000000003"
}
```

| Field | Type | Required | Rules |
|---|---|---|---|
| `type` | enum | ✅ | See table above |
| `values` | object | ✅ | Exactly the required keys for `type`, all numeric |
| `measuredAt` | timestamp | ❌ | Defaults to now (UTC) |
| `note` | string | ❌ | ≤ 500 chars |
| `clientRecordId` | UUID | ❌ | Idempotency key |

**Response** `200 OK`, `message: "Vital logged"`

```json
{
  "success": true,
  "data": {
    "id": "c19a7788-9999-0000-1111-222233334444",
    "type": "BLOOD_PRESSURE",
    "values": { "systolic": 190, "diastolic": 100 },
    "flagged": true,
    "measuredAt": "2026-07-10T08:15:00Z",
    "note": "felt dizzy",
    "clientRecordId": "44d0a3b1-0000-0000-0000-000000000003",
    "createdAt": "2026-07-10T08:15:02Z"
  },
  "message": "Vital logged",
  "timestamp": "2026-07-10T08:15:02Z"
}
```

A `WEIGHT` reading with `heightCm` on the profile comes back with BMI merged in:

```json
{ "type": "WEIGHT", "values": { "weight": 82.0, "bmi": 27.7 }, "flagged": false, "...": "..." }
```

**Errors**

| Code | Cause |
|---|---|
| `400` | Unknown `type`; `values` missing, or not exactly the required key set; non-numeric value; value outside its sanity range; `systolic <= diastolic`; `note` over 500 chars |
| `401` | Missing/invalid token |

---

### `GET /api/v1/vitals` — authenticated

Readings newest first (`measuredAt` desc).

**Query parameters** — all optional

| Param | Type | Notes |
|---|---|---|
| `type` | enum | Filter to one vital type |
| `from` | date | UTC day, inclusive |
| `to` | date | UTC day, inclusive |

**Example:** `GET /api/v1/vitals?type=BLOOD_PRESSURE&from=2026-07-01&to=2026-07-31`

**Response** `200 OK` — array of readings. `[]` when nothing matches.

**Errors:** `400` unknown `type` value or unparseable date · `401`.

---

## 6. Symptom Check-ins

One row per check-in. Patient-entered fields live in `data`; the server computes an `assessment`
from them (FR-SYM-010). Append-only; idempotent on `clientRecordId`.

### `data` keys

| Key | Type | Required | Rules |
|---|---|---|---|
| `chestPain` | object | ✅ | `{ present: boolean, severity?: 0–10 }`; `severity` **required** when `present` is `true` |
| `shortnessOfBreath` | enum | ✅ | `NONE` · `MILD` · `SEVERE` |
| `heartRate` | int | ✅ | 20–300 |
| `bloodPressure` | object | ✅ | `{ systolic: 40–300, diastolic: 40–300 }`; `systolic > diastolic` |
| `swelling` | boolean | ✅ | — |
| `energyLevel` | int | ✅ | 0–10 |
| `worseThanYesterday` | object | ❌ | `{ <symptomKey>: boolean }`; keys must be from the six above |

`data` is strictly whitelisted: any key not listed is a `400`. `assessment` is server-owned, so
sending it inside `data` is rejected as an unknown key.

### How `assessment` is computed

Per-symptom severity, then `overall` = the maximum across all six
(`NONE` < `MONITOR` < `URGENT` < `EMERGENCY`):

| Symptom | `EMERGENCY` | `URGENT` | `MONITOR` | else |
|---|---|---|---|---|
| `chestPain` | severity ≥ 7 | severity 4–6 | severity 1–3 | not present, or 0 |
| `shortnessOfBreath` | — | `SEVERE` | `MILD` | `NONE` |
| `bloodPressure` | systolic ≥ 180 | systolic ≥ 160 or ≤ 90, or diastolic ≥ 100 or ≤ 60 | — | otherwise |
| `heartRate` | — | < 40 or > 120 | — | otherwise |
| `swelling` | — | — | `true` | `false` |
| `energyLevel` | — | — | ≤ 2 | otherwise |

> Documented defaults **pending clinical sign-off**.

### `POST /api/v1/symptoms` — authenticated

**Request**

```json
{
  "data": {
    "chestPain": { "present": true, "severity": 8 },
    "shortnessOfBreath": "MILD",
    "heartRate": 82,
    "bloodPressure": { "systolic": 165, "diastolic": 92 },
    "swelling": true,
    "energyLevel": 4,
    "worseThanYesterday": { "chestPain": true, "swelling": false }
  },
  "measuredAt": "2026-07-10T08:15:00Z",
  "note": "tight chest since morning",
  "clientRecordId": "5c2f8a91-0000-0000-0000-000000000005"
}
```

**Response** `200 OK`, `message: "Symptom check-in logged"`

```json
{
  "success": true,
  "data": {
    "id": "d41b9900-5555-6666-7777-888899990000",
    "data": {
      "chestPain": { "present": true, "severity": 8 },
      "shortnessOfBreath": "MILD",
      "heartRate": 82,
      "bloodPressure": { "systolic": 165, "diastolic": 92 },
      "swelling": true,
      "energyLevel": 4,
      "worseThanYesterday": { "chestPain": true, "swelling": false }
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
    "measuredAt": "2026-07-10T08:15:00Z",
    "note": "tight chest since morning",
    "clientRecordId": "5c2f8a91-0000-0000-0000-000000000005",
    "createdAt": "2026-07-10T08:15:02Z"
  },
  "message": "Symptom check-in logged",
  "timestamp": "2026-07-10T08:15:02Z"
}
```

**Errors**

| Code | Cause |
|---|---|
| `400` | Missing or unknown `data` key; wrong field type; out-of-range value; unrecognized `shortnessOfBreath`; unknown key in `worseThanYesterday`; missing `chestPain.severity` when `present` is `true`; `systolic <= diastolic`; `note` over 500 chars |
| `401` | Missing/invalid token |

### Severity → recommended action

Rendered client-side in EN/AM; the API returns only the severity code.

| Severity | Recommended action |
|---|---|
| `NONE` | No action; keep monitoring |
| `MONITOR` | Self-care; watch for changes |
| `URGENT` | Contact your clinician today |
| `EMERGENCY` | Call your emergency contact now |

---

### `GET /api/v1/symptoms` — authenticated

Check-ins newest first (`measuredAt` desc).

**Query parameters:** `from`, `to` (optional dates, UTC day, inclusive).

**Response** `200 OK` — array of check-ins. **Errors:** `400` unparseable date · `401`.

---

## 7. Activity Logs

One row per session. Unlike vitals and symptoms, the server computes **nothing** — no flag, no
severity, no classification. Pure persist-and-serve. Append-only; idempotent on `clientRecordId`.

### `data` keys

| Key | Type | Required | Rules |
|---|---|---|---|
| `type` | enum | ✅ | `WALKING` · `JOGGING` · `CYCLING` · `HOUSEHOLD` · `FARMING` · `STRETCHING` · `OTHER` |
| `durationMinutes` | int | ✅ | 1–1440 |
| `intensity` | enum | ✅ | `LIGHT` · `MODERATE` · `VIGOROUS` |
| `steps` | int | ❌ | 0–100000 |
| `distanceMeters` | number | ❌ | 0–100000 |

Strictly whitelisted — any other key is a `400`. `type` and `intensity` are language-neutral codes;
the client renders localized EN/AM labels.

### `POST /api/v1/activities` — authenticated

**Request**

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
  "clientRecordId": "81aa5e02-0000-0000-0000-000000000004"
}
```

**Response** `200 OK`, `message: "Activity logged"`

```json
{
  "success": true,
  "data": {
    "id": "e5c30011-1234-5678-9abc-def012345678",
    "data": {
      "type": "WALKING",
      "durationMinutes": 30,
      "intensity": "MODERATE",
      "steps": 3200,
      "distanceMeters": 2400
    },
    "measuredAt": "2026-07-16T06:30:00Z",
    "note": "morning walk to the market",
    "clientRecordId": "81aa5e02-0000-0000-0000-000000000004",
    "createdAt": "2026-07-16T06:30:02Z"
  },
  "message": "Activity logged",
  "timestamp": "2026-07-16T06:30:02Z"
}
```

**Errors:** `400` missing/unknown `data` key, unrecognized `type`/`intensity`, wrong type,
out-of-range `durationMinutes`/`steps`/`distanceMeters`, `note` over 500 chars · `401`.

---

### `GET /api/v1/activities` — authenticated

History newest first (`measuredAt` desc).

**Query parameters:** `from`, `to` (optional dates, UTC day, inclusive).

**Response** `200 OK` — array of activity logs. **Errors:** `400` unparseable date · `401`.

---

## 8. Sync

### `POST /api/v1/sync` — authenticated

Submits a batch of records created offline and returns a per-record verdict.

**Push-only.** There is no pull direction: a fresh install or second device restores by calling the
existing `GET` endpoints (`/medications`, `/dose-logs`, `/vitals`, `/symptoms`, `/activities`,
`/patients/me`).

`userId` always comes from the JWT, never the payload, so a batch can only ever write the caller's
own records.

### Record envelope

| Field | Type | Required | Notes |
|---|---|---|---|
| `clientRecordId` | UUID | ✅ | **The** idempotency key. Any `clientRecordId` inside `payload` is ignored and overwritten with this one |
| `entityType` | string | ✅ | `VITAL` · `SYMPTOM` · `ACTIVITY` · `MEDICATION` · `DOSE_LOG` |
| `payload` | object | ✅ | The feature's normal request body (see below) |

`payload` is verbatim each feature's existing request DTO — `VITAL` takes a `POST /vitals` body,
`SYMPTOM` a `POST /symptoms` body, `ACTIVITY` a `POST /activities` body, `MEDICATION` a
`POST /medications` body. **Every validation rule documented above applies unchanged here.**

`DOSE_LOG` is the one sync-only shape, because the direct endpoint takes the medication from the
URL path and a never-synced device has no server id to put there:

| Field | Type | Required | Notes |
|---|---|---|---|
| `medicationId` | UUID | one of the two | Server id of an owned medication |
| `medicationClientRecordId` | UUID | one of the two | `clientRecordId` of a medication — may be one created in this same batch |
| `status` | enum | ✅ | `TAKEN` · `MISSED` · `SKIPPED` |
| `scheduledDate` | date | ✅ | `YYYY-MM-DD` |
| `scheduledTime` | time | ❌ | `HH:mm` |
| `loggedAt` | timestamp | ❌ | Defaults to now (UTC) |
| `note` | string | ❌ | ≤ 500 chars |

Exactly one of `medicationId` / `medicationClientRecordId` must be present.

### Ordering

Within a batch, `MEDICATION` records are always processed **before** `DOSE_LOG` records regardless
of request order, so a dose can reference a medication created in the same batch. `results`
nonetheless preserves **request** order.

Medication *edits* (update/deactivate) are not syncable — creating a medication offline works,
editing one requires connectivity.

### Request

```
POST /api/v1/sync
Authorization: Bearer <jwt>
Content-Type: application/json
```

```json
{
  "records": [
    {
      "clientRecordId": "9f1c2b7e-0000-0000-0000-000000000001",
      "entityType": "MEDICATION",
      "payload": {
        "name": "Atorvastatin",
        "doseMg": 20,
        "frequency": "ONCE_DAILY",
        "scheduleTimes": ["08:00"]
      }
    },
    {
      "clientRecordId": "2b7edc44-0000-0000-0000-000000000002",
      "entityType": "DOSE_LOG",
      "payload": {
        "medicationClientRecordId": "9f1c2b7e-0000-0000-0000-000000000001",
        "status": "TAKEN",
        "scheduledDate": "2026-07-16",
        "loggedAt": "2026-07-16T08:05:00+03:00"
      }
    },
    {
      "clientRecordId": "44d0a3b1-0000-0000-0000-000000000003",
      "entityType": "VITAL",
      "payload": {
        "type": "BLOOD_PRESSURE",
        "values": { "systolic": 128, "diastolic": 82 },
        "measuredAt": "2026-07-16T08:10:00+03:00"
      }
    }
  ]
}
```

### Response

`200 OK`, `message: "Sync processed"`

```json
{
  "success": true,
  "data": {
    "results": [
      { "clientRecordId": "9f1c2b7e-0000-0000-0000-000000000001", "status": "SAVED",     "serverId": "a3f1b2c4-..." },
      { "clientRecordId": "2b7edc44-0000-0000-0000-000000000002", "status": "SAVED",     "serverId": "b7de1122-..." },
      { "clientRecordId": "44d0a3b1-0000-0000-0000-000000000003", "status": "DUPLICATE", "serverId": "c19a7788-..." },
      { "clientRecordId": "81aa5e02-0000-0000-0000-000000000004", "status": "REJECTED",  "reason": "durationMinutes is out of range" }
    ]
  },
  "message": "Sync processed",
  "timestamp": "2026-07-16T08:10:05Z"
}
```

`serverId` is present unless `REJECTED`; `reason` appears only on `REJECTED`. There are no summary
counts — the client derives them from the array.

### Statuses

| Status | Meaning | `serverId` | Client action |
|---|---|---|---|
| `SAVED` | New record committed | ✅ | Mark `SYNCED`, store `serverId` |
| `DUPLICATE` | Already stored under this `clientRecordId`, payload matches | ✅ | Mark `SYNCED`, store `serverId` |
| `CONFLICT` | Already stored, payload **differs** — the stored record wins; the incoming payload is never written | ✅ | Mark `SYNCED`; log it — a real conflict means a client bug reusing a UUID, not a merge situation |
| `REJECTED` | Payload invalid or unknown `entityType`; can never succeed | ✗ (`reason` instead) | Do **not** retry; surface to the user |

`SAVED`, `DUPLICATE`, and `CONFLICT` all mean the server now holds the record under that
`clientRecordId`, so the client marks all three `SYNCED`. The returned `serverId` is what lets a
later batch reference a medication by `medicationId` instead of `medicationClientRecordId`.

### Errors

| Code | Scope | Cause | Client action |
|---|---|---|---|
| `400` | Whole batch, nothing processed | `records` missing or empty; over 200 records; any record missing `clientRecordId`, `entityType`, or `payload` | Fix the envelope; for size, chunk into smaller batches |
| `401` | Whole batch | Missing/invalid token | Re-authenticate |
| `413` | Whole batch | Body over 2 MB | Chunk into smaller batches |
| `REJECTED` in a `200` | One record | Record content: unknown `entityType`, DTO validation failure, malformed payload, bad enum, or a `DOSE_LOG` whose medication reference doesn't resolve to an owned medication | Drop that record; **the rest of the batch still committed** |
| `500` | Whole batch | Transient — database unavailable or unexpected fault | Keep **every** record queued and retry the whole batch |

The `500`-vs-`REJECTED` split is the important one. `REJECTED` means "this record is bad, stop
retrying it". `500` means "nothing is wrong with your data, try again later" — treating it like
`REJECTED` would make a correct client silently discard unsynced health data. Retrying after a
`500` is safe: records that did commit come back `DUPLICATE`.

---

## Enum reference

| Enum | Values | Used by |
|---|---|---|
| `Role` | `PATIENT` | Auth (`CLINICIAN` is planned, not implemented) |
| `Frequency` | `ONCE_DAILY`, `BID`, `TID`, `CUSTOM` | Medications |
| `DoseStatus` | `TAKEN`, `MISSED`, `SKIPPED` | Dose logs |
| `VitalType` | `BLOOD_PRESSURE`, `GLUCOSE`, `HEART_RATE`, `WEIGHT`, `CHOLESTEROL` | Vitals |
| `Severity` | `NONE`, `MONITOR`, `URGENT`, `EMERGENCY` | Symptom assessment (ordered) |
| `ActivityType` | `WALKING`, `JOGGING`, `CYCLING`, `HOUSEHOLD`, `FARMING`, `STRETCHING`, `OTHER` | Activity |
| `Intensity` | `LIGHT`, `MODERATE`, `VIGOROUS` | Activity |
| `SyncStatus` | `SAVED`, `DUPLICATE`, `CONFLICT`, `REJECTED` | Sync results |

Enum values are sent and received as **strings**, exactly as spelled above (case-sensitive). An
unrecognized value is a `400` on the direct endpoints and a per-record `REJECTED` in sync.

---

## Endpoint index

| Method | Path | Auth | Feature |
|---|---|---|---|
| `POST` | `/api/v1/auth/register` | — | Auth |
| `POST` | `/api/v1/auth/login` | — | Auth |
| `GET` | `/api/v1/auth/me` | ✅ | Auth |
| `GET` | `/api/v1/patients/me` | ✅ | Profile |
| `PUT` | `/api/v1/patients/me` | ✅ | Profile |
| `POST` | `/api/v1/medications` | ✅ | Medications |
| `GET` | `/api/v1/medications` | ✅ | Medications |
| `PUT` | `/api/v1/medications/{id}` | ✅ | Medications |
| `DELETE` | `/api/v1/medications/{id}` | ✅ | Medications |
| `POST` | `/api/v1/medications/{medicationId}/doses` | ✅ | Dose logs |
| `GET` | `/api/v1/dose-logs` | ✅ | Dose logs |
| `POST` | `/api/v1/vitals` | ✅ | Vitals |
| `GET` | `/api/v1/vitals` | ✅ | Vitals |
| `POST` | `/api/v1/symptoms` | ✅ | Symptoms |
| `GET` | `/api/v1/symptoms` | ✅ | Symptoms |
| `POST` | `/api/v1/activities` | ✅ | Activity |
| `GET` | `/api/v1/activities` | ✅ | Activity |
| `POST` | `/api/v1/sync` | ✅ | Sync |

18 endpoints across 7 features. There is no `GET /medications/{id}`, no update or delete on any log
type (all append-only), and no pull direction on sync.
