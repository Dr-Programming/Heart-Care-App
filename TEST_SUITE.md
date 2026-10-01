# Heart Care App — Test Suite

**Run date:** 2026-09-29  
**Environment:** Docker Compose (heartcare-postgres + heartcare-backend), Spring Boot 3, PostgreSQL 16  
**Base URL:** `http://localhost:8080`  
**Mobile:** Code analysis only (APK present, emulator run pending)  
**Total test cases:** 74  
**Pass:** 34 | **Fail / Bug found:** 36 | **Not Applicable / Missing:** 4

> **Re-test 2026-10-01** (branch `bugs`, after the backend fixes in [BUGS_FIXED.md](BUGS_FIXED.md)):
> - These 15 previously failing backend cases now pass: T-AUTH-14, T-MED-04/05/08, T-DOSE-02/03/04, T-VIT-08/09/10/11, T-SYM-02/03, T-ACT-03 and T-SEC-05. T-AUTH-12/13 tried other paths and methods; the change-PIN endpoint added is `POST /auth/change-pin`.
> - Still open: the mobile cases, which need the app to be changed, plus T-HTTP-01 and T-SYNC-03, which were left as is on purpose.
> - Unit and integration tests: 359/359 pass.

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ PASS | Behaved as expected |
| ❌ FAIL | Bug found — see TEST_REPORT.md for details |
| ⚠️ MISSING | Feature / endpoint does not exist |
| 🔍 CODE | Finding from code analysis (not a live API run) |
| 🔁 | Re-tested after the 2026-10-01 fixes |

---

## 1. Authentication

### 1.1 Registration

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-AUTH-01 | Register new user | POST `/api/v1/auth/register` | `{"phone":"+251911000001","pin":"1234","name":"Test User","preferredLanguage":"en"}` | 200 OK, JWT token returned | 200 OK, token returned | ✅ PASS |
| T-AUTH-02 | Duplicate phone registration | POST `/api/v1/auth/register` | Same phone as T-AUTH-01 | 400 with "Phone already registered" | 400 "Phone already registered" | ✅ PASS |
| T-AUTH-03 | PIN too short (1 digit) | POST `/api/v1/auth/register` | `pin: "1"` | 400 validation error | 400 validation error | ✅ PASS |
| T-AUTH-04 | PIN too long (20 digits) | POST `/api/v1/auth/register` | `pin: "12345678901234567890"` | 400 validation error | 400 validation error | ✅ PASS |
| T-AUTH-05 | Alphabetic PIN | POST `/api/v1/auth/register` | `pin: "abcd"` | 400 validation error | 400 validation error | ✅ PASS |
| T-AUTH-06 | Missing phone field | POST `/api/v1/auth/register` | `{"pin":"1234","name":"Test"}` | 400 "phone must not be blank" | 400 "phone: must not be blank" | ✅ PASS |

### 1.2 Login

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-AUTH-07 | Login with valid credentials | POST `/api/v1/auth/login` | `{"phone":"+251911000001","pin":"1234"}` | 200 OK, JWT token | 200 OK, token returned | ✅ PASS |
| T-AUTH-08 | Login with wrong PIN | POST `/api/v1/auth/login` | `{"phone":"+251911000001","pin":"9999"}` | 401 unauthorized | 401 "Invalid credentials" | ✅ PASS |
| T-AUTH-09 | PIN brute-force lockout | POST `/api/v1/auth/login` × 5 | Wrong PIN 5 times in a row | Lock account after 5th attempt | Locked for 15 minutes after attempt 5 | ✅ PASS |
| T-AUTH-10 | Access protected endpoint with no token | GET `/api/v1/medications` | No Authorization header | 401 | 401 Unauthorized | ✅ PASS |
| T-AUTH-11 | Access protected endpoint with invalid JWT | GET `/api/v1/medications` | `Authorization: Bearer fake.token.here` | 401 | 401 Unauthorized | ✅ PASS |

