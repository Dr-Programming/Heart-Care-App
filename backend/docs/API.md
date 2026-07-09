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
