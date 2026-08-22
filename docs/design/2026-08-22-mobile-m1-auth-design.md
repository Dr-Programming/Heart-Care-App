# Mobile Design — M1 (Auth & Session)

**Date:** 2026-08-22
**Branch:** `feature/mobile/auth`
**Base:** `mobile`
**Status:** Approved for planning
**Depends on:** M0 (merged)

---

## 0. How to use this spec

This is a design document, not a plan. Your first task is to turn it into one.

1. `/superpowers:brainstorming` — settle what is left open below.
2. `/superpowers:writing-plans` → `docs/plans/2026-XX-XX-mobile-m1-auth.md`.
3. `/superpowers:subagent-driven-development` — execute task by task.
4. `/superpowers:requesting-code-review`, then
   `/superpowers:finishing-a-development-branch` — PR into `mobile`.

Read `mobile/CLAUDE.md` and `mobile/CONTRIBUTING.md` first. Build bottom-up:
domain → data → presentation.

---

## 1. Context & goal

Every other slice is gated behind this one. Until login exists, nobody can
reach a real token, so M1 is the critical path for end-to-end testing even
though it does not block anyone's development.

Auth here is **phone + 4-digit PIN**, not email + password. The backend was
reworked to match (`V8`, released in `v1.0.0`): phone is `+251` followed by
nine digits, the PIN is exactly four digits, both BCrypt-hashed, and five
consecutive failures lock the account for fifteen minutes.

The goal: a patient can create an account, sign in, stay signed in across
relaunches **including offline relaunches**, and sign out.

### Requirements covered (`FUNCTIONAL_REQUIREMENTS.md` §1, §16)

