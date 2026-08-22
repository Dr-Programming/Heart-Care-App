# Frontend Decisions & Roadmap

Living record of the decisions behind the Flutter mobile app, why they were made, and what's planned next. Started 2026-08-02 when frontend work began (backend's 7 slices complete). Update this as decisions evolve.

Related: per-slice specs in `docs/design/`, architecture in `ARCHITECTURE.md` / `PROJECT_STRUCTURE.md`, scope in `FUNCTIONAL_REQUIREMENTS.md`, backend contract in `backend/docs/API.md`.

---

## 1. How we build the frontend

**Changed 2026-08-22: the frontend is team-owned and built in parallel.** The
backend was built solo, one slice after another, and the frontend was going to
be. It is not. Five developers each own one feature end to end, so they earn
real authorship, and the CTO reviews rather than implements. Programme index:
`docs/design/2026-08-22-mobile-frontend-program.md`.

**Decomposition — a complete foundation first, then five parallel features.**
Sequential slices could share files freely because one person touched them.
Parallel slices cannot: five branches editing `app_database.dart`,
`pubspec.yaml` and `en.json` would spend more time merging than building. So
the foundation slice declares **every shared file complete up front** — the
whole database schema, all 18 API paths, every dependency, the full route
table, the widget kit, the sync engine — and a feature slice then edits only
its own folder plus one marked region in `lib/app/app_wiring.dart`.

**A slice document is now a spec, not a plan.** Each feature gets a
`docs/design/` spec; writing the implementation plan is the first task of the
slice and belongs to its owner. That is where their engineering judgement
shows, and it is what makes the contribution real rather than transcription.

**Execution = contract-first, still.** The backend is frozen at `v1.0.0`, so
every feature is built against a real, tested API. Integration risk stays near
zero even with five people working at once.

**Method = TDD, feature-first clean architecture.** Logic first (pure Dart, test-driven), then wire the UI. In an offline-first app the hard part is the data flow, not the pixels — building logic first means screens plug into proven controllers instead of a moving target. Each feature is self-contained with `data / domain / presentation` layers (see `CLAUDE.md` architectural rules).

---

## 2. Technical stack decisions

| Decision | Choice | Why |
|---|---|---|
| **State management** | **Riverpod** (+ code-gen) | Compile-safe, excellent testability (`ProviderContainer` overrides), strong async/loading/error model (`AsyncNotifier`) — ideal for offline flows. CLAUDE.md deliberately left this open; now decided. |
| **Dependency injection** | **Riverpod** (no `get_it`) | Riverpod's providers are the DI graph — one tool instead of two. |
| **Routing** | **go_router** | Declarative + a redirect hook that implements the auth gate cleanly. |
| **Fonts** | **Poppins** via `google_fonts` | Exact design font; it's a Google Font, so no manual bundling. |
| **Icons** | **iconsax** | The Figma design uses the Iconsax "linear" set — the Flutter package is an exact match. Custom marks (Libu Care logo) exported as assets. |
| **Local DB** | `drift` (SQLite) | Offline source of truth (per CLAUDE.md). |
| **HTTP** | `dio` | Interceptors for JWT injection + error mapping. |
| **Secure storage** | `flutter_secure_storage` | Encrypted JWT at rest. |
| **Connectivity** | `connectivity_plus` | Detect offline to gate first-time auth. |
| **Localization** | `easy_localization` | EN / አማርኛ; first-run language picker + in-app toggle. |
| **Charts** | `fl_chart` (deferred) | Vitals slice, not now. |
| **Models/codegen** | `freezed` + `json_serializable` | Immutable models, JSON mapping. |

**Platform config:** package `com.libucare.app`, minSdk 21 (low-end Android), portrait-only. API base URL via `--dart-define=API_BASE_URL=...`, default `http://10.0.2.2:8080` (Android emulator → host localhost).

---

## 3. Auth decisions (this changes the backend)

**Auth model = phone `+251…` + 4-digit PIN.** The Figma design is phone+PIN throughout; the backend was email+password. We chose to **change the backend to match Figma** because phone+PIN is the right UX for the target users (low digital literacy, Ethiopian mobile-first) — the designer chose it deliberately. This reopens the "done" backend (new migration `V8`, auth refactor). See the spec §2 for the exact contract and changes.

**Login lockout is now mandatory** (closes SecurityReview **M-1**). A 4-digit PIN is only 10,000 combinations — trivially brute-forced online without a lockout. Policy: **5 failed attempts → 15-minute lockout**, per account, in-DB counter (no Redis). This was previously a "needs a decision" item; the PIN model forces it.

