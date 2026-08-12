# Design — Phone+PIN Auth & Mobile Foundation

**Date:** 2026-08-02
**Branch:** `feature/phone-pin-auth`
**Status:** Approved for planning
**Slice:** First mobile slice — backend auth rework **+** Flutter Foundation & Auth (delivered together as one vertical).

---

## 1. Context & goal

The backend's seven slices are merged and the API runs locally. `mobile/` is greenfield (no Flutter source). This slice stands up the Flutter app's foundation and its first vertical feature — authentication — proving the whole stack end-to-end against the running API.

A polished 10-screen Figma design exists (file `B2D41kike6v4YRjHQMlszS`, brand **"Libu Care"**). During design review we found the Figma auth model (**phone + 4-digit PIN**) does not match the backend (**email + password**). Decision: **change the backend to phone + PIN** — it is the correct UX for the target users (low digital literacy, Ethiopian mobile-first). That reopens the "done" backend, so this slice has two coupled halves.

**Execution approach:** contract-first, **backend then frontend** (single developer → sequential is cleanest and keeps integration risk near zero). The frontend is built against the *real*, already-tested endpoints.

### Constraints (from project docs/memory)
- Offline-first (intermittent Ethiopian connectivity); device is source of truth.
- Bilingual EN / አማርኛ (Amharic).
- Patient-only MVP (clinician role dropped).
- Low-end Android; free/open-source only.

### Locked decisions
- **State/DI:** Riverpod (+ code-gen); Riverpod doubles as DI (no `get_it`). Routing via **go_router**.
- **Auth model:** phone `+251…` + 4-digit PIN; JWT unchanged.
- **Login lockout (closes SecurityReview M-1):** mandatory — a 4-digit PIN is only 10,000 combinations.
- **Forgot PIN:** info-only for MVP (no self-service reset); real reset deferred.
- **Design fidelity:** exact colors + fonts from Figma; layout/composition latitude is the implementer's.
- **Registration scope:** identity only (phone + PIN + name + language). The 3-step medical onboarding wizard (medical profile, reminders) is deferred to the patient-profile slice.

### Logged for later slices (not in scope)
- Figma has **Appointments** and **Alerts** screens with **no backend** (dropped / unbuilt per scope decisions).
- Backend has **Symptoms** and **Activity** logging with **no Figma screens**.
- Reconcile both when those slices are reached.

---

## 2. Backend half — Phone+PIN auth rework

### 2.1 API contract

**`POST /api/v1/auth/register`** *(public)*
```jsonc
// request
{ "phone": "+251911234567", "pin": "1234", "name": "Abebe Girma", "preferredLanguage": "en" }
// 201 -> auto-login
{ "token": "<jwt>", "user": { "id", "name", "phone", "preferredLanguage", "role": "PATIENT" } }
// 409 phone already registered · 400 bad phone/PIN format
```

**`POST /api/v1/auth/login`** *(public)*
```jsonc
{ "phone": "+251911234567", "pin": "1234" }
// 200 -> { "token", "user" }
// 401 generic "Invalid phone or PIN" · 423 Locked while lockout active
```

**`GET /api/v1/auth/me`** *(authenticated)* — unchanged; returns the user.

### 2.2 Changes

| Area | Change |
|---|---|
| **Migration `V8`** | `users`: add `phone` (unique, not null), `pin_hash`, `preferred_language`, `failed_login_attempts`, `locked_until`; **drop `email` + `password_hash`** (no prod data; phone-only MVP). |
| **`User` entity** | +`phone`, `pinHash`, `preferredLanguage`, `failedLoginAttempts`, `lockedUntil`; remove `email`/`passwordHash`. |
| **DTOs** | `RegisterRequest`(phone, pin, name, preferredLanguage), `LoginRequest`(phone, pin). Validation: phone `^\+251\d{9}$`, pin `^\d{4}$`. |
| **`AuthService`** | `register`: BCrypt-hash PIN, save, issue JWT. `login`: check lockout → verify PIN → reset-or-increment attempts → issue JWT. |
| **Lockout (M-1)** | In-DB counter, no Redis. **5 failed attempts → 15-minute `locked_until`**; a success resets the counter. Per-account. |
| **Docs** | Update `backend/docs/API.md`; mark `backend/docs/SecurityReview.md` M-1 = FIXED. |

### 2.3 Backend tests (TDD)
- `AuthServiceTest`: register success, duplicate-phone (409), login success, wrong-PIN (401), lockout triggers after 5, lockout expires after 15 min, counter resets on success.
- `AuthControllerIntegrationTest` (Testcontainers): full register→login→me flow, validation errors.
- Validation tests for phone / PIN patterns.

---

## 3. Frontend half — Foundation & Auth

### 3.1 Scaffold
`flutter create` → package `com.libucare.app`, **minSdk 21**, portrait-only. `assets/` for the Libu Care logo + any exported icons + `assets/translations/`.

**Dependencies:** `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `build_runner`; `go_router`; `dio`; `drift`, `sqlite3_flutter_libs`; `flutter_secure_storage`; `connectivity_plus`; `easy_localization`; `google_fonts` (Poppins); `iconsax` (Figma icon set is Iconsax "linear"); `freezed`, `json_serializable`. `fl_chart` deferred to the vitals slice.

### 3.2 `core/` layout
```
core/
  theme/        app_theme.dart · app_colors.dart · app_typography.dart · app_spacing.dart
  router/       app_router.dart (go_router + auth redirect/gate)
  network/      dio_client.dart · interceptors/ (auth_token, error_mapping)
  db/           app_database.dart (Drift) + daos
  localization/ en.json · am.json  (assets/translations/)
  config/       env.dart (API base URL via --dart-define)
  error/        failure.dart · exceptions.dart
  providers/    global providers (dio, secureStorage, connectivity, db)