FR-AUTH-001 (register), 002 (log in), 004 (7-day JWT), 005 (encrypted token
storage), 006 (auto-login on relaunch), 007 (log out), 009 (a patient reaches
only their own data — enforced server-side, honoured here by never caching
another user's row). FR-LOC-003, first-run language picker.

FR-AUTH-003, 010, 011 (roles, clinician, admin) are dropped scope.
FR-AUTH-008 (reset) is deferred — see Decision 4.

### Deferred / out of scope (and where it lands)

- **The medical onboarding wizard.** Registration is identity only. Steps 2–3
  of the Figma "create account" flow are **M2**.
- **Self-service PIN reset.** Guidance screen only. Revisit when an SMS
  gateway is decided.
- **Changing the language after first run.** The picker here is one-time; the
  settings toggle is **M2**.
- **Token revocation** (SecurityReview M-2) and **registration disclosing that
  a phone is in use** (M-3) remain open by decision, backend-side.

---

## 2. Design decisions

### Decision 1 — The auth gate reads local state only, never the network

`AuthGate` (`core/router/auth_gate.dart`) is consulted on every navigation,
including a cold start with no signal. Implement it from the token in secure
storage plus a local decode of the JWT `exp` claim (`core/security/jwt.dart`),
and nothing else.

`GET /auth/me` is for refreshing the cached user, never for deciding whether
the user is signed in. If the gate awaited a request, an offline launch would
either hang on a spinner or bounce a signed-in patient to Login — the exact
failure the offline-first design exists to prevent.

Consequence: a token revoked server-side still opens the app until it expires.
Accepted; that is SecurityReview M-2, open by decision.

### Decision 2 — The session is two independent pieces of local state

The **token** lives in `flutter_secure_storage` (`TokenStore`). The **user**
lives in Drift (`CachedUsers`, one row, via `CachedUserDao`). They are written
together on sign-in and cleared together on sign-out, but read independently:
the gate needs only the token; the greeting needs only the row.

`cachedUserProvider` in `core/` already exposes the row as a stream. That is
how the shell greets the user without importing this feature — keep writing to
that table and everyone else keeps working.

### Decision 3 — Login and register are the only operations allowed to require connectivity

Everywhere else in the app, an action must work offline. First-time
authentication genuinely cannot: there is nothing local to check a PIN
against. Fail fast — check `isOnlineProvider` **before** the request and
surface `errors.offline` — rather than letting a 20-second timeout expire.

Do not build an offline PIN check. Caching a PIN hash on the device to verify
against would put a four-digit secret's hash on the filesystem, and a
four-digit space is 10,000 candidates.

### Decision 4 — Forgot PIN is an information screen

No self-service reset for the MVP. SMS OTP needs a paid gateway and
connectivity; a recovery code issued at signup is poor UX for users with low
digital literacy. The screen explains how to get help from the clinic and
reassures the patient that a lockout expires on its own.

The copy is already written and translated: `auth.forgotPin.*`.

### Decision 5 — Validators return translation keys, not sentences

A validator returns `'auth.errors.phoneFormat'`; the widget calls `.tr()`.
Pure functions stay testable without a widget binding, and the same validator
works in both languages.

### Decision 6 — The lockout is a wait, never a wrong PIN

`423` must render as "too many attempts, try again in N minutes", never as an
invalid-credentials error. `AccountLockedFailure` already carries
`minutesRemaining`, parsed by `parseLockoutMinutes` — which handles the
server's singular "1 minute" on the final minute. Use it; do not re-parse.

Do not retry a `423` on a timer. It resolves with time, not with retries.

### Decision 7 — Registration auto-logs-in, then hands off to onboarding

`POST /auth/register` returns `{token, user}`. Store the session exactly as
login does, then set the flag that makes `AuthGate.needsOnboarding` true so
the router sends the new patient into M2's wizard. Persist that flag in
`Preferences` so it survives a kill mid-wizard.

Until M2 lands there is no wizard, so keep `needsOnboarding` false and go
straight to Home. Note it in your PR so M2 knows to flip it.

---

## 3. Screens

Figma file `B2D41kike6v4YRjHQMlszS`, section "LibuCare - Main Design".
Colours and fonts are exact and contractual; layout is yours.

| Screen | Route | Source | Contents | States |
|---|---|---|---|---|
| **Splash / gate** | `AppRoutes.splash` `/` | — | Logo while the token check resolves. Must be brief — it is local work only. | resolving only |
| **Language picker** | `AppRoutes.language` | inline | English / አማርኛ, each in its own script. One-time; persists via `LanguageStore`. | idle |
| **Login** | `AppRoutes.login` | Screen 1 | Phone (`+251` prefixed), 4-digit PIN, Sign in, Create account, Forgot PIN, "Works offline" note, language toggle | idle · validating · submitting · invalid credentials · locked · offline |
| **Create account** | `AppRoutes.register` | Screen 2, step 1 | Name, phone, PIN, confirm PIN, preferred language → register + auto-login | idle · validating · submitting · phone taken · offline |
| **Forgot PIN** | `AppRoutes.forgotPin` | — | Guidance, no input. Back to sign in. | static |

Use `AppScaffold.banded` for the cream header band, `AppTextField`,
`AppButton`, and `iconsax` icons. A PIN entry widget is genuinely
feature-specific — build it in `features/auth/presentation/widgets/`, not in
`core/`.

All copy exists in both languages under `auth.*` in
`assets/translations/en.json` and `am.json`. Add keys only inside that
namespace.

**Amharic is not optional.** Check every screen in Amharic — the strings are
longer and will overflow a layout tuned to English.

---

## 4. API contract

From `backend/docs/API.md` §1. **Success is always `200`** — there is no `201`
even for register. Every response is the `{success, data, message, timestamp}`
envelope; unwrap with `ApiResponse.fromJson`.

### `POST /api/v1/auth/register` — public

```jsonc
// request
{ "phone": "+251911234567", "pin": "1234", "name": "Abebe Girma",
  "preferredLanguage": "en" }
// 200
{ "token": "<jwt>",
  "user": { "id", "name", "phone", "preferredLanguage", "role": "PATIENT" } }
```

`409` phone already registered · `400` bad format. `role` is always `PATIENT`.

### `POST /api/v1/auth/login` — public

```jsonc
{ "phone": "+251911234567", "pin": "1234" }
// 200 -> { "token", "user" }
```

`401` — message is deliberately identical for an unknown phone and a wrong
PIN, and the server compares in constant time. Do not "helpfully" distinguish
them in the UI.
`423` — `"Too many failed attempts. Try again in N minutes."`, singular on the
final minute.

### `GET /api/v1/auth/me` — authenticated

Returns the user. `404` if the account was deleted while a valid token exists
— treat as a signed-out session. Use it to refresh the cached row after a
successful online start, never to gate navigation.

### Validation, client-side, before any request

Phone `^\+251\d{9}$` · PIN `^\d{4}$` · confirm PIN matches · name 1–255 chars
· language ∈ {`en`, `am`}.

---

## 5. Local state & offline behaviour

| What | Where | Notes |
|---|---|---|
| JWT | `flutter_secure_storage` via `TokenStore` | Android Keystore / iOS Keychain (FR-AUTH-005) |
| User | `CachedUsers` (Drift), one row | `CachedUserDao.save` replaces wholesale — a second row would be a bug |
| Language | `Preferences` via `LanguageStore` | device-owned (D5) |
| Needs onboarding | `Preferences` | set at register, cleared by M2 |

Nothing in this slice touches the sync queue: auth is not a user-generated
record.

**Sign-out clears all four.** A cached user left behind after sign-out shows
the next person the previous patient's name — a privacy bug, not a cosmetic
one.

**Relaunch offline** must land on Home with the greeting intact. This is the
single most important behaviour in the slice; test it explicitly.

---

## 6. Feature layout

```
lib/features/auth/
  auth_providers.dart              repository, datasources, the real AuthGate
  domain/
    entities/auth_user.dart
    repositories/auth_repository.dart
    usecases/{login,register,get_me,logout}.dart
    validators.dart
  data/
    models/{user_model,auth_response_model}.dart   freezed + json
    datasources/auth_remote_datasource.dart        Dio only
    datasources/auth_local_datasource.dart         secure storage + Drift
    repositories/auth_repository_impl.dart
  presentation/
    controllers/auth_controller.dart               AsyncNotifier<AuthState>
    screens/{splash,language,login,register,forgot_pin}_screen.dart
    widgets/{phone_field,pin_input}.dart
```

Wire it up in `lib/app/app_wiring.dart`, in the `M1 auth` region: add the five
routes to `topLevel`, and override `authGateProvider` with your implementation.

---

## 7. Files this slice may NOT touch

`lib/core/**` · `lib/main.dart` · `pubspec.yaml` · `lib/core/db/tables.dart`
· `api_endpoints.dart` — all owned by M0 and already complete. The three auth
paths, `CachedUsers`, `Preferences`, `TokenStore`, `jwt.dart`, the
`Failure` subtypes and `AuthGate` all exist.

Allowed, in your marked region only: `lib/app/app_wiring.dart`, and the
`auth.*` namespace in `assets/translations/*.json`.

Missing something shared? Ask the maintainer. Do not add it here.

---

## 8. Testing strategy (TDD)

**`validators_test`** — phone accepts `+251911234567`; rejects `0911234567`,
a wrong country code, letters, too few and too many digits. PIN accepts exactly
four digits, rejects three, five and non-digits. Confirm-PIN mismatch. Name
length bounds. Every failure returns a key that exists in `en.json`.

**`auth_remote_datasource_test`** (`FakeDio`) — register and login send the
exact documented bodies; both unwrap the envelope from a **200**, not a 201;
`me` attaches the bearer token.

**`auth_repository_impl_test`** (`FakeDio` + `testDatabase()`) — a successful
login writes both the token and the cached row; **login while offline makes no
request at all** and throws `NetworkFailure`; `401` on login →
`InvalidCredentialsFailure`; `401` on `me` → `SessionExpiredFailure`; `423` →
`AccountLockedFailure` with the right `minutesRemaining`, including the
final-minute singular; `409` on register → `PhoneAlreadyRegisteredFailure`;
logout clears token, user, and the onboarding flag.

**`auth_gate_test`** — signed in when a valid token is stored; signed out when
none is; signed out when the token has locally expired; **resolves without any
network call** (assert `FakeDio.requests` is empty).

**`auth_controller_test`** (`ProviderContainer` overrides) — cold start with a
stored session restores from disk with no request; login and register move
through loading to authenticated; a failure lands in `AsyncError` carrying the
`Failure`; sign-out returns to unauthenticated.

**Widget tests** (`pumpApp`) — Login: invalid phone shows an inline error and
does not submit; a wrong PIN shows the credentials error; `423` shows the wait
message with the minutes; offline shows the offline message and never
submits; the submit button shows its loading state and cannot be double-tapped.
Create account: PIN mismatch blocks submit; a taken phone shows its error.
Language picker: choosing አማርኛ persists and re-renders in Amharic.
At least one screen asserted in Amharic.

---

## 9. "Done" criteria

- A new patient registers with phone, PIN, name and language, is signed in
  automatically, and lands in the app.
- An existing patient signs in; a wrong PIN gives one clear message; five
  wrong PINs give a wait message with the remaining minutes.
- Killing and relaunching the app **with the radio off** lands on Home with
  the greeting intact and makes no request.
- Sign-out returns to Login and leaves no token and no cached user.
- The first-run language picker appears once, persists, and does not reappear.
- Forgot PIN explains what to do.
- Every screen renders correctly in English and አማርኛ.
- `flutter analyze` clean; whole suite green; CI passing.

---

## 10. Handover checklist

- [ ] Plan committed to `docs/plans/`
- [ ] `flutter analyze` clean, `flutter test` green
- [ ] Ran the app against a local backend and used every flow, including the
      offline relaunch
- [ ] No edits to shared files outside the marked regions
- [ ] Screenshots in the PR, English and Amharic
- [ ] No AI co-author trailer on any commit
- [ ] PR into `mobile`, title `feat(mobile): M1 — Auth & session`
- [ ] Noted in the PR whether `needsOnboarding` is wired, so M2 knows