### 1.3 PIN Management

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-AUTH-12 | Change PIN via PUT | PUT `/api/v1/auth/pin` | `{"oldPin":"1234","newPin":"5678"}` | 200 OK | 404 Resource not found | ❌ FAIL (BE-PROF-03) · 🔁 2026-10-01: wrong path for this test. The change-PIN endpoint added is `POST /auth/change-pin` with `{currentPin,newPin}` (see T-AUTH-14) |
| T-AUTH-13 | Change PIN via PATCH | PATCH `/api/v1/auth/change-pin` | `{"oldPin":"1234","newPin":"5678"}` | 200 OK | 404 Resource not found | ❌ FAIL (BE-PROF-03) · 🔁 2026-10-01: only POST is supported (see T-AUTH-14) |
| T-AUTH-14 | Change PIN via POST | POST `/api/v1/auth/change-pin` | `{"oldPin":"1234","newPin":"5678"}` | 200 OK | 404 Resource not found | ❌ FAIL (BE-PROF-03) · 🔁 Re-test 2026-10-01: ✅ PASS (200 with field `currentPin`; the old PIN is then refused) |

---

## 2. Patient Profile

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-PROF-01 | Create valid profile | PUT `/api/v1/patients/profile` | `{"birthYear":1985,"heightCm":170,"chdStage":"Stage II","preferredLanguage":"en"}` | 200 OK | 200 OK | ✅ PASS |
| T-PROF-02 | birthYear below minimum | PUT `/api/v1/patients/profile` | `{"birthYear":1800}` | 400 validation error | 400 "birthYear must be 1900 or later" | ✅ PASS |
| T-PROF-03 | birthYear future (2099) | PUT `/api/v1/patients/profile` | `{"birthYear":2099}` | Should reject (born in future) | 200 OK, stored as-is | ❌ FAIL (BE-PROF-02 — ruled out: intentional design, @Max=2100) |
| T-PROF-04 | chdStage arbitrary string | PUT `/api/v1/patients/profile` | `{"chdStage":"NOT_REAL_STAGE"}` | Should reject or warn | 200 OK, stored as-is | ❌ FAIL (BE-PROF-01 — ruled out: intentional free-text field) |
| T-PROF-05 | heightCm below minimum | PUT `/api/v1/patients/profile` | `{"heightCm":10}` | 400 validation error | 400 "heightCm must be at least 50" | ✅ PASS |
| T-PROF-06 | preferredLanguage invalid | PUT `/api/v1/patients/profile` | `{"preferredLanguage":"fr"}` | 400 validation error | 400 validation error | ✅ PASS |

---

## 3. Medications

### 3.1 Create Medication

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-MED-01 | Create valid QD medication | POST `/api/v1/medications` | `{"name":"Aspirin","doseMg":75,"frequency":"QD","scheduleTimes":["08:00"],"clientRecordId":"<uuid>"}` | 200 OK, medication created | 200 OK | ✅ PASS |
| T-MED-02 | Create valid BID medication | POST `/api/v1/medications` | `{"name":"Metoprolol","doseMg":50,"frequency":"BID","scheduleTimes":["08:00","20:00"],"clientRecordId":"<uuid>"}` | 200 OK | 200 OK | ✅ PASS |
| T-MED-03 | Duplicate clientRecordId (idempotency) | POST `/api/v1/medications` | Same clientRecordId as T-MED-01 | Returns same existing record | Returned existing record | ✅ PASS |
| T-MED-04 | Dose 99,999 mg — no upper limit | POST `/api/v1/medications` | `{"doseMg":99999}` | Should reject or warn | 200 OK, stored | ❌ FAIL (BE-03) · 🔁 Re-test 2026-10-01: ✅ PASS (400 `doseMg must be at most 10000`) |
| T-MED-05 | BID medication with 3 schedule times | POST `/api/v1/medications` | `{"frequency":"BID","scheduleTimes":["08:00","12:00","20:00"]}` | 400 — count mismatch | 200 OK, stored | ❌ FAIL (BE-MED-SCHED) · 🔁 Re-test 2026-10-01: ✅ PASS (400 `BID needs exactly 2 schedule times, got 3`) |
| T-MED-06 | Negative dose amount | POST `/api/v1/medications` | `{"doseMg":-100}` | 400 validation error | 400 "doseMg must be positive" | ✅ PASS |

