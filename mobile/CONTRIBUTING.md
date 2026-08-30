# Contributing — Libu Care mobile

The one document you need before writing code. Read it once end to end; it is
the contract a reviewer will hold you to.

The Flutter client for Heart-Care-App: offline-first coronary heart disease
self-management for patients in Ethiopia. Bilingual English / አማርኛ. Patient
role only — no clinician, no appointments, no real-time alerting.

The backend is **finished, frozen at `v1.0.0`, and read-only to you**
(253 tests, 18 endpoints). `backend/docs/API.md` is the contract.

Read-only means exactly that — **reading it is encouraged**. When your spec
says the client must mirror `SymptomAssessment.java` or `VitalThresholds.java`,
open them. Understanding why the server answers the way it does is often the
fastest route to a frontend bug.

What you must never do is **change** anything under `backend/` or `database/`,
for any reason, including "it was a one-line fix". CI blocks it. If the
backend is genuinely wrong or missing something, that is a conversation with
the maintainer — reopening a released API affects all five slices and 253
passing tests.

---

## 1. Set up

```bash
git clone https://github.com/Dr-Programming/Heart-Care-App.git
cd Heart-Care-App
git checkout mobile
cd mobile
flutter pub get
dart run build_runner build          # REQUIRED
flutter analyze                      # expect: No issues found!
flutter test                         # expect: all green
```

**`build_runner` is not optional.** Generated files (`*.g.dart`,
`*.freezed.dart`) are gitignored, so a fresh clone will not compile until you
run it. Re-run it whenever you add or change a freezed model. Do **not** pass
`--delete-conflicting-outputs` — it was removed from this build_runner version
and only prints a warning.

Run against a local backend:

```bash
# from the repo root, in another terminal
docker compose up -d
mvn -f backend/pom.xml spring-boot:run

# then
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` is the Android emulator's alias for your machine's localhost. On a
physical device use your machine's LAN IP.

---

## 2. Branches

```
main                                  release only
└── dev                               integration
    └── mobile                        the foundation + where your work lands
        ├── feature/mobile/auth
        ├── feature/mobile/profile
        ├── feature/mobile/medications
        ├── feature/mobile/vitals
        └── feature/mobile/symptoms-activity
```

```bash
git checkout mobile
git pull
git checkout -b feature/mobile/<your-slice>
```

Branch from `mobile`, PR into `mobile`. Never PR into `dev` or `main`. Merge
`mobile` into your branch regularly — a week-old branch is a week of conflicts.

**No branch is mechanically protected.** Branch protection needs a paid plan
on a private repository, so nothing stops a bad merge except us. Two rules
follow, and they are not optional:

- **Never merge a red PR.** CI runs a boundaries check and the full suite on
  every PR into `mobile`. A red X means it would break someone else's slice.
- **Never push directly to `mobile`, `dev` or `main`.** Those are the
  maintainer's. Your work reaches `mobile` through a PR, always.

---

## 3. Your slice

Five feature slices, one owner each. The index is
`docs/design/2026-08-22-mobile-frontend-program.md`.

| Slice | Your branch | Your spec (in `docs/design/`) |
|---|---|---|
| **M1** Auth & session | `feature/mobile/auth` | `2026-08-22-mobile-m1-auth-design.md` |
| **M2** Profile, onboarding & settings | `feature/mobile/profile` | `2026-08-22-mobile-m2-profile-onboarding-design.md` |
| **M3** Medications, dose logs & reminders | `feature/mobile/medications` | `2026-08-22-mobile-m3-medications-reminders-design.md` |
| **M4** Vitals & trend charts | `feature/mobile/vitals` | `2026-08-22-mobile-m4-vitals-trends-design.md` |
| **M5** Symptoms, activity & guidance | `feature/mobile/symptoms-activity` | `2026-08-22-mobile-m5-symptoms-activity-guidance-design.md` |

Who owns which slice is in [SLICE_OWNERS.md](SLICE_OWNERS.md) — keep the
Status column there current as you go.

Build **only** what your spec covers. Needing something from another slice is
a signal you are about to break rule 1 below.

### Your first session

Before writing any code, get your assistant oriented. Ask the maintainer for
the plugin configuration, then open the repository and start with something
like this — substituting your own slice number, name, branch and spec file:

```text
I am building slice M4 (Vitals & Trend Charts) of the Libu Care Flutter app,
on branch feature/mobile/vitals. Five developers are each building one slice
in parallel off the `mobile` branch.

Before anything else, read these three files in full:
  - mobile/CONTRIBUTING.md                                   (the rules I must follow)
  - docs/design/2026-08-22-mobile-frontend-program.md        (how the slices fit together)
  - docs/design/2026-08-22-mobile-m4-vitals-trends-design.md (my slice spec)

Then explore lib/core/ so you know what the foundation already provides —
especially core/db/tables.dart, core/sync/, core/clinical/, core/widgets/,
core/router/routes.dart and test/helpers/.

Then write a CLAUDE.md at the repository root capturing what a future session
needs: the architecture rules, the shared files I may not edit, the
offline-first write path, the API contract traps, the testing helpers and
toolchain gotchas, and — most importantly — the specifics of MY slice: which
tables, endpoints, routes, translation namespace and core helpers are mine,
and what belongs to other slices. Keep it concise; it is loaded into every
prompt.

Do not write any feature code yet. After CLAUDE.md, stop and confirm your
understanding of my slice's scope and boundaries.
```

`CLAUDE.md` is gitignored at every depth, so the file this produces stays on
your machine and cannot be committed by accident. Write your own rather than
copying someone else's: a file that says *"`VitalsLogs` is yours; `SymptomLogs`
belongs to M5 — read the table directly, never import their code"* is what
actually stops boundary violations.

Regenerate it if your understanding of the slice changes materially. It is
notes to your future self, not a deliverable.

---

## 4. Architecture — the rules

Feature-first clean architecture. Every feature is self-contained:

```
lib/features/<feature>/
  data/         models (freezed/json) · datasources (local Drift, remote Dio) · repositories
  domain/       entities · repository interfaces · use cases
  presentation/ controllers (Riverpod) · screens · widgets
```

**A reviewer will reject violations of these.**

1. **Features never import each other.** Not the entity, not the provider, not
   the widget. Cross-feature data goes through a `core/db` table (they belong
   to nobody) or the Home card registry.
2. **`core/` never imports `features/`.** If core seems to need a feature, the
   dependency is inverted — declare an interface in core and implement it in
   the feature. `AuthGate` is the worked example.
3. **Local and remote datasources are always separate classes.** No
   `if (online)` inside a datasource. The repository decides.
4. **All API URLs live in `core/constants/api_endpoints.dart`.** Never write a
   path literal in a datasource. All 18 are already declared.
5. **Shared files are complete already** — the Drift schema, every API path,
   every dependency, the whole route table. You edit only your own folder.
   This is what makes five parallel branches possible.
6. **`lib/app/app_wiring.dart` is the only place features meet.**

### Shared files you must not edit

Needing a change to one of these is a request to the maintainer, not an edit
on your branch. The next person needs it too, and the same helper landing
twice in two places is worse than waiting a day.

- `backend/**` and `database/**` — **read-only**, frozen at `v1.0.0`
- `lib/core/**` — theme, db schema, network, sync, router, widgets, shell
- `lib/core/db/tables.dart`, `app_database.dart` — every table you need exists
- `lib/core/constants/api_endpoints.dart`
- `pubspec.yaml` — every dependency any slice needs is already resolved
- `lib/main.dart`
- `android/**`, `ios/**` — platform config; a permission entry is a request

Two you *may* edit, inside your own marked region only:

- `lib/app/app_wiring.dart` — your routes, Home card, provider overrides
- `assets/translations/en.json` and `am.json` — your own top-level namespace
  (`meds.*`, `vitals.*`, …). Never another slice's block, and never the shared
  `common.*` / `errors.*` / `clinical.*` blocks.

---

## 5. Offline-first is not a feature, it is the default

The device is the source of truth. Every user action must work with the radio
off.

- Write to Drift **first**, then enqueue for sync. Never await the network on
  a user action.
- Mint a `client_record_id` with `newClientRecordId()` at capture time. It is
  the server's idempotency key — never regenerate it on retry.
- Enqueue through `SyncEnqueuer` (`syncEnqueuerProvider`). Do not call
  `POST /api/v1/sync` yourself; `core/sync` owns draining the queue.
