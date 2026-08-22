# Mobile Frontend — Programme Overview

**Date:** 2026-08-22
**Status:** Approved
**Supersedes:** §3 of `docs/design/2026-08-02-phone-pin-auth-and-mobile-foundation-design.md`
and `docs/plans/2026-08-17-slice8-mobile-foundation-auth-frontend.md`

This is the index. Each of the five feature slices has its own spec; start
there once you know which one is yours.

---

## 1. What changed, and why

The backend was built solo, one slice at a time, and the frontend was going to
be built the same way. It is not. The frontend is now owned by the team, one
feature per developer, working in parallel.

That changes the decomposition problem. Sequential slices could share files
freely because only one person ever touched them. Parallel slices cannot: five
branches editing `app_database.dart`, `pubspec.yaml` and `en.json` would spend
more time merging than building. So the foundation slice (M0) deliberately
front-loads **every shared file**, complete, before any feature starts — the
full database schema, every API path, every dependency, the router's whole
route table, the widget kit, the sync engine. A feature slice then edits only
its own folder plus one marked region in one integration file.

It also changes what a "slice document" is. The backend's slices had a design
spec *and* a 1,000–4,800-line implementation plan with the code written out.
Here you get the spec; **writing the plan is the first task of the slice**, and
it is yours. See §5.

---

## 2. The slices

| Slice | Branch | Owner |
|---|---|---|
| **M0** Foundation & app shell | `mobile` | maintainer — **done** |
| **M1** [Auth & session](2026-08-22-mobile-m1-auth-design.md) | `feature/mobile/auth` | |
| **M2** [Profile, onboarding & settings](2026-08-22-mobile-m2-profile-onboarding-design.md) | `feature/mobile/profile` | |
| **M3** [Medications, dose logs & reminders](2026-08-22-mobile-m3-medications-reminders-design.md) | `feature/mobile/medications` | |
| **M4** [Vitals & trend charts](2026-08-22-mobile-m4-vitals-trends-design.md) | `feature/mobile/vitals` | |
| **M5** [Symptoms, activity & guidance](2026-08-22-mobile-m5-symptoms-activity-guidance-design.md) | `feature/mobile/symptoms-activity` | |

### Sequencing

The slices are genuinely parallel with one exception: **M1 is the critical
path for manual end-to-end testing**, because nothing else can obtain a real
token until login exists. Start it first and give it to whoever is fastest.

It does **not** block development. The app is offline-first, so every other
slice's local Drift path, repository logic, controllers and widget tests are
fully buildable and testable without a session; remote datasources are tested
against `FakeDio`. Until M1 lands, `OpenAuthGate` lets every route through, so
the shell runs and screens can be developed against it.

M4's Home card wants profile height for BMI, and M3's cross-signal alert wants
M5's symptom data. Neither is a build-order dependency: both read from Drift
tables that already exist, and both degrade to "—" when the other slice has
not written anything yet. Build for the empty case.

---

## 3. What M0 already gives you

Read this before deciding you need to add something shared.

**Database** — `core/db/tables.dart` declares every table for every slice:
`CachedUsers`, `Preferences`, `PatientProfiles`, `Medications`, `DoseLogs`,
`VitalsLogs`, `SymptomLogs`, `ActivityLogs`, `SyncQueueEntries`. Your tables
exist. Query them with plain Drift from your own local datasource
(`db.select(db.medications)`); no `@DriftAccessor` and no regeneration of a
shared file.

**Sync** — write locally, then `syncEnqueuerProvider.enqueue(...)`. The engine
drains on reconnect, batches to `POST /api/v1/sync`, and maps the server's four
outcomes onto a local lifecycle. You never call the sync endpoint yourself.
`SyncQueueDao.statusFor()` and `.serverIds()` let a history list show per-row
sync state without you storing one.

**Clinical** — `core/clinical/alert_evaluator.dart`. Severity for a vitals
reading, a full symptom assessment, consecutive-miss detection, and the
missed-dose-plus-symptoms cross-signal. All pure functions, all mirroring the
backend exactly. Do not write your own thresholds.

**Router** — `core/router/routes.dart` names every screen in the app,
including ones other slices own, so you can navigate to them without importing
them. `AppRoutes.publicPaths` and the redirect implement the auth gate.

**Shell** — a five-tab frame (Home · Medicines · Vitals · Check-in · Learn).
Home is assembled from `HomeCard`s that features register; that is how five
people each contribute to one dashboard without importing each other.

**Widgets** — `core/widgets/widgets.dart`: `AppScaffold` (+ `.banded`),
`AppButton`, `AppTextField`, `StatusChip`, `SectionCard`, `MetricTile`,
`EmptyState`, `ErrorView`, `LoadingOverlay`, `OfflineBanner`, `ConfirmSheet`.
Build screens out of these.

**Network** — `dioProvider` with the bearer token attached,
`ApiResponse.fromJson` for the envelope, `failureFromDioException` for the
status-to-`Failure` mapping. All 18 paths in `ApiEndpoints`.