**Registration scope = identity only** (phone + PIN + name + preferred language → one screen, auto-login). The Figma "create account" is a 3-step wizard, but steps 2–3 (medical profile, reminders) belong to the **patient-profile slice** — they write to `PUT /patients/me` and device-local storage that don't exist on the client yet.

**Forgot PIN = deferred for MVP.** The "Forgot PIN?" link shows guidance (contact clinic / re-register) — no self-service reset. Real reset options (SMS OTP vs. recovery code) were weighed and deferred to avoid a paid SMS gateway and to keep the auth slice tight. See §6.

**Offline auth behavior.** Token in secure storage; user cached in Drift so the app opens to a greeting offline. On launch the go_router redirect reads the token, checks local JWT `exp`, and routes to Home (offline-capable) or Login. First-time login/register require connectivity and show a friendly message otherwise.

---

## 4. Design fidelity

**Contract with the designer:** colors and fonts must match **exactly**; layout/composition is the implementer's latitude (redesign screens, build missing ones, merge/split flows) as long as the color + type system stays faithful.

**Figma source:** file `B2D41kike6v4YRjHQMlszS` ("Capstone"), page "Main", section "LibuCare - Main Design" — 10 mobile frames (402×874). No Figma variables; raw hex/fonts, so tokens were read from layer styles.

**Exact tokens extracted** (→ `core/theme`):

| Token | Hex |
|---|---|
| `primary` (brand amber/gold) | `#FCAB10` |
| `accent` (blue) | `#1D4ED8` |
| `success` (green) | `#16A34A` |
| `warning` (amber) | `#D97706` |
| `ink` (text primary) | `#282A2A` |
| `textSecondary` | `#6B7280` |
| `textTertiary` (placeholder) | `#9CA3AF` |
| `surface` / background | `#FFFFFF` |

Font **Poppins** (Regular 400 / Bold 700). Type scale: display 30 · h1 24 · section 15 · body 13–14 · caption 12 · micro 10–11.

**Still to extract at build time** (vector/gradient fills, not text layers): the **critical red** (Alerts screen) and the **cream header band** atop each screen.

---

## 5. Screen inventory & design ↔ backend mismatches

The 10 Figma screens: **Login**, **Onboarding 1–3** (personal details → medical profile → reminders), **Home**, **Medications**, **Vitals**, **Alerts**, **Appointments**, **Profile**.

Mismatches logged during design review (reconcile when each slice is reached):