```

### 3.3 Theme — exact Figma tokens

**Font:** Poppins (Regular 400, Bold 700) via `google_fonts`.

| Token | Hex | Usage in design |
|---|---|---|
| `primary` (brand amber/gold) | `#FCAB10` | active nav, primary CTA buttons |
| `accent` (blue) | `#1D4ED8` | links, "Works offline", "Forgot PIN?" |
| `success` (green) | `#16A34A` | Normal / In range |
| `warning` (amber) | `#D97706` | Elevated / Watch |
| `ink` (text primary) | `#282A2A` | headings, labels |
| `textSecondary` | `#6B7280` | body / muted |
| `textTertiary` | `#9CA3AF` | placeholders |
| `surface` / background | `#FFFFFF` | screen background |

**To finalize during the build** (vector/gradient fills, not text layers): the **critical red** (Alerts screen) and the **cream header band** at the top of each screen — pull exact fills then.

**Type scale (Poppins):** display 30 · h1 24 · section 15 (bold) · body 13–14 · caption 12 · micro 10–11 → `app_typography.dart`.

**Config:** API base URL via `--dart-define=API_BASE_URL=...`, default `http://10.0.2.2:8080` (Android emulator → host localhost).

### 3.4 Auth feature (`features/auth/`, three layers)
```
features/auth/
  data/
    models/         user_model.dart · auth_response_model.dart (freezed/json)
    datasources/    auth_remote_datasource.dart (Dio)
                    auth_local_datasource.dart (secure storage: token; Drift: cached user)
    repositories/   auth_repository_impl.dart
  domain/
    entities/       auth_user.dart
    repositories/   auth_repository.dart (interface)
    usecases/       login.dart · register.dart · get_me.dart · logout.dart
  presentation/
    controllers/    auth_controller.dart (Riverpod AsyncNotifier<AuthState>)
    screens/        (see 3.5)
    widgets/        pin_input.dart · phone_field.dart · primary_button.dart
```

**Data flow (offline-first):**
- Token → `flutter_secure_storage`. Cached user → Drift (app opens to a greeting offline).
- Login/register require connectivity (first-time auth is inherently online); if offline, a friendly "connect to sign in" message via `connectivity_plus`.
- **Auth gate (go_router redirect):** on launch, read token → if present & not locally expired (decode JWT `exp`) → **Home** (offline-capable via cached user); else **Login**.
- **Error mapping:** Dio interceptor → `Failure` types → controller → UI. Invalid PIN → inline error; 423 lockout → "Too many attempts, try again in N min"; network error → offline banner.

### 3.5 Screens (from Figma; colors/fonts exact, layout latitude)

| Screen | Source | Notes |
|---|---|---|
| **SplashGate** | — | token check → Home/Login |
| **Login** | Screen 1 | phone `+251…`, 4-digit PIN, Sign in, Create account, language toggle, "Works offline", "Forgot PIN?" |
| **Create account** | Screen 2 (step 1 only) | phone + PIN + name + language → `register` (auto-login). Full medical wizard deferred. |
| **First-run language** | inline | one-time EN / አማርኛ picker (persisted) before Login |
| **Home (placeholder)** | Screen 5 (shell) | greeting + logout; real dashboard = later slice |
| **Forgot PIN (info)** | — | deferred-reset guidance; no self-service |

Icons via `iconsax`; Libu Care logo exported from Figma as an asset.

### 3.6 Frontend tests (TDD)
- **Unit:** `auth_repository_impl` (mocked Dio via `mocktail`); `auth_controller` (`ProviderContainer` overrides); datasources (secure storage + remote).
- **Widget:** Login & Create-account (field validation, error states, loading); auth-gate redirect test.

---

## 4. Isolation & boundaries (why this decomposes cleanly)

- **Backend auth** is a self-contained package change behind a stable HTTP contract (§2.1). Its only outward interface is the three JSON endpoints.
- **`core/`** exposes theme, router, network, db, and providers — features depend on these, never on each other (matches CLAUDE.md architectural rule #1).
- **`features/auth/`** talks to the backend only through `auth_remote_datasource`, and to the rest of the app only through the `AuthRepository` interface + `authController` provider. Local vs remote datasources are separate classes (rule #3).
- Each unit is independently testable: backend service (JUnit), repository/controller (Dart unit tests with mocked Dio), screens (widget tests).

---

## 5. Definition of done
- Backend: migration `V8` applies; auth endpoints work as specified; lockout enforced; all new tests green; `API.md` + `SecurityReview.md` (M-1) updated.
- Frontend: app builds (`flutter analyze` clean); a user can register (phone+PIN), be auto-logged-in, land on Home; relaunch offline lands on Home via cached user; logout returns to Login; first-run language picker persists; all new tests green.
- End-to-end: the Flutter app authenticates against the locally running backend.

---

## 6. Out of scope (explicit)
- Medical-profile onboarding wizard (steps 2–3), reminders — patient-profile slice.
- Self-service PIN reset (SMS/recovery-code) — future slice.
- Appointments, Alerts, Symptoms, Activity screens — later slices.
- SecurityReview items M-2 (token revocation) and HTTPS-at-edge — deployment decisions, tracked separately.