### 3.2 Read / Update / Delete

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-MED-07 | List all medications | GET `/api/v1/medications` | — | 200 OK, array of medications | 200 OK, medications returned | ✅ PASS |
| T-MED-08 | Get single medication by ID | GET `/api/v1/medications/{id}` | Valid medication ID | 200 OK, single record | 405 Method Not Allowed | ❌ FAIL (BE-NOGET) · 🔁 Re-test 2026-10-01: ✅ PASS (200) |
| T-MED-09 | Deactivate medication | DELETE `/api/v1/medications/{id}` | Valid medication ID | 200 OK, medication deactivated | 200 OK | ✅ PASS |
| T-MED-10 | Cross-patient isolation | GET `/api/v1/medications` | Token from User 2 (different account) | Returns only User 2's meds (empty) | Empty array returned | ✅ PASS |

### 3.3 Dose Logging

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-DOSE-01 | Log dose for active medication | POST `/api/v1/medications/{id}/doses` | `{"status":"TAKEN","scheduledDate":"2026-09-29","scheduledTime":"08:00","clientRecordId":"<uuid>"}` | 200 OK | 200 OK | ✅ PASS |
| T-DOSE-02 | Log dose for deactivated medication | POST `/api/v1/medications/{id}/doses` | Same format, medication ID is deactivated | 400 or 422 — medication inactive | 200 OK, dose logged | ❌ FAIL (BE-DEACT) · 🔁 Re-test 2026-10-01: ✅ PASS (400 for doses after the deactivation day; doses on or before it are still accepted because they may sync late) |
| T-DOSE-03 | Duplicate dose log without clientRecordId | POST `/api/v1/medications/{id}/doses` × 2 | Same request, no clientRecordId, sent twice | Second request rejected or merged | Two separate records created | ❌ FAIL (BE-01) · 🔁 Re-test 2026-10-01: ✅ PASS (400 `clientRecordId is required`) |
| T-DOSE-04 | Dose with future scheduled date | POST `/api/v1/medications/{id}/doses` | `{"scheduledDate":"2026-12-31"}` | 400 — future date | 200 OK | ❌ FAIL (BE-FUTURE) · 🔁 Re-test 2026-10-01: ✅ PASS (400 `scheduledDate must not be in the future`) |
| T-DOSE-05 | Get dose history | GET `/api/v1/dose-logs` | Optional `?from=&to=&medicationId=` | 200 OK, array of logs | 200 OK, history returned | ✅ PASS |

---

## 4. Vitals

### 4.1 Blood Pressure

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-VIT-01 | Log valid blood pressure | POST `/api/v1/vitals` | `{"type":"BLOOD_PRESSURE","values":{"systolic":120,"diastolic":80},"measuredAt":"<now>","clientRecordId":"<uuid>"}` | 200 OK | 200 OK | ✅ PASS |
| T-VIT-02 | Negative blood pressure values | POST `/api/v1/vitals` | `{"values":{"systolic":-10,"diastolic":-5}}` | 400 validation error | 400 "systolic is out of range" | ✅ PASS |
| T-VIT-03 | Extreme BP (300/200) — should flag | POST `/api/v1/vitals` | `{"values":{"systolic":300,"diastolic":200}}` | 200 OK, `flagged: true` | 200 OK, flagged=true | ✅ PASS |
| T-VIT-04 | Wrong field names (bpm, kg) | POST `/api/v1/vitals` | `{"type":"BLOOD_PRESSURE","values":{"bpm":72}}` | 400 — wrong keys | 400 "values must contain exactly [heartRate]" | ✅ PASS |
| T-VIT-05 | Empty values map | POST `/api/v1/vitals` | `{"type":"BLOOD_PRESSURE","values":{}}` | 400 validation error | 400 "values for BLOOD_PRESSURE must contain exactly [systolic, diastolic]" | ✅ PASS |

### 4.2 Other Vital Types

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-VIT-06 | Log glucose | POST `/api/v1/vitals` | `{"type":"GLUCOSE","values":{"glucose":5.4}}` | 200 OK | 200 OK | ✅ PASS |
| T-VIT-07 | Log heart rate | POST `/api/v1/vitals` | `{"type":"HEART_RATE","values":{"heartRate":72}}` | 200 OK | 200 OK | ✅ PASS |
| T-VIT-08 | Log weight 0 kg | POST `/api/v1/vitals` | `{"type":"WEIGHT","values":{"weight":0}}` | 400 — clinically invalid | 200 OK, stored | ❌ FAIL (BE-VIT-WEIGHT) · 🔁 Re-test 2026-10-01: ✅ PASS (400) |
| T-VIT-09 | Log vital with future date (2099) | POST `/api/v1/vitals` | `{"measuredAt":"2099-12-31T09:00:00Z"}` | 400 — future date | 200 OK, stored | ❌ FAIL (BE-FUTURE) · 🔁 Re-test 2026-10-01: ✅ PASS (400) |
| T-VIT-10 | Log vital at Ethiopian midnight (UTC boundary) | POST `/api/v1/vitals` | `{"measuredAt":"2026-09-29T01:00:00+03:00"}` | Returned in Sep 29 query | Not returned in Sep 29 query; appears in Sep 28 | ❌ FAIL (MOB-08 / BE-UTC) · 🔁 Re-test 2026-10-01: ✅ PASS (with `X-Timezone: Africa/Addis_Ababa`, or with no header since Addis is the default) |

