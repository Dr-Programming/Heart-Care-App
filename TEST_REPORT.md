# Heart Care App — Test Report

**Date:** 2026-09-30  
**Tested by:** Claude Code (automated API + code analysis)  
**Scope:** Backend REST API (live), Mobile source code analysis  
**APK testing:** Pending — requires Android emulator run  
**Fix status updated:** 2026-10-01. Backend fixes are on branch `bugs`; see [BUGS_FIXED.md](BUGS_FIXED.md).

---

## Quick Summary

| # | Issue | Severity | Fix Side | Status |
|---|-------|----------|----------|--------|
| 1 | Vitals/symptoms show on wrong day (timezone bug) | High | Backend + Mobile | ✅ Backend fixed · 📱 mobile pending |
| 2 | Can log doses for deactivated medications | High | Backend | ✅ Fixed (2026-10-01) |
| 3 | Multiple symptom check-ins allowed on same day | High | Backend | ✅ Fixed (2026-10-01) |
| 4 | Duplicate dose logs created without unique ID | High | Backend | ✅ Fixed (2026-10-01) |
| 5 | No way to change PIN | High | Backend | ✅ Fixed (backend + mobile, works offline) |
| 6 | No token refresh — app will silently fail after token expires | High | Backend + Mobile | ✅ Backend fixed · 📱 mobile pending |
| 7 | Activity feature missing from mobile | Medium | Mobile | 📱 Open (mobile) |
| 8 | Future dates accepted for all health records | Medium | Backend | ✅ Fixed (2026-10-01) |
| 9 | No upper limit on medication dose (99,999 mg accepted) | Medium | Backend | ✅ Fixed (2026-10-01) |
| 10 | Schedule time count not enforced (BID med with 3 times accepted) | Medium | Backend | ✅ Fixed (2026-10-01) |
| 11 | Sync doesn't trigger on first reconnect after app start | Low | Mobile | 📱 Open (mobile) |
| 12 | Edited dose notes don't sync to server | Low | Mobile | 📱 Open (mobile) |
| 13 | Sign-out doesn't clear cached data from memory | Low | Mobile | 📱 Open (mobile) |

---

## Detailed Findings

---

### 1. Vitals / Symptoms Appear on Wrong Day (Timezone Bug)

**What's wrong:**  
The backend stores all records in UTC time. Ethiopian users are UTC+3. So a reading logged at 12:30 AM local time is stored as 9:30 PM the *previous* day in UTC. When the app queries "today's" data, it misses that record entirely.

**Example:** Log a vital at 12:30 AM on Sep 30 (Ethiopian time) → the backend thinks it was logged on Sep 29.

**Severity:** High — affects vitals, symptoms, and dose logs for night-time entries.

**What needs to change:**
- Backend: Accept a timezone offset from the client and use it when bucketing records by date
- Mobile: Send the user's timezone in each request (e.g. as a header or field)

**Files to change:**
- `backend/src/main/java/com/heartcare/vitals/VitalsService.java`
- `backend/src/main/java/com/heartcare/symptoms/SymptomsService.java`
- `backend/src/main/java/com/heartcare/medication/DoseLogService.java`
- `mobile/lib/core/network/dio_provider.dart` (add timezone header)