- Reads come from Drift, not the API. A screen that shows a spinner when
  offline is a bug.

The one exception in the whole app is first-time login, which genuinely cannot
work offline.

---

## 6. Stack and design fidelity

Riverpod (state **and** DI — no `get_it`) · go_router · Drift · Dio ·
flutter_secure_storage · connectivity_plus · easy_localization · google_fonts
(Poppins) · iconsax · freezed + json_serializable · fl_chart ·
flutter_local_notifications · mocktail.

Colours and fonts from the Figma file are **exact and contractual**; layout
and composition are yours. Never write a raw hex — use `AppColors`. Never set
a font — use the theme. Build screens out of `core/widgets/` so five people's
work still looks like one app.

Amharic needs Noto Sans Ethiopic; Poppins has no Ethiopic glyphs. The theme
handles it. Check at least one screen in Amharic — the strings are longer and
overflow layouts tuned to English.

---

## 7. How to build your slice

Your spec is a design document. Turning it into a plan is your first task, and
it is where your judgement shows.

With Claude Code and the plugin set the maintainer shares with you:

1. `/superpowers:brainstorming` — work through the spec, settle what it leaves
   open, record decisions.
2. `/superpowers:writing-plans` — produce
   `docs/plans/2026-XX-XX-mobile-m<N>-<slice>.md`. Bite-sized TDD tasks, each
   ending green and committed.
3. `/superpowers:subagent-driven-development` — execute it task by task.
4. `/superpowers:requesting-code-review` — review your own branch first.
5. `/superpowers:finishing-a-development-branch` — push and open the PR.

### Order of work

Build bottom-up. It is tempting to start with screens; don't.

1. **domain** — entity, repository interface, use cases. Pure Dart, no Flutter
   import, fully testable.
2. **data** — freezed models, remote datasource (Dio), local datasource
   (Drift), repository implementation. This is where offline-first lives and
   where the hard bugs are.
3. **presentation** — controller, then screens.

In an offline-first app the hard part is the data flow, not the pixels.

---

## 8. The canonical layer template

Copy this shape. Names change, structure does not.

```dart
// domain/entities/vital_reading.dart  — no JSON, no Drift, no Flutter
class VitalReading {
  const VitalReading({required this.clientRecordId, required this.type, ...});
  final String clientRecordId;
  final VitalType type;
}

// domain/repositories/vitals_repository.dart
abstract interface class VitalsRepository {
  /// Returns a value or throws a [Failure]. Never returns null for an error.
  Future<void> log(VitalReading reading);
  Stream<List<VitalReading>> watchHistory({VitalType? type});
}

// domain/usecases/log_vital.dart  — thin, one job
class LogVital {
  const LogVital(this._repository);
  final VitalsRepository _repository;
  Future<void> call(VitalReading reading) => _repository.log(reading);
}

// data/models/vital_model.dart  — freezed; toEntity() / toCompanion() / toJson()
// data/datasources/vitals_remote_datasource.dart  — Dio only, unwraps ApiResponse
// data/datasources/vitals_local_datasource.dart   — Drift only

// data/repositories/vitals_repository_impl.dart
class VitalsRepositoryImpl implements VitalsRepository {
  @override
  Future<void> log(VitalReading reading) async {
    await _local.insert(reading);                 // 1. device first, always
    await _sync.enqueue(                          // 2. then owe it to the server
      clientRecordId: reading.clientRecordId,
      entityType: SyncEntityType.vital,
      payload: VitalModel.fromEntity(reading).toJson(),
      recordedAt: reading.measuredAt,
    );
  }                                               // never awaits the network
}

// presentation/controllers/vitals_controller.dart
class VitalsController extends AsyncNotifier<VitalsState> { ... }
```

Note what the repository does **not** do: it does not check connectivity and
it does not call the API. Writes go local-then-queue, unconditionally.

---

## 9. Traps in the API contract

From `backend/docs/API.md`. Each of these has bitten someone already.

- **Success is always `200`.** There is no `201`, not even for creates.
- Every response is wrapped in `{success, data, message, timestamp}`. Unwrap
  with `ApiResponse.fromJson` before touching `data`.
- `PUT /patients/me` is a **full replace** — omitted fields are cleared to
  null. Always send the complete profile.