- **In Figma, no backend:** **Appointments** (§13 dropped per scope decisions) and **Alerts** (alert engine planned, never built). Building these requires new backend work or dropping the screens.
- **In backend, no Figma screen:** **Symptoms** and **Activity** logging endpoints exist but have no designed screens — need new screens (implementer's latitude).

---

## 6. Future planning

### Frontend slice map (owners work in parallel)

| Slice | Branch | Scope |
|---|---|---|
| **M0** Foundation & app shell | `mobile` | **Built.** Scaffold, theme, full Drift schema, sync engine, clinical evaluator, router, five-tab shell, widget kit, test helpers, CI. |
| **M1** Auth & session | `feature/mobile/auth` | Splash/gate, first-run language, login, register, forgot-PIN, logout. |
| **M2** Profile, onboarding & settings | `feature/mobile/profile` | 3-step wizard, profile view/edit, goals, settings, language toggle, accessibility. |
| **M3** Medications, dose logs & reminders | `feature/mobile/medications` | Med CRUD, schedule, dose logging, adherence, local notifications. |
| **M4** Vitals & trend charts | `feature/mobile/vitals` | Five vital types, history, flags, `fl_chart` 7/30-day trends. |
| **M5** Symptoms, activity & guidance | `feature/mobile/symptoms-activity` | Daily check-in, activity logging, bundled EN/AM education and diet content, quiz. |

Branch from `mobile`, PR into `mobile`; `mobile` → `dev` at milestones.

**M1 is the critical path for manual end-to-end testing** — nothing else can
reach a real token until login exists. It does not block development: the app
is offline-first, so every other slice's local path, repository logic and
widget tests are buildable without a session, and `OpenAuthGate` keeps the
shell reachable until M1 lands.

### Deferred items to revisit
- **Self-service PIN reset.** Options considered: **SMS OTP** (standard, self-service, but needs a paid gateway + connectivity — conflicts with free/offline constraints) or a **recovery code at signup** (offline, free, but weak UX for low-literacy users). Revisit once an SMS path is decided. M1 ships a guidance screen only.
- **NFR-004, AES-256 at rest** (SQLCipher or equivalent) — unimplemented; plain Drift today. Deferred rather than dropped: adopting it changes the database setup for every slice at once, so it is a single coordinated change after the features land.
- **Amharic clinical and educational copy** — written by the implementers, **not yet reviewed by a native speaker**. A release gate, alongside the clinical thresholds.
- **Appointments** — dropped (D6). The Figma screen has no backend.
- **Alerts screen** — dropped (D4); severity surfaces inline instead.

Now settled, previously listed here: the onboarding wizard and reminders (M2
and M3), symptom and activity screens (M5, designed from scratch), DOB as year
only (M2), and `preferred_language` ownership (D5).

### Backend security items still open (tracked in `backend/docs/SecurityReview.md`)
- **M-1 (login rate limiting)** — **closed** by the PIN lockout shipped in `v1.0.0`.
- **M-2 (token lifetime / revocation)** — open by decision. The offline auth gate reads the JWT `exp` locally and never calls the server, so a revoked token would still open the app until it expires. Accepted for the MVP; a `token_version` claim remains the cheapest fix.
- **M-3 (registration reveals whether a phone is in use)** — open by decision.
- **HTTPS at the platform edge** — deployment concern, confirm on Railway.

---

## 7. References
- **Programme index: `docs/design/2026-08-22-mobile-frontend-program.md`**
- Per-slice specs: `docs/design/2026-08-22-mobile-m1..m5-*-design.md`
- Team workflow: `mobile/CONTRIBUTING.md` · rules: `mobile/CLAUDE.md`
- Superseded (kept as history): `docs/design/2026-08-02-phone-pin-auth-and-mobile-foundation-design.md` §3, `docs/plans/2026-08-17-slice8-mobile-foundation-auth-frontend.md`
- Backend API contract: `backend/docs/API.md`
- Security findings: `backend/docs/SecurityReview.md`
- Figma file key: `B2D41kike6v4YRjHQMlszS`
- Architectural rules & stack: `CLAUDE.md`

---

## 8. Team-parallel scope decisions (2026-08-22)

Settled when the frontend became team-owned. Recorded here so a slice owner can
see the reasoning rather than re-litigating it mid-build.

**D1 — Education, the diet guide and activity guidance are in scope**, in M5,
as bundled offline EN/AM content, reference links only, no video. Dropping them
would have left 19 P1 requirements unmet, and they have zero backend coupling
and zero shared-file contact — the safest possible parallel work.

**D2 — Local notifications are in scope**, in M3, alongside the medication
schedule. FR-NOT-001/002/003 are all medication-triggered; a separate owner
would have needed a cross-feature import to reach the schedule.

**D3 — Decision support is in scope** as pure functions in `core/clinical/`,
built as part of M0. `PROJECT_STRUCTURE.md` already placed the evaluator in
core, and FR-DEC-011 requires it to work entirely offline, so it is
client-side by definition. **The thresholds mirror `SymptomAssessment.java`
and `VitalThresholds.java` exactly** — if the two disagreed, a reading would
change severity after it synced, which is the worst possible behaviour for
clinical information.

**D4 — No standalone Alerts screen.** Severity surfaces inline: on entry, as
chips in history, and on a Home card. The Figma Alerts screen has no backend
and its clinician-forwarding half (FR-DEC-010) is dropped scope; FR-DEC-009
only requires the recommended action be displayed.

**D5 — Language is device-local, and this closes the open `preferred_language`
question.** `core/localization/LanguageStore` is authoritative.
`users.preferred_language` is a registration-time hint with no update endpoint;
`patient_profiles.preferred_language` is profile data written through
`PUT /patients/me`. Neither decides what the UI renders. The setting is
inherently per-device, the toggle has to work offline, and adding
`PATCH /users/me/language` would reopen a shipped API for a value the server
never reads.

**D6 — Appointments stay dropped.** NFR-004 (AES-256 at rest, SQLCipher) is
deferred and logged as a known gap: adopting SQLCipher would change the Drift
setup for all five slices at once.

**D7 — Home is assembled from a `HomeCard` registry.** Each feature contributes
its own card and Home only lays them out, so five people land part of one
screen without any feature importing another (architectural rule #1).

**Still open, and not for a feature branch to settle:** self-service PIN reset
(deferred; M1 shows guidance only), SecurityReview **M-2** (7-day tokens, no
revocation — the offline auth gate accepts this by design) and **M-3**
(registration reveals whether a phone is in use).