> **Fix status (2026-10-01): backend fixed, mobile pending.** The server reads the IANA zone from an `X-Timezone` header. Without it, the server uses `Africa/Addis_Ababa`. Day filters for vitals, symptoms and activities now use local midnight. The mobile app still needs to send the header; see [BUGS_FIXED.md](BUGS_FIXED.md#issue-1-records-appear-on-the-wrong-day).

---

### 2. Can Log Doses for Deactivated Medications

**What's wrong:**  
When a medication is marked inactive, the mobile app removes it from the dose schedule. But the backend still accepts dose log requests for it. If data syncs after a medication is deactivated, those dose records get saved incorrectly.

**Severity:** High — corrupts adherence history.

**What needs to change:**
- Backend: When a dose log is submitted, check that the medication is still active before saving.

**Files to change:**
- `backend/src/main/java/com/heartcare/medication/DoseLogService.java`

> **Fix status (2026-10-01): fixed.** The check depends on the date, as agreed: a new `deactivated_at` column (migration V12) is set when a medication is turned off. Doses scheduled *after* that day are rejected with 400 (`REJECTED` on sync). Doses on or before that day are still accepted, because the app works offline and they may sync late. See [BUGS_FIXED.md](BUGS_FIXED.md#issue-2-dose-logs-accepted-for-deactivated-medications).

---

### 3. Multiple Symptom Check-ins Allowed on Same Day

**What's wrong:**  
The app is designed for one symptom check-in per day. The mobile UI enforces this, but the backend doesn't. A direct API call (or a sync edge case) can create two check-in records for the same day, which breaks history charts and daily summaries.

**Confirmed:** Two check-ins on the same day were accepted and saved with different IDs.

**Severity:** High — corrupts symptom history.

**What needs to change:**
- Backend: Reject a second check-in if one already exists for the same patient on the same calendar date.

**Files to change:**
- `backend/src/main/java/com/heartcare/symptoms/SymptomsService.java`
- `backend/src/main/resources/db/migration/` (optional: add a UNIQUE constraint on patient + date)

> **Fix status (2026-10-01): fixed.** New `check_in_date` column (the patient's local date) with `UNIQUE (user_id, check_in_date)` (migration V13). Existing same-day duplicates are removed, keeping the latest. A second check-in returns `400 "A symptom check-in already exists for <date>"`, and `REJECTED` on sync. See [BUGS_FIXED.md](BUGS_FIXED.md#issue-3-several-symptom-check-ins-allowed-on-one-day).

---

### 4. Duplicate Dose Logs Created Without Unique ID

**What's wrong:**  
The sync queue uses a `clientRecordId` (a unique ID the app generates) to prevent duplicate records from being saved twice. But `clientRecordId` is optional — if it's missing, the backend creates a new record every time the same request is sent. This can happen during retry logic.

**Confirmed:** Two identical dose log requests (no clientRecordId) created two separate records.

**Severity:** High — inflates adherence numbers.

**What needs to change:**
- Backend: Make `clientRecordId` a required field for dose log submissions. Reject requests without it.

**Files to change:**
- `backend/src/main/java/com/heartcare/medication/dto/DoseLogRequest.java`
- `backend/src/main/java/com/heartcare/medication/DoseLogService.java`

> **Fix status (2026-10-01): fixed.** `clientRecordId` is now required. A request without it gets 400. See [BUGS_FIXED.md](BUGS_FIXED.md#issue-4-duplicate-dose-logs-when-clientrecordid-is-missing).

---

### 5. No Way to Change PIN

**What's wrong:**  
There is no API endpoint to change a user's PIN. If a user wants to update their PIN (for security or because they forgot it), there is no flow for it. The "Forgot PIN" screen exists in the mobile app but it needs a backend endpoint to work.

**Confirmed:** Tried `POST`, `PUT`, and `PATCH` on `/api/v1/auth/change-pin` — all returned 404.

**Severity:** High — basic account security feature is completely missing.

**What needs to change:**
- Backend: Add a `POST /api/v1/auth/change-pin` endpoint that verifies the old PIN and saves the new one.
- Mobile: Wire the existing `ForgotPinScreen` to call the new endpoint.

**Files to change:**
- `backend/src/main/java/com/heartcare/auth/AuthController.java` (new endpoint)
- `backend/src/main/java/com/heartcare/auth/AuthService.java` (logic)
- `mobile/lib/features/auth/presentation/screens/forgot_pin_screen.dart`

> **Fix status (2026-10-01): fixed in backend and mobile, and it works offline.** The app changes the PIN through `POST /api/v1/auth/pin-change`. Offline, the phone checks the PIN and queues the change, and the server checks it again at the next sync. The server wins conflicts. This was checked end to end on the emulator. See [BUGS_FIXED.md](BUGS_FIXED.md#offline-pin-change-and-forgot-pin). Also added: `POST /api/v1/auth/change-pin` `{currentPin, newPin}`.
> - Wrong current-PIN attempts count toward the login lockout. A wrong PIN returns 400; a locked account returns 423.
> - On success, all refresh tokens are cancelled and a new token pair is returned.
> - Changing the PIN needs an internet connection. On success the app must update its offline PIN cache.
> - **Forgot PIN (added 2026-10-01):** Forgot PIN uses security questions, with `POST /auth/recovery/questions` and `POST /auth/reset-pin`. It is built in backend and mobile and works offline on a phone where the questions are set up. See [BUGS_FIXED.md](BUGS_FIXED.md#new-feature-forgot-pin-security-questions).
>
> See [BUGS_FIXED.md](BUGS_FIXED.md#issue-5-change-pin).

---

### 6. No Token Refresh — App Silently Fails After Token Expires

**What's wrong:**  
JWT tokens expire after some time. When they do, every API call silently fails with a 401 error. The app has no logic to automatically get a new token — it just keeps failing. The user is never told to re-login.

**Severity:** High — app appears to work but all data sync stops.

**What needs to change:**
- Backend: Add a `POST /api/v1/auth/refresh` endpoint that takes a refresh token and returns a new access token.
- Mobile: Add a Dio interceptor that catches 401 responses and either refreshes the token automatically or navigates the user back to the login screen.

**Files to change:**
- `backend/src/main/java/com/heartcare/auth/AuthController.java`
- `backend/src/main/java/com/heartcare/auth/AuthService.java`
- `mobile/lib/core/network/dio_provider.dart` (401 interceptor)
- `mobile/lib/features/auth/data/datasources/auth_remote_datasource.dart`

> **Fix status (2026-10-01): backend fixed, mobile pending.** Added refresh tokens that are stored in the database (SHA-256 hash only) and replaced on every use.
> - New endpoints: `POST /api/v1/auth/refresh` and `POST /api/v1/auth/logout`.
> - Register, login and refresh now also return `refreshToken` and expiry times.
> - The access-token lifetime stays at 7 days until the mobile 401 interceptor is released.
>
> See [BUGS_FIXED.md](BUGS_FIXED.md#issue-6-token-refresh).

---

### 7. Activity Feature Missing from Mobile

**What's wrong:**  
The backend has a full activity logging API (`/api/v1/activities` — walk, jog, cycle, etc.). The mobile app has no activity screens at all. There is no `lib/features/activity/` folder.

**Severity:** Medium — feature gap; backend is ready but mobile was never built.

**What needs to change:**
- Mobile: Build the activity feature (list screen, log form, history).

**Files to add:**
- `mobile/lib/features/activity/` (entire feature folder)

---

### 8. Future Dates Accepted for All Health Records

**What's wrong:**  
Any health record (vitals, symptoms, activities, dose logs) can be submitted with a date far in the future. For example, a blood pressure reading dated year 2099 is accepted and saved.

**Severity:** Medium — data quality issue; doesn't crash anything but corrupts history.

**What needs to change:**
- Backend: Validate that `measuredAt` / `loggedAt` timestamps are not in the future (or no more than a few minutes ahead to allow for clock drift).

**Files to change:**
- `backend/src/main/java/com/heartcare/vitals/VitalsService.java`
- `backend/src/main/java/com/heartcare/symptoms/SymptomsService.java`
- `backend/src/main/java/com/heartcare/activity/ActivityService.java`
- `backend/src/main/java/com/heartcare/medication/DoseLogService.java`

> **Fix status (2026-10-01): fixed.** `measuredAt` and `loggedAt` more than 5 minutes ahead of the server clock are rejected; the 5 minutes allow for phone clock drift. A dose's `scheduledDate` can't be later than the client's today. Error: `400 "<field> must not be in the future"`. See [BUGS_FIXED.md](BUGS_FIXED.md#issue-8-future-dates-accepted).

---

### 9. No Upper Limit on Medication Dose

**What's wrong:**  
When adding a medication, there is no maximum dose validation. A dose of 99,999 mg was accepted without error. The minimum is enforced (must be positive) but there is no maximum.

**Severity:** Medium — a realistic typo (e.g. entering "500" as "5000") is silently accepted.

**What needs to change:**
- Backend: Add a reasonable `@Max` constraint on `doseMg` (e.g. max 10,000 mg as a safe upper bound).

**Files to change:**
- `backend/src/main/java/com/heartcare/medication/dto/MedicationRequest.java`

> **Fix status (2026-10-01): fixed.** `@DecimalMax("10000")` on `doseMg`.

---

### 10. Medication Schedule Times Not Validated Against Frequency

**What's wrong:**  
A `BID` (twice-daily) medication should have exactly 2 scheduled times. The backend accepts a BID medication with 3 schedule times without complaint. The same applies to other frequencies (QD, TID, QID).

**Severity:** Medium — incorrect schedules cause wrong dose reminders and incorrect adherence calculations.

**What needs to change:**
- Backend: Validate that `scheduleTimes.size()` matches the selected frequency (QD=1, BID=2, TID=3, QID=4).

**Files to change:**
- `backend/src/main/java/com/heartcare/medication/dto/MedicationRequest.java`
- `backend/src/main/java/com/heartcare/medication/MedicationService.java`

> **Fix status (2026-10-01): fixed.** The real enum values are `ONCE_DAILY` (exactly 1 time), `BID` (2), `TID` (3) and `CUSTOM` (0–12; 0 means as needed). `QD` and `QID` don't exist in the code. Repeated times are also rejected. The check applies to REST calls and sync.
>
> **Mobile note:** the medication form keeps extra times when the frequency is lowered, so it needs to trim them. See [BUGS_FIXED.md](BUGS_FIXED.md#issue-10-medication-form).

---

### 11. Sync Doesn't Fire on First Reconnect After App Start

**What's wrong:**  
The app watches for internet connectivity changes to trigger a sync. The watcher starts with `wasOnline = true`, so the first time the device goes offline then back online after launch, the "reconnected" event is missed and queued data doesn't sync.

**Severity:** Low — sync still fires on subsequent reconnects and on app relaunch.

**What needs to change:**
- Mobile: Initialize `wasOnline = false` so the first offline→online transition is always caught.

**Files to change:**
- `mobile/lib/core/sync/connectivity_watcher.dart` (or equivalent sync trigger file)

---

### 12. Edited Dose Notes Don't Sync to Server

**What's wrong:**  
When a user edits a note on a dose log, the local database is updated. But the sync queue uses `insertOrIgnore` — if a record with that `clientRecordId` is already in the queue, the update is silently ignored and the old version is sent to the server instead.

**Severity:** Low — affects only note edits, not core dose status.

**What needs to change:**
- Mobile: Change the sync queue from `insertOrIgnore` to `insertOrReplace` when updating existing records, or add a separate "update" queue operation.

**Files to change:**
- `mobile/lib/core/sync/sync_queue_dao.dart` (or equivalent)

---

### 13. Sign-Out Doesn't Clear Cached Data from Memory

**What's wrong:**  
When a user signs out, their auth token is cleared but the in-memory Riverpod providers (medications, vitals, symptoms) are not invalidated. If another user signs in on the same device, there is a brief window where the previous user's data may be visible before providers refresh.

**Severity:** Low — data is cleared once providers reload; no data is written to the wrong account.

**What needs to change:**
- Mobile: On sign-out, explicitly invalidate all feature providers so cached data is cleared immediately.

**Files to change:**
- `mobile/lib/features/auth/data/repositories/auth_repository_impl.dart` (sign-out method)
- `mobile/lib/features/auth/auth_providers.dart` (call `ref.invalidate` on feature providers)

---

## Additional Backend Fixes (from TEST_SUITE.md)

These were not in the issue list above but were failing in the suite. They were fixed on 2026-10-01:

| Test | Problem | Fix |
|------|---------|-----|
| T-VIT-08 | Weight of 0 kg accepted | Allowed weight range is now 1–500 kg |
| T-MED-08 | `GET /medications/{id}` returned 405 | Endpoint added; it only returns the caller's own medications |
| T-SEC-05 | No rate limit on registration | Per-IP limit: 10 per hour on `/auth/register` and 60 per minute on `/auth/refresh`, then 429 |

Left as is on purpose: T-HTTP-01 (201 vs 200; the mobile app may check for 200) and T-SYNC-03 (`clientRecordId` is unique within each table, so the same ID in different record types can't collide).

## What Was Ruled Out (Not Bugs)

These were investigated and confirmed to be working as designed:

| Item | Why it's not a bug |
|------|-------------------|
| Auth gate returns "open" gate by default | `featureOverrides()` in `app_wiring.dart` correctly wires the real auth gate at app startup |
| Adherence % seems low | The calculation is correct — `due` counts all scheduled non-skipped slots |
| CHD stage accepts free text | Intentional — no standard enum exists for this field |
| Birth year 2099 accepted | `@Max(value=2100)` is the explicit design limit |

---

## Notes for the Team

- **API testing was done against the live Docker backend.** All "Confirmed" findings were verified with real HTTP requests.
- **Mobile findings (11, 12, 13) are code analysis only** — they need to be verified by running the actual APK on an emulator.
- **Some UI-side issues may not be reachable through the mobile app** (e.g. the UI might already prevent future date entry in the date picker) — emulator testing will confirm.
- **Priority order for fixing:** Issues 1–6 are the most impactful for real users. Issues 7–10 are data quality. Issues 11–13 are edge-case polish.
- **2026-10-01:** All backend work from issues 1–6 and 8–10 is done. The remaining work is mobile: issues 7 and 11–13, and the mobile parts of 1, 5, 6 and 10. These are listed in the mobile follow-up section of [BUGS_FIXED.md](BUGS_FIXED.md#mobile-follow-up).