- `404` also means "exists but belongs to another user". Never `403`.
- `GET /dose-logs?medicationId=<unknown-but-valid-uuid>` returns `200 []`.
- The `423` lockout message is singular on the final minute ("1 minute").
  Parse with `parseLockoutMinutes`, which handles it.
- Retry only `500`. `400/404/405/409/413` are permanent; `423` is temporary
  but must not be retried on a timer.

---

## 10. Testing

TDD. Logic first (pure Dart, test-driven), then wire the UI.

- `test/helpers/` has everything: `testDatabase()`, `FakeDio`, `pumpApp()`.
  **Use them** — see the gotchas below for why.
- Real in-memory Drift, never a mocked database.
- `FakeDio` over a mocked Dio: the real client keeps its interceptors and
  error mapping, which is the code most likely to be wrong.
- `mocktail` for mocks. No build_runner-generated mocks.
- Cover the offline path explicitly — a repository test proving the write
  landed locally and **no request was made**.

### Toolchain gotchas

These cost real time to diagnose, and each presents as something other than
what it is.

- **Widget tests hang with no output at all** — not a failure, no message —
  unless `setUpWidgetTests()` and `pumpApp()` are used. Three independent
  causes (google_fonts fetching the font at runtime, Drift's cleanup timer,
  easy_localization's real async). All handled there; read the comments in
  `test/helpers/pump_app.dart` before writing your own harness.
- **Riverpod 3:** `Override` is exported from
  `package:flutter_riverpod/misc.dart`, not the main barrel.
  `StreamProvider.stream` no longer exists — watch the underlying provider.
  `WidgetRef` is not a `Ref`; anything needing a real `Ref` goes in a provider.
- **Drift:** a `where` callback is typed with the *generated* table class
  (`($MedicationsTable t) => ...`), not the `Table` subclass — otherwise
  `equalsValue` and the typed columns are "not found".
- **Windows:** killing a test run orphans `flutter_tester`, which locks
  `build/native_assets/windows/sqlite3.dll`. Every later run then fails with
  a file-permission error that points nowhere near the real cause. Fix:
  `Get-Process flutter_tester | Stop-Process -Force`.

---

## 11. Clinical content

Thresholds in `core/clinical/alert_evaluator.dart` mirror the backend
(`SymptomAssessment.java`, `VitalThresholds.java`) **exactly**. Do not invent
a threshold and do not "improve" one: if the client and server disagree, a
reading changes severity after it syncs, which is the worst possible
behaviour for clinical information.

They are documented defaults **pending clinical sign-off** — not approved
clinical guidance. Amharic clinical copy needs native-speaker review before
release; flag new strings rather than assuming they are final.

The app must not diagnose and must not tell anyone not to seek help. Use the
approved action strings; do not improvise clinical instructions.

---

## 12. Before every commit

```bash
cd mobile
dart run build_runner build          # if you touched a freezed/json model
flutter analyze                      # must print: No issues found!
flutter test                         # must be all green
```

`flutter analyze` fails on info-level lints too, and CI additionally runs
`dart format --set-exit-if-changed lib test`.

Conventional commits, scope `mobile`: `feat(mobile): …`, `test(mobile): …`,
`fix(mobile): …`, `chore(mobile): …`.

**Never add an AI co-author trailer to a commit.** The author is the human
whose branch it is.

---

## 13. Pull requests

Title: `feat(mobile): M<N> — <slice name>`. In the description:

- what the slice delivers, against its spec's "Done criteria"
- anything you deliberately left out, and why
- screenshots for new screens, English and Amharic

Before you open it:

- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] you ran the app and used the feature, including with the radio off
- [ ] no edits to shared files outside your marked region
- [ ] nothing under `backend/` or `database/` changed
- [ ] no AI co-author trailer on any commit

Request review from the maintainer plus `j444cky`. The maintainer merges.

---

## 14. When you are stuck

- The spec is wrong or incomplete → say so in the PR or an issue. Specs are
  drafts, not scripture.
- You need something from `core/` that isn't there → ask. Do not add it on
  your branch.
- You need a backend change → almost certainly no, but ask. The API is frozen
  at `v1.0.0`, the backend is read-only to you, and reopening it affects all
  five slices. In most cases what looks like a missing endpoint is a shape the
  client should derive locally instead.