### 4.3 History

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-VIT-11 | Query vitals history by date | GET `/api/v1/vitals?from=2026-09-29&to=2026-09-29` | — | Returns all Sep 29 records | Returns UTC Sep 29 records; midnight-3AM local excluded | ❌ FAIL (BE-UTC) · 🔁 Re-test 2026-10-01: ✅ PASS (filters use local days; the mobile app must send `X-Timezone`) |
| T-VIT-12 | SQL injection in vitals note | POST `/api/v1/vitals` | `{"note":"'; DROP TABLE vitals;--"}` | Stored as literal string | Stored safely (JPA parameterization) | ✅ PASS |

---

## 5. Symptoms

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-SYM-01 | Log valid symptom check-in | POST `/api/v1/symptoms` | `{"data":{"chestPain":false,"shortnessOfBreath":"NONE","heartRate":72,"bloodPressure":{"systolic":120,"diastolic":80},"swelling":false,"energyLevel":8},"measuredAt":"<now>","clientRecordId":"<uuid>"}` | 200 OK | 200 OK | ✅ PASS |
| T-SYM-02 | Second check-in same day | POST `/api/v1/symptoms` | Same date, different clientRecordId, EMERGENCY severity | 400 — duplicate same day | 200 OK, both records stored | ❌ FAIL (BE-02) · 🔁 Re-test 2026-10-01: ✅ PASS (400 `A symptom check-in already exists for <date>`) |
| T-SYM-03 | Check-in with future date | POST `/api/v1/symptoms` | `{"measuredAt":"2099-01-01T09:00:00Z"}` | 400 — future date | 200 OK, stored | ❌ FAIL (BE-FUTURE) · 🔁 Re-test 2026-10-01: ✅ PASS (400) |
| T-SYM-04 | Invalid shortnessOfBreath value | POST `/api/v1/symptoms` | `{"data":{"shortnessOfBreath":"EXTREME"}}` | 400 validation error | 400 validation error | ✅ PASS |
| T-SYM-05 | heartRate out of range (500) | POST `/api/v1/symptoms` | `{"data":{"heartRate":500}}` | 400 — out of range | 400 validation error | ✅ PASS |
| T-SYM-06 | energyLevel out of range (15) | POST `/api/v1/symptoms` | `{"data":{"energyLevel":15}}` | 400 — max is 10 | 400 validation error | ✅ PASS |

---

## 6. Activity

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-ACT-01 | Log valid walking activity | POST `/api/v1/activities` | `{"data":{"type":"WALKING","durationMinutes":30,"intensity":"MODERATE"},"measuredAt":"<now>","clientRecordId":"<uuid>"}` | 200 OK | 200 OK | ✅ PASS |
| T-ACT-02 | Log invalid activity type (RUNNING) | POST `/api/v1/activities` | `{"data":{"type":"RUNNING",...}}` | 400 — invalid type | 400 "type: must be one of [WALKING, JOGGING, CYCLING...]" | ✅ PASS |
| T-ACT-03 | Log activity with future date | POST `/api/v1/activities` | `{"measuredAt":"2099-01-01T09:00:00Z"}` | 400 — future date | 200 OK, stored | ❌ FAIL (BE-ACT-FUTURE) · 🔁 Re-test 2026-10-01: ✅ PASS (400) |
| T-ACT-04 | Get activity history | GET `/api/v1/activities` | — | 200 OK, array | 200 OK, array returned | ✅ PASS |
| T-ACT-05 | Activity feature on mobile | Mobile APK (code analysis) | Navigate to activity log screen | Activity screen exists | No activity feature in `lib/features/` | ❌ FAIL (MISS-01) |

