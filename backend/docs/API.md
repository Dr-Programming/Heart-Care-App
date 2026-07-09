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