**Tests** — `testDatabase()`, `FakeDio`, `pumpApp()`. Use them; `pumpApp` in
particular works around three separate failure modes that otherwise make a
widget test hang with no output at all.

---

## 4. Boundaries

The rules in `mobile/CONTRIBUTING.md` are the contract. The two that cause the most
trouble in parallel work:

**Features never import each other.** If M4's Home card wants the patient's
height, it reads the `PatientProfiles` table, not M2's repository. If M3 wants
to know whether the patient reported chest pain today, it reads `SymptomLogs`,
not M5's controller. Both tables are declared in `core/` and belong to nobody.

**`core/` is not yours to edit.** If something genuinely shared is missing —
a widget a second slice would also want, a helper, a route — ask the
maintainer. Do not add it on your branch: the next person needs it too, and
the same helper landing twice in two places is worse than waiting a day.

**The backend is read-only.** `backend/**` and `database/**` are frozen at
`v1.0.0`. Reading the Java is encouraged — M4 and M5 are explicitly asked to
mirror `VitalThresholds.java` and `SymptomAssessment.java` — but nothing there
changes on a feature branch, for any reason. CI blocks it.

The only shared things you may touch:

- `lib/app/app_wiring.dart` — your marked region: routes, Home card, overrides
- `assets/translations/*.json` — your own top-level namespace only

A PR into `mobile` runs a boundaries check before the tests: it fails if the
diff touches `backend/`, `database/`, `mobile/lib/core/`, `pubspec.yaml`,
`main.dart`, or the platform folders. Review would catch these too, but not
reliably — and a foundation change merged by accident is felt by every other
slice at once.

---

## 5. How to run a slice

Your spec is a design document. Turning it into an executable plan is the
first task, and it is where your engineering judgement shows — the spec
deliberately leaves screen composition, state modelling and task breakdown to
you.

With the assistant tooling the maintainer shares with you:

1. **`/superpowers:brainstorming`** — work through the spec, settle what it
   left open, record decisions and rejected alternatives.
2. **`/superpowers:writing-plans`** — write
   `docs/plans/2026-XX-XX-mobile-m<N>-<slice>.md`: bite-sized TDD tasks, each
   ending green and committed, with a Global Constraints block.
3. **`/superpowers:subagent-driven-development`** — execute task by task.
4. **`/superpowers:requesting-code-review`** — review your own branch first.
5. **`/superpowers:finishing-a-development-branch`** — push, open the PR into
   `mobile`.

Build bottom-up: domain → data → presentation. In an offline-first app the
hard part is the data flow, not the pixels.

---

## 6. Scope decisions that apply to every slice

Recorded in full in `docs/frontend-decisions.md` §8.

| | |
|---|---|
| **D1** | Education, the diet guide and activity guidance are **in scope**, in M5, as bundled offline EN/AM content. Reference links only, no video. |
| **D2** | Local notifications are **in scope**, in M3, alongside medication scheduling. |
| **D3** | Decision support is **in scope** as pure functions in `core/clinical/`, already built. |
| **D4** | **No standalone Alerts screen.** Severity surfaces inline: on entry, as chips in history, and as a Home card. |
| **D5** | **Language is device-local.** `LanguageStore` is authoritative. No backend change. |
| **D6** | Appointments stay dropped. NFR-004 (AES-256 at rest) is a known, accepted gap. |
| **D7** | Home is assembled from a `HomeCard` registry, never from cross-feature imports. |

Still open, and not for a feature branch to settle: self-service PIN reset
(deferred, M1 shows guidance only), SecurityReview **M-2** (7-day tokens, no
revocation) and **M-3** (registration reveals whether a phone is in use).

### Known gaps in the foundation

Maintainer's to-do, not a slice's. Raise them rather than fixing them on a
feature branch.

- **Poppins is fetched at runtime, not bundled.** `google_fonts` downloads the
  font on first use and caches it. A patient whose *first ever* launch is
  offline gets a fallback face instead of the design font — which contradicts
  both offline-first and the "colours and fonts are exact" agreement with the
  designer. The fix is to bundle Poppins and Noto Sans Ethiopic as assets;
  roughly 1 MB against a 50 MB budget (NFR-007). Surfaced by
  `test/app_boot_test.dart`.
- **NFR-004, AES-256 at rest**, is unimplemented — plain Drift today. Deferred
  deliberately: adopting SQLCipher changes the database setup for all five
  slices at once, so it is one coordinated change after the features land.
- **`assets/content/`** is not yet declared in `pubspec.yaml`. M5 needs it
  before starting the education work.
- **The Amharic copy** in `assets/translations/*.json` was written by the
  implementers and has **not been reviewed by a native speaker**. A release
  gate, alongside the clinical thresholds.

---

## 7. Definition of done for the programme

- A patient can register, complete onboarding, and land on a dashboard.
- They can add medicines and log doses; record vitals and see trends; complete
  a symptom check-in and get a recommended action; log activity; read the
  education and diet guidance — **all with the radio off**.
- Reconnecting drains the sync queue with no duplicates and no lost records.
- Every screen renders correctly in English and አማርኛ.
- `flutter analyze` clean, whole suite green, CI passing on `mobile`.