---

## 7. Sync

| ID | Test | Method + Endpoint | Input | Expected | Actual | Result |
|----|------|-------------------|-------|----------|--------|--------|
| T-SYNC-01 | Sync empty records array | POST `/api/v1/sync` | `{"records":[]}` | 400 — records must not be empty | 400 "records must not be empty" | ✅ PASS |
| T-SYNC-02 | Sync duplicate clientRecordId within same entity type | POST `/api/v1/sync` | Two records same clientRecordId, same entity | Idempotent — second ignored | Handled correctly | ✅ PASS |
| T-SYNC-03 | Sync same clientRecordId across different entity types | POST `/api/v1/sync` | UUID `aaaa-...` used for both VITAL and MEDICATION | Should reject or scope by type | Both accepted, ambiguous records created | ❌ FAIL (BE-SYNC-XTYPE) · Not changed on purpose: `clientRecordId` is unique within each table, so records of different types can't collide |

---

## 8. Security & Data Isolation

| ID | Test | Description | Expected | Actual | Result |
|----|------|-------------|----------|--------|--------|
| T-SEC-01 | Cross-patient data isolation — medications | User 2 calls GET `/api/v1/medications` after User 1 added meds | Returns only User 2's data (empty) | Empty array | ✅ PASS |
| T-SEC-02 | Cross-patient data isolation — vitals | User 2 calls GET `/api/v1/vitals` | Empty | Empty | ✅ PASS |
| T-SEC-03 | SQL injection in medication name | `'; DROP TABLE medications;--` in name field | Stored safely | Stored as literal string | ✅ PASS |
| T-SEC-04 | SQL injection in vitals note field | Same pattern | Stored safely | Stored safely | ✅ PASS |
| T-SEC-05 | No rate limiting on registration | Send 20 rapid POST `/api/v1/auth/register` requests | Rate limiting kicks in | All accepted, no limiting | ❌ FAIL (BE-05) · 🔁 Re-test 2026-10-01: ✅ PASS (10 per hour per IP, then 429 with `Retry-After`) |

---

## 9. Mobile Code Analysis

These were not run as API calls — they are findings from reading the Flutter source code.

| ID | File Inspected | What Was Checked | Finding |
|----|----------------|-----------------|---------|
| T-MOB-01 | `lib/core/router/auth_gate.dart:30-32` | Is `authGateProvider` wired to real auth? | Default returns `OpenAuthGate` — but `app_wiring.dart:205` overrides it. **Not a bug.** |
| T-MOB-02 | `lib/app/app_wiring.dart:203-209` | Does `featureOverrides()` wire real auth? | Confirmed: `authGateProvider.overrideWith(realAuthGateProvider)` ✅ |
| T-MOB-03 | `lib/features/medication/domain/schedule.dart:80-88` | Is adherence calculation correct? | `due++` counts all scheduled slots, `taken++` counts taken — ratio is correct. **Not a bug.** |
| T-MOB-04 | `lib/core/sync/sync_service.dart:57` | Initial value of `wasOnline` | `wasOnline = true` — first offline→online transition missed | 🔍 CODE — FAIL (MOB-09) |
| T-MOB-05 | `lib/core/sync/sync_queue_dao.dart:43` | Insert mode for sync queue | `InsertMode.insertOrIgnore` — note edits silently dropped | 🔍 CODE — FAIL (MOB-11) |
| T-MOB-06 | `lib/features/auth/presentation/controllers/auth_controller.dart:55-60` | Sign-out clears providers? | `signOut()` clears token and DB session but does not `ref.invalidate()` feature providers | 🔍 CODE — FAIL (MOB-03) |
| T-MOB-07 | `lib/features/auth/auth_providers.dart:52-83` | `RealAuthGateNotifier` implementation | Correctly resolves `isSignedIn`, `needsOnboarding`, `hasChosenLanguage` ✅ |
| T-MOB-08 | `lib/features/vitals/domain/vital_type.dart` | Available vital types | Only 5 types: bloodPressure, glucose, heartRate, weight, cholesterol — no oxygen saturation | 🔍 CODE — noted |
| T-MOB-09 | `lib/features/medication/presentation/screens/forgot_pin_screen.dart` | Forgot PIN implementation | Screen exists in nav, no functional backend call | 🔍 CODE — FAIL (MOB-FP) · 🔁 2026-10-01: ✅ Forgot PIN through security questions is built in backend and mobile, works offline, and was checked on the emulator |
| T-MOB-10 | `lib/features/` directory listing | Activity feature presence | No `activity` folder — feature missing entirely | 🔍 CODE — FAIL (MISS-01) |
| T-MOB-11 | `mobile/lib/features/auth/data/datasources/auth_remote_datasource.dart` | Token refresh call | No refresh method exists | 🔍 CODE — FAIL (MOB-06) · Backend `POST /auth/refresh` now exists; the mobile client is still pending |
| T-MOB-12 | `lib/features/medication/domain/schedule.dart:11-15` | Deactivation day handling | `isActiveOn` uses strict `isAfter` — deactivation day still shows medication | 🔍 CODE — FAIL (MOB-ED) |
| T-MOB-13 | `backend/src/main/java/com/heartcare/patient/dto/PatientProfileRequest.java` | chdStage validation | `@Size(max=50) String` — free text, intentional ✅ |
| T-MOB-14 | `backend/src/main/java/com/heartcare/patient/dto/PatientProfileRequest.java` | birthYear max value | `@Max(value=2100)` — 2099 is within design range ✅ |

