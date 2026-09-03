# Frontend Decisions & Roadmap

Living record of the decisions behind the Flutter mobile app, why they were made, and what's planned next. Started 2026-08-02 when frontend work began (backend's 7 slices complete). Update this as decisions evolve.

Related: per-slice specs in `docs/design/`, architecture in `ARCHITECTURE.md` / `PROJECT_STRUCTURE.md`, scope in `FUNCTIONAL_REQUIREMENTS.md`, backend contract in `backend/docs/API.md`.

---

## 1. How we build the frontend

**Decomposition — one slice at a time, mirroring the backend.** The whole app is too large for a single spec/plan. Each slice gets its own `docs/design/` spec → implementation plan → build, exactly like the backend did.

**First slice = Foundation & Auth** (`docs/design/2026-08-02-phone-pin-auth-and-mobile-foundation-design.md`). It scaffolds the project + `core/` layer and delivers the auth feature end-to-end, proving the full vertical stack against the running API. Chosen over "foundation only" (nothing user-visible, doesn't exercise the network/auth stack) and over a bigger multi-feature slice (too much to review at once).

**Execution = contract-first, backend then frontend.** Single developer, so sequential beats parallel: freeze the API contract, implement + test the backend, then build the frontend against real endpoints. Near-zero integration risk.

**Method = TDD, feature-first clean architecture.** Logic first (pure Dart, test-driven), then wire the UI. In an offline-first app the hard part is the data flow, not the pixels — building logic first means screens plug into proven controllers instead of a moving target. Each feature is self-contained with `data / domain / presentation` layers (see `CLAUDE.md` architectural rules).

---

## 2. Technical stack decisions

| Decision | Choice | Why |
|---|---|---|
| **State management** | **Riverpod** — codegen dropped, see §7 | Compile-safe, excellent testability (`ProviderContainer` overrides), strong async/loading/error model (`AsyncNotifier`) — ideal for offline flows. CLAUDE.md deliberately left this open; now decided. `riverpod_generator` can't co-resolve with `drift_dev` on this toolchain, so every provider is hand-declared. |
| **Dependency injection** | **Riverpod** (no `get_it`; no codegen — see §7) | Riverpod's providers are the DI graph — one tool instead of two. |
| **Routing** | **go_router** | Declarative + a redirect hook that implements the auth gate cleanly. |
| **Fonts** | **Poppins + Noto Sans Ethiopic**, bundled as assets (`google_fonts` removed) — see §7 | Exact design font. Bundled rather than fetched at runtime: offline-first requires no runtime download, and it fixes Amharic tofu (Poppins has no Ethiopic glyphs); Latin stays Poppins via `fontFamilyFallback`. |
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

**Still to extract at build time** (vector/gradient fills, not text layers): the **critical red** (Alerts screen). The **cream header band** was extracted during slice 1 — `#DBD5B5` (see §7); the **critical red** is still outstanding for the Vitals/Alerts work.

---

## 5. Screen inventory & design ↔ backend mismatches

The 10 Figma screens: **Login**, **Onboarding 1–3** (personal details → medical profile → reminders), **Home**, **Medications**, **Vitals**, **Alerts**, **Appointments**, **Profile**.

Mismatches logged during design review (reconcile when each slice is reached):

- **In Figma, no backend:** **Appointments** (§13 dropped per scope decisions) and **Alerts** (alert engine planned, never built). Building these requires new backend work or dropping the screens.
- **In backend, no Figma screen:** **Symptoms** and **Activity** logging endpoints exist but have no designed screens — need new screens (implementer's latitude).

---

## 6. Future planning

### Frontend slice roadmap (tentative order)
1. **Foundation & Auth** — **built 2026-09-03** (backend phone+PIN rework shipped at `v1.0.0`; Flutter foundation + auth verified end-to-end against the live backend — see §7).
2. **Patient profile + onboarding wizard** — the full 3-step Figma onboarding (medical profile, reminders), `GET/PUT /patients/me`, first offline read/write + sync.
3. **Home dashboard + bottom nav** — the real Home shell (replaces the auth-slice placeholder).
4. **Medications & dose logs** — Today/Schedule/History, add medication.
5. **Vitals** — logging + `fl_chart` trends.
6. **Symptoms** — daily check-in (needs a new screen; backend exists).
7. **Activity** — session logging (needs a new screen; backend exists).
8. **Offline sync engine** — Drift `sync_queue`, `POST /api/v1/sync`, conflict handling.

*(Order may adjust; Home shell could merge into a later feature slice.)*

### Deferred items to revisit
- **Self-service PIN reset.** Options considered: **SMS OTP** (standard, self-service, but needs a paid gateway + connectivity — conflicts with free/offline constraints) or a **recovery code at signup** (offline, free, but weak UX for low-literacy users). Revisit once an SMS path is decided.
- **Medical-profile onboarding wizard (steps 2–3)** and **reminders** — patient-profile slice. Reminders are device-local notifications; confirm whether any backend is needed (currently none).
- **Appointments / Alerts screens** — need a backend decision (build vs. drop) before implementing.
- **Symptoms / Activity screens** — design from scratch against existing backend.
- **DOB = year only** (per scope decisions) — enforce in the profile slice.

### Backend security items still open (tracked in `backend/docs/SecurityReview.md`)
- **M-1 (login rate limiting)** — **closed** by this slice: 5 failed PINs → `423 Locked` for 15 min (`app.auth.lockout.*`). Verified by curl in slice 1 (5th attempt returns 423, correct PIN also refused during the lockout).
- **M-2 (token lifetime / revocation)** — **still open by decision.** 7-day tokens, no revocation path. Not addressed in slice 1.
- **M-3 (registration enumerates phones)** — **still open by decision.** `POST /auth/register` returns `409 "Phone already registered"`, revealing whether a number is in use.
- **HTTPS at the platform edge** — deployment concern, confirm on Railway.

---

## 7. Slice 1 — Foundation & Auth — built 2026-09-03

The first mobile slice is built and verified end-to-end against the running
backend. See `mobile/README.md` for run/test instructions.

**What shipped**
- Flutter app scaffolded: package `com.libucare.app`, `minSdk 21`, portrait-only,
  plus a **web dev-preview** target (not a shipping platform — see caveats below).
- `core/` layer: theme (exact Figma tokens), config (`--dart-define API_BASE_URL`,
  default `http://10.0.2.2:8080`), network (Dio + bearer-token interceptor +
  `Failure` mapping), Drift DB (cached user + preferences), localization
  (EN/AM, device-local language store), `security/jwt.dart` (local `exp` check),
  go_router with the offline auth-gate redirect, Riverpod providers.
- Auth feature, three layers: phone+PIN **register / login / me** against the live
  API, offline-aware repository (local datasource is source of truth), JWT-expiry
  gate, secure-storage token + Drift-cached user for an offline greeting.
- Screens: splash gate, first-run language picker, Login, Create account
  (identity fields only), Home placeholder, Forgot-PIN info.
- **98 tests**, `flutter analyze` clean. curl contract check green (register 200 /
  duplicate 409 / login 200 / wrong-PIN 401 / lockout **423 "Try again in 15
  minutes."** / me 200). Chrome-driven against the live backend: first-run
  language picker → pick አማርኛ → Amharic renders with **no tofu** → picker does
  not reappear on reload → register a fresh number → Home greeting → reload stays
  on Home → sign out returns to Login.

**Decisions settled by this slice**
- **Figma file in use for the frontend is `2ulgCN3pghwu6g4bzzi4mw`** (the `§4` /
  References key `B2D41kike6v4YRjHQMlszS` is the earlier "Capstone" file). Its
  **"Screen 2" is the 3-step medical wizard**, so **Create account was composed
  from that frame's visual system with an identity-only field set** — DOB /
  height / sex are deferred to the patient-profile slice.
- **First-run language picker** and **Forgot-PIN info screen** were built from the
  design system — no Figma frames exist for them.
- **Fonts are bundled** (Poppins + Noto Sans Ethiopic under `assets/fonts/`)
  instead of `google_fonts` runtime fetch. Reasons: the offline-first constraint
  (no runtime download), it fixes Amharic tofu, and `fontFamilyFallback` keeps
  Latin text in Poppins on Amharic screens. This supersedes the §2 "Poppins via
  `google_fonts`" row for the shipped app.
- **`preferredLanguage` is device-local for this slice.** `users.preferred_language`
  still has no update endpoint; which column owns the setting is a
  patient-profile-slice decision (the open question in `CLAUDE.md` stands
  unchanged).
- **Brand hexes:** header band `#DBD5B5`, primary button `#FCAB10` — from this
  doc's earlier extraction. The Figma file has no variables and both are
  flattened SVG fills, so **confirm on a real colour-pick when convenient.**
  Header band **212px**, logo **160px** at **36px** top-inset (frame `368:680`,
  ~214px band); 212 = 36 + 160 + 16px of cream below the mark.
- **Confirm-PIN field added to Create account** (not on any frame): a mistyped
  4-digit PIN with no self-service reset is a permanent lockout. Client-side
  check only.
- **Backend security items M-2** (7-day tokens, no revocation path) **and M-3**
  (registration reveals whether a phone is in use) **remain open by decision** —
  see §6.
- **Web dev-preview caveats:** `flutter build web` needs `--no-tree-shake-icons`
  (the `iconsax` 0.0.8 font breaks the icon subsetter); drift's WASM DB runs on
  `sharedIndexedDb` and is not durable across a hard refresh, so the web app
  recovers its session via `GET /auth/me` when online and a true fresh restore is
  server-side. Native (SQLite + secure storage) persistence is durable.

**Deviations from the spec, and why** — see the plan's Self-Review; the load-bearing
ones are the bundled-font swap (above), the composed (not traced) Create account,
and the toolchain (Flutter 3.44.8 / Dart 3.12.2, Riverpod pinned 2.6.x without
codegen, `freezed` 3.2.x prerelease).

---

## 8. References
- Slice spec: `docs/design/2026-08-02-phone-pin-auth-and-mobile-foundation-design.md`
- Backend API contract: `backend/docs/API.md`
- Security findings: `backend/docs/SecurityReview.md`
- Frontend run/test instructions: `mobile/README.md`
- Figma file key: `B2D41kike6v4YRjHQMlszS` ("Capstone"); **frontend build uses `2ulgCN3pghwu6g4bzzi4mw`** (see §7)
- Architectural rules & stack: `CLAUDE.md`
