# Heart Care App: Bugs Fixed

**Date:** 2026-10-01
**Branch:** `bugs`
**Source:** [TEST_REPORT.md](TEST_REPORT.md) and [TEST_SUITE.md](TEST_SUITE.md)
**Scope:** Backend fixes for report Issues 1–6 and 8–10, a new **Forgot PIN (security questions)** feature, plus the backend failures listed only in the suite: T-VIT-08 (zero weight accepted), T-MED-08 (no way to fetch one medication), T-SEC-05 (registration not rate-limited). Issues 1, 5 and 6 also need mobile changes. Those are described in [Mobile follow-up](#mobile-follow-up). No mobile code was changed.

---

## Summary

| # | Issue | Status | Test IDs |
|---|-------|--------|----------|
| 1 | Records appear on the wrong day (timezone) | ✅ Backend fixed · 📱 mobile must send `X-Timezone` | T-VIT-10, T-VIT-11 |
| 2 | Dose logs accepted for deactivated medications | ✅ Fixed | T-DOSE-02 |
| 3 | Several symptom check-ins allowed on one day | ✅ Fixed | T-SYM-02 |
| 4 | Duplicate dose logs when `clientRecordId` is missing | ✅ Fixed | T-DOSE-03 |
| 5 | No way to change the PIN | ✅ Fixed, backend and mobile; **works offline** | T-AUTH-12/13/14 |
| 6 | No token refresh | ✅ Backend fixed · 📱 mobile interceptor pending | T-MOB-11 |
| 8 | Future dates accepted on health records | ✅ Fixed | T-DOSE-04, T-VIT-09, T-SYM-03, T-ACT-03 |
| 9 | No maximum medication dose | ✅ Fixed | T-MED-04 |
| 10 | Number of schedule times not checked against frequency | ✅ Fixed | T-MED-05 |
| — | Weight of 0 kg accepted | ✅ Fixed | T-VIT-08 |
| — | `GET /medications/{id}` returned 405 | ✅ Fixed | T-MED-08 |
| — | No rate limit on registration | ✅ Fixed | T-SEC-05 |
| — | Forgot PIN: no way back in (new feature) | ✅ Done, backend and mobile; **works offline** | T-MOB-09 |

**Not fixed in this round:**
- Issues 7 and 11–13 need mobile code only.
- T-HTTP-01 (201 instead of 200) was left as is because the mobile app may check for 200.
- T-SYNC-03 (the same `clientRecordId` used by different record types) isn't a bug. Each table has its own uniqueness check, so the records don't collide.

### Verification
- **Backend test suite:** 392 of 392 tests pass. Each fix started from a test that failed before the change.
- **Mobile test suite:** 716 tests pass, including 77 new ones for offline PIN change, forgot PIN and security questions at sign-up. Three tests fail, all in the education/learn feature (`app_boot_test` learn routes and two `content_local_datasource_test` fixture tests). Those 3 already failed before any of this work and are not related to it. `flutter analyze` reports no new issues.
- **Live API:** the failing TEST_SUITE cases were re-run with curl against the Docker backend after a rebuild. All 31 checks passed (results below).
- **Database:** migrations V12–V16 applied cleanly to the existing Docker database. No duplicate symptom rows existed, so V13 deleted nothing.
- **Forgot PIN live check:** every case passed against Docker, from registering with answers through to the lock after 5 wrong attempts (results below).
- **On a real device:** on the Android emulator against the Docker backend, three scenarios worked end to end:
  1. Changing the PIN offline.
  2. A conflicting change made elsewhere, where the server wins.
  3. Forgot PIN offline.

  See [Offline PIN change](#offline-pin-change-and-forgot-pin).
- **Security:** `/security-review` on the bug fixes found no HIGH or MEDIUM vulnerabilities. Forgot PIN and offline PIN change were added afterwards and had a focused review. That review found one gap, now fixed: a retried change (same `changeId`) was accepted while the account was locked. The lock is now checked first, with a test for both `pin-change` and `reset-pin`.

---

## Breaking changes for API clients

| Change | Who is affected |
|--------|-----------------|
| Dose logs (`POST /medications/{id}/doses` and sync `DOSE_LOG`) now require `clientRecordId`. | Direct API callers only. The mobile app always sends one. |
| Medications must have the right number of schedule times for their frequency, with no repeated times. | The mobile form can currently produce a mismatch. See [Mobile follow-up](#mobile-follow-up). |
| Requests without `X-Timezone` now group dates by `Africa/Addis_Ababa` instead of UTC. | Any client that relied on UTC days. Send `X-Timezone: UTC` to keep the old behaviour. |
| `measuredAt`, `loggedAt` and `scheduledDate` can't be in the future. Timestamps may be up to 5 minutes ahead to allow for clock drift. | Direct API callers only. |
| A second symptom check-in on the same local day is rejected. | Direct API callers only. The mobile UI already allows one per day. |

---

## Fix details

### Issue 1: Records appear on the wrong day

**Root cause:** `VitalsService`, `SymptomsService` and `ActivityService` worked out day boundaries with `from.atStartOfDay(ZoneOffset.UTC)`. In Ethiopia (UTC+3), a reading taken at 01:00 on Sep 29 is stored as 22:00Z on Sep 28, so it showed up under Sep 28. The mobile app always sends timestamps in UTC, so the server had no way to know the user's local day.

**Fix:**
- New `ClientZone` component (`common/time/ClientZone.java`). It reads the IANA time zone from the **`X-Timezone`** request header, for example `Africa/Addis_Ababa`.
- If the header is missing or invalid, it uses `app.time.default-zone`, which defaults to `Africa/Addis_Ababa`. A bad header never causes an error, so older app builds keep working.
- History filters (`from` / `to`) for vitals, symptoms and activities now use local midnight in that zone.
- Dose history filters on `scheduledDate`, which is already a local date, so it didn't need this change.
- The header is read from the current request, so `/sync` gets the same behaviour without any change to the sync handlers.

**Files:** `common/time/ClientZone.java` (new); `vitals/VitalsService.java`; `symptoms/SymptomsService.java`; `activity/ActivityService.java`; `application.yml` (`app.time.*`).

### Issue 2: Dose logs accepted for deactivated medications

**Root cause:** `DoseLogService.log` checked that the medication belonged to the user but never checked whether it was still active.

**Fix:** the check depends on the date, because the app works offline. A dose taken on Monday can reach the server after the medication was turned off on Tuesday. That dose is real history and must still be saved.
- New column `medications.deactivated_at` (migration V12). For medications that were already inactive, it is filled from `updated_at`.
- `Medication.setActive` sets `deactivated_at` when a medication is turned off and clears it when it is turned back on. `DELETE /medications/{id}` turns a medication off.
- A dose is **rejected only if `scheduledDate` falls after the day the medication was deactivated** (in the client's time zone).
  - Error: `400 "Medication is inactive: it was deactivated before <date>"`
  - On sync, the record comes back as `REJECTED`.
- `MedicationResponse` now includes `deactivatedAt`. The field is left out while the medication is active.

**Files:** `V12__medication_deactivated_at.sql`; `medication/model/Medication.java`; `medication/DoseLogService.java`; `medication/dto/MedicationResponse.java`; `medication/MedicationService.java`.

### Issue 3: Several symptom check-ins allowed on one day

**Root cause:** the app allows one check-in per day, but the backend never enforced it.

**Fix:**
- New column `symptom_logs.check_in_date`: the patient's local date of `measuredAt`, worked out from `X-Timezone`. A database constraint, `UNIQUE (user_id, check_in_date)`, allows only one row per user per day.
- **Migration V13** fills `check_in_date` for existing rows using `Africa/Addis_Ababa`. Where a day already has more than one check-in, it **keeps the most recent and deletes the rest**, as agreed beforehand. This deleted 0 rows on the Docker database.
- `SymptomsService` checks before saving. If a check-in already exists for that day it returns `400 "A symptom check-in already exists for <date>"`.
- If two requests arrive at the same moment and both pass that check, the database constraint stops the second one, and it gets the same 400.
- **This is a 400, not a 409, on purpose.** `SyncService` only turns 400 and 404 errors into a per-record `REJECTED`. Any other error fails the whole sync batch with a 500, and the batch would fail again on every retry.
- Re-sending the same `clientRecordId` still returns the existing check-in, as before.

**Files:** `V13__symptom_check_in_date.sql`; `symptoms/model/SymptomLog.java`; `symptoms/SymptomsRepository.java`; `symptoms/SymptomsService.java`.

### Issue 4: Duplicate dose logs when `clientRecordId` is missing

**Root cause:** `DoseLogRequest.clientRecordId` was optional. Without it, retrying a request created a second record.

**Fix:** the field is now required (`@NotNull`). Missing it gives `400 "clientRecordId: clientRecordId is required"`. Sync always sends the record's own ID, so it isn't affected.

**Files:** `medication/dto/DoseLogRequest.java`; `medication/DoseLogService.java`.

### Issue 5: Change PIN

**New endpoint:** `POST /api/v1/auth/change-pin`. It needs a patient access token.

```json
{ "currentPin": "1234", "newPin": "5678" }
```

What it does:
1. **Checks the current PIN with the same lockout as login.** The lockout logic was moved into a shared method, `verifyPinCountingFailures`, used by both login and change PIN.
   - Wrong PINs count toward the same 5-try / 15-minute lock.
   - A locked account gets `423` without the PIN being checked.
   - This stops someone with a stolen access token from guessing the PIN through this endpoint.
2. Rejects a new PIN that is the same as the current one.
3. Saves the new PIN as a BCrypt hash.
4. **Signs out all refresh tokens** for that user.
5. Returns a new access token and refresh token to the device that made the change.

| Case | Response |
|------|----------|
| Success | `200` with new tokens |
| Wrong current PIN | `400 "Current PIN is incorrect"` |
| Account locked | `423` |
| New PIN same as current, or not 4 digits | `400` |
| No token, or an invalid one | `401` |

**A wrong current PIN returns 400, not 401, on purpose.** The access token is still valid. A 401 would make the app's token-refresh interceptor think the session had expired, so it would refresh and retry in a loop or sign the patient out.

**The app doesn't use this endpoint.** It uses `POST /auth/pin-change`, which works without a session, so a PIN changed offline can be sent later. See [Offline PIN change and forgot PIN](#offline-pin-change-and-forgot-pin). This authenticated endpoint is kept for other clients.

**Files:** `auth/AuthController.java`; `auth/AuthService.java`; `auth/dto/ChangePinRequest.java` (new); `auth/model/User.java`.

### Issue 6: Token refresh

**Root cause:** access tokens lasted 7 days and there was no way to renew one. After that, every request failed with 401.

**Fix:** refresh tokens are now stored in the database, and each one can be used only once (migration V14, `auth/RefreshTokenService.java`).
- A refresh token is 256 random bits. **Only its SHA-256 hash is stored.**
- **Each use replaces it.** The token sent in is cancelled and a new one is returned. The database row is locked during this, so two requests using the same token at the same time can't both get a new one.
- **Reuse is treated as theft.** All refresh tokens that come from the same sign-in share a family ID. If a token that was already used is sent again, the whole family is cancelled and the patient has to sign in again.
- Lifetime: `app.jwt.refresh-expiration-ms`, 60 days.
- The access-token lifetime stays at 7 days for now (`JWT_EXPIRATION_MS`), so the current app keeps working. **Lower it to about 1 hour once the mobile interceptor is released.**

New endpoints. Both work without being signed in, because the refresh token is the credential.

| Endpoint | Body | Response |
|----------|------|----------|
| `POST /api/v1/auth/refresh` | `{ "refreshToken": "..." }` | `200` with a new token pair. `401` if the token is unknown, expired, already used or cancelled. |
| `POST /api/v1/auth/logout` | `{ "refreshToken": "..." }` | Always `200`. Cancels that token's whole family. |

Register, login, refresh and change PIN now all return:

```json
{
  "token": "<access JWT>",
  "user": { ... },
  "refreshToken": "<opaque>",
  "accessTokenExpiresAt": "2026-10-08T04:49:00Z",
  "refreshTokenExpiresAt": "2026-11-30T04:49:00Z"
}
```

`token` keeps its old name, so current app builds still work. They simply ignore the new fields.

**Files:** `V14__refresh_tokens.sql`; `auth/model/RefreshToken.java`, `auth/RefreshTokenRepository.java`, `auth/RefreshTokenService.java`, `auth/dto/RefreshRequest.java` (all new); `auth/dto/AuthResponse.java`; `auth/AuthService.java`; `auth/AuthController.java`; `common/config/SecurityConfig.java`; `common/security/JwtTokenProvider.java`; `application.yml`.

### Issue 8: Future dates accepted

**Fix:**
- `measuredAt` (vitals, symptoms, activities) and `loggedAt` (dose logs) are rejected if they are more than 5 minutes ahead of the server clock. The 5 minutes (`app.time.max-future-skew-seconds`) allow for phone clocks that run fast.
- A dose's `scheduledDate` can't be later than today in the client's time zone.
- Error: `400 "<field> must not be in the future"`.
- The checks are in the services, so both REST calls and sync get them.

**Files:** `common/time/ClientZone.java`; `vitals/VitalsService.java`; `symptoms/SymptomsService.java`; `activity/ActivityService.java`; `medication/DoseLogService.java`.

### Issue 9: No maximum dose

**Fix:** `@DecimalMax("10000")` on `MedicationRequest.doseMg`. Error: `400 "doseMg: doseMg must be at most 10000"`.

### Issue 10: Schedule times not checked against frequency

**Fix:** the `Frequency` enum now defines how many times each frequency allows. The real enum values are listed below; the report's `QD` and `QID` don't exist in the code.

| Frequency | Schedule times allowed |
|-----------|------------------------|
| `ONCE_DAILY` | exactly 1 |
| `BID` | exactly 2 |
| `TID` | exactly 3 |
| `CUSTOM` | 0 to 12. 0 means "as needed", which the mobile form uses. |

- A new check on the request, `@ScheduleMatchesFrequency`, enforces these counts and also rejects repeated times.
- It runs for both REST calls (`@Valid`) and sync (`SyncPayloadMapper`).
- Error: `400 "scheduleTimes: BID needs exactly 2 schedule times, got 3"`.

**Files:** `medication/model/Frequency.java`; `medication/dto/MedicationRequest.java`; `medication/dto/ScheduleMatchesFrequency.java` and `ScheduleMatchesFrequencyValidator.java` (new).

### T-VIT-08: Weight of 0 kg accepted

**Fix:** the allowed weight range in `VitalsService` is now 1–500 kg instead of 0–500.

### T-MED-08: Fetching one medication

**Fix:** new endpoint `GET /api/v1/medications/{id}`. It only returns the caller's own medications; anyone else's gives 404.

### T-SEC-05: Registration not rate-limited

**Fix:** new `RateLimitFilter`, which runs inside the Spring Security filter chain, and `FixedWindowRateLimiter`. Counts are kept in memory per client IP.

| Endpoint | Default limit (`app.rate-limit.*`) |
|----------|------------------------------------|
| `POST /auth/register` | 10 per hour |
| `POST /auth/refresh` | 60 per minute |

- Over the limit, the response is `429 "Too many requests. Try again later."` with a `Retry-After` header.
- Login isn't on this list because it already has the per-account PIN lockout.
- The filter uses the connection's own IP address (`getRemoteAddr()`). It never trusts `X-Forwarded-For`, because a client can fake that header.
- **If the backend is deployed behind a reverse proxy**, set `server.forward-headers-strategy=native`. Otherwise every request looks like it comes from the proxy and all clients share one limit.
- The counts are kept separately on each server instance and reset when the server restarts.

---

## New feature: Forgot PIN (security questions)

**Problem:** a patient who forgot their PIN had no way back in. The Forgot PIN screen only said "contact your clinic" (T-MOB-09), and the clinic had no tool for it.

**Chosen approach:** the patient picks 3 security questions from a fixed list and answers them. Forgot PIN asks those questions again; if all answers are right, the patient sets a new PIN. The app can check the answers offline, but **the server checks them again** before it accepts the new PIN.

**Trade-off:** we considered SMS codes and clinic-issued reset codes. Security questions were chosen because they need no SMS provider and no staff time, and they work offline. The downside is that they are the weakest of the three, since close family may know or guess the answers. The rules below limit that risk.

### Rules
- **Question list:** 8 fixed IDs (`SecurityQuestion` enum). The text for each, in English and Amharic, lives in the app. Questions that family members would easily know, such as mother's name or birthplace, are left out on purpose.
- **Exactly 3 answers, to 3 different questions.** Each answer is 2–100 characters after normalising.
- **Normalising:** trim, collapse spaces, lowercase, so capitals and extra spaces don't cause a mismatch. There is no Unicode NFKC step: the phone checks answers offline with the same rules and has no NFKC implementation, so the server must not use it either.
- **Storage:** answers are stored only as **BCrypt hashes** (`user_security_answers`, migration V15). They are never returned by any endpoint.
- **Changing answers:** answers can be changed with `PUT /auth/security-answers`, which needs the current PIN. They aren't permanent, so an answer that leaks can be replaced.
- **Lockout:** recovery has its **own lockout**: 5 wrong attempts lock recovery for 60 minutes. It is separate from the PIN lockout, because a patient who forgot the PIN has often just locked it. A successful recovery clears both locks.
- **Hiding which numbers are registered:**
  - An unknown phone gets the same 400 as wrong answers, after the same BCrypt work, so response time gives nothing away.
  - `recovery/questions` returns 3 stable **decoy** questions for unknown numbers, so it can't be used to check whether a number is registered.
  - The decoys are picked using a key derived from the JWT secret, so no new secret needs configuring.
- **Success:** the new PIN is saved, every other session is signed out (all refresh tokens cancelled), and a new token pair is returned.
- **Rate limits:** per IP, 10 per hour on `reset-pin` and 30 per hour on `recovery/questions`.

### Endpoints

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `GET /auth/security-questions` | public | List of question IDs |
| `POST /auth/register` + `securityAnswers` | public | Set answers at sign-up. Optional, so older app builds keep working. |
| `GET /auth/security-answers` | patient | Whether answers are set, and which questions. Never the answers. |
| `PUT /auth/security-answers` `{currentPin, answers}` | patient | Set or replace the answers |
| `POST /auth/recovery/questions` `{phone}` | public | The 3 questions to ask for this phone |
| `POST /auth/reset-pin` `{phone, answers, newPin}` | public | Check the answers and set the new PIN |

| Reset result | Response |
|--------------|----------|
| All 3 right | `200` with a new token pair |
| Any wrong, wrong questions, unknown phone, or no answers set | `400 "The answers don't match"`, the same in every case |
| 5th wrong attempt, or already locked | `423 "Too many failed attempts. Try again in 60 minutes."` |
| Too many from one IP | `429` |

**Files:**
- New: `auth/PinRecoveryService.java`, `auth/SecurityAnswerService.java`, `auth/SecurityAnswerNormalizer.java`, `auth/SecurityAnswerRepository.java`, `auth/model/SecurityQuestion.java`, `auth/model/SecurityAnswer.java`, `auth/dto/{SecurityAnswerInput, SetSecurityAnswersRequest, RecoveryQuestionsRequest, ResetPinRequest, SecurityQuestionsResponse}.java`, `V15__security_answers.sql`
- Changed: `auth/AuthController.java`, `auth/AuthService.java`, `auth/UserRepository.java`, `auth/model/User.java`, `auth/dto/RegisterRequest.java`, `common/config/SecurityConfig.java`, `common/security/RateLimitFilter.java`, `application.yml`

**Tests:** `PinRecoveryIntegrationTest` (15) and `SecurityAnswerNormalizerTest` (6), plus a rate-limit case in `RateLimitIntegrationTest`.

---

## Offline PIN change and forgot PIN

**Goal:** a patient can change their PIN, or reset a forgotten one with their security questions, **without internet**. The change works on the phone at once and reaches the server when the phone is back online.

### The rule
This is the same rule the app already uses for sign-in:
- **Online:** the server decides.
- **Offline:** the phone checks the current PIN, or the answers, itself (with the same lockouts as the server), applies the change locally, and queues it.

**The server wins conflicts.** A queued change is applied only if the server still accepts its proof: the old PIN, or the answers. If the PIN was changed elsewhere first, the queued change is dropped and the patient is asked to sign in with their current PIN.

### Backend
- **`POST /api/v1/auth/pin-change`** (public) `{phone, currentPin, newPin, changeId}`.
  - It proves itself with the current PIN instead of a session, because a queued change may sync after the phone's tokens expired or were cancelled.
  - It follows login's rules: the same lockout, the same `401 "Invalid phone or PIN"` for a wrong PIN or an unknown phone, and the same BCrypt work.
  - On success it returns a new session and cancels other sessions.
- **`changeId` (UUID) makes retries safe.**
  - It is required on `pin-change` and optional on `reset-pin`.
  - The server stores the last applied change ID (`users.last_pin_change_id`, migration V16).
  - **The problem it solves:** if the connection drops after the server applied a change, the phone retries with the old PIN, which no longer matches.
  - **How it's handled:** when the retry has the same ID and the new PIN matches, the server answers 200 again. It doesn't count a failure and doesn't cancel tokens again. An ID without the right new PIN is worth nothing.
  - **Locks still apply:** while the account (or recovery) is locked, even a correct retry gets 423.
- **Answers are compared the same way on phone and server.** NFKC was removed from `SecurityAnswerNormalizer` (see above).
- **Tests:** `PinChangeIntegrationTest` has 8 cases: success, replay, replay with a different PIN, stale change refused, lockout, unknown phone, missing `changeId`, and same PIN. `PinRecoveryIntegrationTest` adds a replay case for `reset-pin`.

### Mobile
| Piece | File | What it does |
|-------|------|--------------|
| Pending change | `auth/data/datasources/pending_pin_change_store.dart` | One queued change in secure storage: `{changeId, phone, kind: change\|reset, currentPin? \| answers?, newPin}`. A second offline change keeps the first change's proof (the PIN the server still has) and moves `newPin` forward. |
| Offline store | `auth/data/datasources/offline_credential_store.dart` | Now also keeps PBKDF2 hashes of the security answers (never the answers), with a recovery lockout of 5 tries / 60 minutes that matches the server. `changePin()` replaces the local PIN hash, and `remember()` keeps the answers when the same user signs in again. |
| Repository | `auth/data/repositories/auth_repository_impl.dart`, interface `auth/domain/repositories/pin_repository.dart` | `changePin`, `resetPin`, `recoveryQuestions`, `setSecurityAnswers`, `flushPendingPinChange`. |
| Sync hook | `refreshSession()`, which runs at the start of every sync, and `login()` | The queued change is sent **first**. Before this, `refreshSession` signed in with the new local PIN, got 401 from the server (which still had the old one), and wiped the phone's credentials. |
| Answer rules | `auth/domain/answer_normalizer.dart`, `auth/domain/security_question.dart` | Same rules as the server, and the 8 question IDs. |
| Screens | `change_pin_screen.dart`, `forgot_pin_screen.dart` (rewritten), `security_questions_screen.dart` | Settings → **Change PIN** and **Security questions** (which shows "Set" or "Not set"). Login → **Forgot PIN?**. The login screen shows "Your PIN was changed on another device…" after a conflict. |
| Translations | `en.json`, `am.json` | New `auth.changePin.*`, `auth.forgotPin.*`, `auth.securityQuestions.*` (including all 8 questions), `auth.errors.pinChangedElsewhere` and `profile.settings.{changePin,securityQuestions}`. **The Amharic text is a draft and needs a native speaker to review it.** |

**What happens to a queued change when it is sent:**

| Server answer | App behaviour |
|---------------|---------------|
| 200 | Session stored, queued change cleared. |
| 401 (change) or 400 (reset) | **Conflict:** the change is dropped, the patient is signed out, and the login screen explains why. |
| 423, offline, or 5xx | The change is kept and retried at the next sync. The patient stays signed in on this phone. |

### Verified on the Android emulator (Docker backend)

| Scenario | Result |
|----------|--------|
| Sign in online (PIN 1234), turn on airplane mode, Settings → Change PIN to 5678 | "PIN changed on this phone…". The server still accepts only 1234. |
| Sign out, sign in **offline** with 1234 / 5678 | 1234 refused, 5678 signs in |
| Turn off airplane mode | About 5 seconds later the server accepts 5678 and refuses 1234. The patient stays signed in. |
| Offline change to 2468 while another device changes the PIN to 1111, then reconnect | The app signs out and shows "Your PIN was changed on another device…". The server keeps 1111 and refuses 2468. |
| Set security questions online, go offline, sign out, Forgot PIN with answers typed in different case, new PIN 3579 | Signed in offline. The server refuses 3579 until reconnect, then accepts it and refuses the old PIN. |

### Security questions at sign-up
**Problem:** creating an account didn't ask for security questions, so a new patient couldn't reset a forgotten PIN until they found Settings → Security questions.

**Fix (mobile only):**
- **Sign-up now has two steps:**
  - **Step 1:** phone, PIN, name, language, then **Next**.
  - **Step 2:** choose and answer 3 different questions, then **Create account**.
  - **Back** returns to step 1 with everything kept.
- **Required.** The account can't be created until the 3 answers pass the usual rules (3 different questions, 2–100 characters each).
- **One request.** A single register request carries the answers (`securityAnswers`).
- **Offline reset from day one.** The phone also keeps hashes of the answers, so a new account can reset its PIN offline straight away.
- **Shared widget.** The question pickers are now one widget (`security_questions_fields.dart`), used by both sign-up and Settings, so both apply the same rules.

**Existing accounts without questions** get a one-time card at the top of Home: **"Set up security questions"**, with **Set up** and **Later**.
- It is shown only when the server confirms none are set. Offline, the status is unknown and the card stays hidden.
- **Later** hides it for good; that choice is stored in preferences. Settings keeps showing "Not set".

**Checked on the emulator:**
- **Step 2:** appears, and Create account is blocked while the answers are empty.
- **Changing a question:** picking a different question with the dropdown worked; the server stored `FIRST_SCHOOL`, `FAVORITE_TEACHER`, `FIRST_PHONE_BRAND`.
- **The new account:**
  - no prompt on Home
  - Settings shows "Set"
  - an offline forgot-PIN reset worked straight after sign-up, and the server took the new PIN after reconnecting
- **An account made without answers:** the prompt appears; **Later** hides it, and it stays hidden after the app is restarted.

**Tests:** 13 new or updated mobile tests. They cover the sign-up steps, sending and storing the answers, the status check, and the prompt.

---

## Mobile follow-up

The backend can't fix these on its own. The backend changes above are designed so the current app keeps working until these are done.

### Issue 1: Send the time zone (`mobile/lib/core/network/dio_provider.dart`)
- Add an `X-Timezone` header to **every** request, including `/sync`, with the device's IANA time zone. For example, use the `flutter_timezone` package and call `await FlutterTimezone.getLocalTimezone()`, which returns something like `"Africa/Addis_Ababa"`.
- Read it once when the app starts and again when the app returns to the foreground, in case the user changes time zone while travelling.
- Without the header, the server uses Ethiopia's time zone. That is right for most users but wrong for anyone travelling.

### Issue 6: Token refresh
- **Store** `refreshToken` in `flutter_secure_storage`, next to the access token, every time a register, login, refresh or change-PIN call succeeds.
- **Add a 401 interceptor**, a `QueuedInterceptor`, so that only one refresh runs at a time:
  1. When a request gets a 401 (other than from `/auth/login` or `/auth/refresh`), call `POST /auth/refresh` **using a separate Dio instance that doesn't have the auth interceptor**.
  2. Save the new pair and retry the original request **once**.
  3. If refresh returns 401, clear the session and send the user to the login screen.
- **Only one refresh at a time matters.** Each refresh token works once. If two requests refresh in parallel with the same token, the server treats the second as theft and signs the user out.
- **Signing out:** call `POST /auth/logout` with the refresh token, then clear the local tokens. If the call fails because the device is offline, ignore the error.
- **Add a `refresh()` method** to `auth_remote_datasource.dart`.
- **After this is released**, lower the access-token lifetime on the server (`JWT_EXPIRATION_MS=3600000`).

### Issue 5 and Forgot PIN
Done. See [Offline PIN change and forgot PIN](#offline-pin-change-and-forgot-pin) and [Security questions at sign-up](#security-questions-at-sign-up). Still open:
- **Get the Amharic text reviewed** for the new screens and questions.

### Issue 10: Medication form
- `setFrequency` in `medication_form_controller.dart` only ever *adds* times. Changing TID to BID keeps 3 times, and the server now rejects that.
- Fix: when the frequency changes, trim the list to the new count.
- Also check the count before saving, so the user sees the error in the form instead of the sync silently returning `REJECTED`.

### Sync: show rejected records
The following can now come back from `/sync` as `REJECTED` with a reason:
- a second check-in on the same day
- a dose for a medication that was deactivated before that date
- future dates
- a schedule that doesn't match the frequency

The app should show these to the user, or at least log them, rather than silently dropping them.

---

## Database migrations

| Version | Change | Effect on existing data |
|---------|--------|-------------------------|
| V12 | `medications.deactivated_at` | Filled from `updated_at` for medications that are already inactive |
| V13 | `symptom_logs.check_in_date` + `UNIQUE (user_id, check_in_date)` | Filled using Addis Ababa time. **Same-day duplicates are deleted, keeping the latest.** |
| V14 | New `refresh_tokens` table | None |
| V15 | New `user_security_answers` table; `users.recovery_failed_attempts`, `users.recovery_locked_until` | None. Existing users have no answers until they set them. |
| V16 | `users.last_pin_change_id` | None |

## Configuration added (`application.yml`)

| Key | Default |
|-----|---------|
| `app.jwt.expiration-ms` | `${JWT_EXPIRATION_MS:604800000}` (7 days; lower to 1 hour later) |
| `app.jwt.refresh-expiration-ms` | `${JWT_REFRESH_EXPIRATION_MS:5184000000}` (60 days) |
| `app.time.default-zone` | `${APP_DEFAULT_ZONE:Africa/Addis_Ababa}` |
| `app.time.max-future-skew-seconds` | `300` |
| `app.rate-limit.register.max-requests` / `window-seconds` | `10` / `3600` |
| `app.rate-limit.refresh.max-requests` / `window-seconds` | `60` / `60` |
| `app.rate-limit.reset-pin.max-requests` / `window-seconds` | `10` / `3600` |
| `app.rate-limit.recovery-questions.max-requests` / `window-seconds` | `30` / `3600` |
| `app.auth.recovery.max-attempts` / `duration-minutes` | `5` / `60` |

## Known limitations
- **Old access tokens after a PIN change.** Access tokens issued before the change keep working until they expire, which is up to 7 days at today's setting. Access tokens (JWTs) can't be cancelled early; this was already true before these changes. The gap shrinks to 1 hour once the access-token lifetime is lowered.
- **Security questions are a weak factor.** Close family may know or guess the answers. The lockout, rate limits and the choice of questions reduce this risk but don't remove it.
- **Offline changes only affect this phone until it syncs.** A PIN changed or reset offline works on that phone straight away. The server, and every other phone, keep the old PIN until this phone reconnects. Other phones also keep the old PIN cached for offline sign-in until they next sign in online.
- **The proof for a queued change is stored on the phone.** A queued change keeps the old PIN, or the security answers, encrypted in secure storage (Android Keystore) until the server accepts it, and then deletes it.
- **Offline forgot PIN needs answers on this phone.** It only works on a phone where the security questions were set up, or used online, before. Elsewhere it needs a connection.
- **Required only in the app.** The server keeps `securityAnswers` optional on register, so app builds that are already installed keep working. The current app always sends them.
- **Recovery lockout shows the account exists.** A `423` from `reset-pin` confirms the account exists, the same as login's `423`.
- **Rate limits per server.** The rate-limit counts are kept separately on each server and reset on restart. That's fine for one instance; several instances would need a shared store such as Redis.

## Changes to existing tests
Some existing tests used data that is now correctly rejected. They were updated:
- BID medications with only one schedule time.
- Dose logs without a `clientRecordId`.
- Two check-ins on the same day in the admin test.
- Day-filter tests that assumed UTC days. They now send `X-Timezone: UTC`.
- `RequestErrorMappingTest` used the formerly missing `GET /medications/{id}` as its example of a 405. It now uses `PATCH` instead.

## Live re-test results (Docker, 2026-10-01)

| Test | Before | After |
|------|--------|-------|
| T-AUTH-14 change PIN | 404 | 200. The old PIN gets 401, the new PIN 200, and the old refresh token 401. |
| Refresh / reuse / logout | — | 200 / 401 for a reused token and its whole family / 200, after which the token gets 401 |
| T-MED-04 dose 99999 | 200 | 400 |
| T-MED-05 BID with 3 times | 200 | 400 `BID needs exactly 2 schedule times, got 3` |
| T-MED-08 GET by id | 405 | 200 |
| T-DOSE-02 dose after deactivation | 200 | 400. A dose on the deactivation day itself is still accepted. |
| T-DOSE-03 no clientRecordId | 200 (duplicates) | 400 |
| T-DOSE-04 future scheduledDate | 200 | 400 |
| T-VIT-08 weight 0 | 200 | 400 |
| T-VIT-09 future measuredAt | 200 | 400 |
| T-VIT-10/11 Addis 01:00 reading | under Sep 28 | under Sep 29 (with `X-Timezone`) |
| T-SYM-02 second check-in same day | 200 | 400 |
| T-SYM-03 / T-ACT-03 future | 200 | 400 |
| T-SEC-05 registration flood | all 200 | 10 allowed per hour, then 429 |
| Forgot PIN: register with answers, `recovery/questions` | — | 200; returns the patient's 3 questions |
| Forgot PIN: unknown phone | — | The same 3 decoy questions on every request; `reset-pin` gives the same 400 as wrong answers |
| Forgot PIN: correct answers typed with different case and spacing | — | 200. The old PIN gets 401 and the new PIN 200. |
| Forgot PIN: 5 wrong attempts | — | 400 ×4, then 423. Correct answers are refused while locked. |
| Forgot PIN: storage | — | `user_security_answers` holds only BCrypt hashes (`$2a$10$…`) |