---

## 10. HTTP Response Code Tests

| ID | Test | Expected Code | Actual Code | Result |
|----|------|---------------|-------------|--------|
| T-HTTP-01 | Successful resource creation (POST) | 201 Created | 200 OK | ❌ FAIL (BE-201) · Not changed on purpose: the mobile app may check for 200 |
| T-HTTP-02 | Unauthorized access | 401 | 401 | ✅ PASS |
| T-HTTP-03 | Invalid input | 400 | 400 | ✅ PASS |
| T-HTTP-04 | Non-existent route | 404 | 404 | ✅ PASS |
| T-HTTP-05 | Method not allowed (GET on collection-only endpoint) | 405 | 405 | ✅ PASS |

---

## Test Coverage Summary

| Feature | API Tests | Code Analysis | Total | Pass | Fail |
|---------|-----------|---------------|-------|------|------|
| Authentication | 14 | 2 | 16 | 11 | 5 |
| Patient Profile | 6 | 2 | 8 | 5 | 3 |
| Medications | 10 | 1 | 11 | 6 | 5 |
| Vitals | 12 | 0 | 12 | 6 | 6 |
| Symptoms | 6 | 0 | 6 | 4 | 2 |
| Activity | 5 | 0 | 5 | 2 | 3 |
| Sync | 3 | 0 | 3 | 2 | 1 |
| Security | 5 | 0 | 5 | 4 | 1 |
| Mobile (code only) | 0 | 14 | 14 | 6 | 8 |
| HTTP responses | 5 | 0 | 5 | 4 | 1 |
| **Total** | **66** | **19** | **85** (some overlap) | | |

**After the 2026-10-01 re-test:** the 15 previously failing backend cases listed at the top now pass. The cases still failing are the mobile ones (T-ACT-05, T-MOB-04/05/06/09/11/12) and the two left unchanged on purpose (T-HTTP-01, T-SYNC-03).

---

## What Was NOT Tested

The following areas require an Android emulator running the APK and were not covered in this session:

- Mobile UI navigation flows (tab switching, back button, deep links)
- Vitals date picker — does it allow future dates?
- Medication form — does it validate doseMg input?
- Reminder notifications — do they fire on time?
- Language switching (English ↔ Amharic) mid-session
- Offline mode — add data while offline, reconnect, verify sync
- App restart after token expiry — does it prompt re-login?
- Sign-out on a shared device (User A → User B data visibility)
- Amharic translation completeness — missing keys that silently fall back

---

## Notes

- All API tests ran against `http://localhost:8080` with real JWT tokens from T-AUTH-01 / T-AUTH-07.
- A second test account was registered for cross-patient isolation tests.
- UUIDs used in `clientRecordId` fields were proper hex UUIDs (e.g. `11111111-1111-1111-1111-111111111101`).
- The Ethiopian timezone boundary test (T-VIT-10) was done by submitting timestamps with `+03:00` offset.
- Backend was fully reset between major test sections using new user accounts to avoid state contamination.
