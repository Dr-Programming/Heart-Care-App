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
