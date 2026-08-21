# CLAUDE.md — Libu Care mobile app

Guidance for Claude Code when working anywhere under `mobile/`. These rules
override default behaviour. Read `mobile/CONTRIBUTING.md` before your first
commit; it has the workflow, this has the rules.

## What this is

The Flutter client for Heart-Care-App: offline-first coronary heart disease
self-management for patients in Ethiopia. Bilingual English / አማርኛ. Patient
role only — there is no clinician, no appointments, no real-time alerting.

The backend is **finished and frozen** at `v1.0.0` (253 tests, 18 endpoints).
`backend/docs/API.md` is the contract. Do not change backend code to make a
frontend problem easier; raise it with the maintainer instead.

## Your slice

The frontend is split into five feature slices, one owner each. Your slice's
spec is in `docs/design/2026-08-22-mobile-m*-design.md`. Build **only** what
that spec covers. If you find yourself needing something from another slice,
that is a signal you are about to break architectural rule #1 — see below.

## Architecture

Feature-first clean architecture. Every feature is self-contained:

```
lib/features/<feature>/
  data/         models (freezed/json) · datasources (local Drift, remote Dio) · repositories
  domain/       entities · repository interfaces · use cases
  presentation/ controllers (Riverpod) · screens · widgets
```

**The four rules. A reviewer will reject violations.**

1. **Features never import each other.** Not the entity, not the provider, not
   the widget. Cross-feature needs go through `core/` or through the Home card
   registry. `lib/app/app_wiring.dart` is the only place features meet.
2. **`core/` never imports `features/`.** If core seems to need a feature, the
   dependency is inverted — declare an interface in core and implement it in
   the feature (`AuthGate` is the worked example).
3. **Local and remote datasources are always separate classes.** No
   `if (online)` inside a datasource. The repository decides.
4. **All API URLs live in `core/constants/api_endpoints.dart`.** Never write a
   path literal in a datasource.

## Offline-first is not a feature, it is the default

The device is the source of truth. Every user action must work with the radio
off.

- Write to Drift **first**, then enqueue for sync. Never await the network on
  a user action.
- Mint a `client_record_id` with `newClientRecordId()` at capture time. It is
  the server's idempotency key — never regenerate it on retry.
- Enqueue through `SyncEnqueuer` (`syncEnqueuerProvider`). Do not call
  `POST /api/v1/sync` yourself; `core/sync` owns that.
- Reads come from Drift, not from the API. A screen that shows a spinner when
  offline is a bug.

## Shared files you must not edit

These belong to the foundation. Needing a change to one is a request to the
maintainer, not an edit on your branch.

- `lib/core/**` — theme, db schema, network, sync, router, widgets, shell
- `lib/core/db/tables.dart` and `app_database.dart` — the schema is complete;
  every table you need already exists
- `lib/core/constants/api_endpoints.dart` — all 18 paths are already declared
- `pubspec.yaml` — every dependency any slice needs is already resolved
- `lib/main.dart`

Two shared files you *may* edit, only inside your own marked region:

- `lib/app/app_wiring.dart` — register your routes, Home card and overrides
- `assets/translations/en.json` and `am.json` — your own top-level namespace
  only (`meds.*`, `vitals.*`, …). Never touch another slice's block or the
  shared `common.*` / `errors.*` / `clinical.*` blocks.

## Stack

Riverpod (state **and** DI — no `get_it`) · go_router · Drift · Dio ·
flutter_secure_storage · connectivity_plus · easy_localization · google_fonts
(Poppins) · iconsax · freezed + json_serializable · fl_chart ·
flutter_local_notifications · mocktail.

## Design fidelity

Colours and fonts from the Figma file are **exact and contractual**; layout and
composition are yours. Never write a raw hex — use `AppColors`. Never set a
font — use the theme. Build screens out of `core/widgets/` so five people's
work still looks like one app.

Amharic needs Noto Sans Ethiopic; Poppins has no Ethiopic glyphs. The theme
already handles this. Test at least one screen in Amharic — the strings are
longer and overflow fixed-width layouts.

## Testing

TDD. Logic first (pure Dart, test-driven), then wire the UI.

- `test/helpers/` has everything: `testDatabase()`, `FakeDio`, `pumpApp()`.
  Use them. `pumpApp` in particular works around three separate traps that
  otherwise make widget tests hang with no output.
- Real in-memory Drift, never a mocked database.
- `FakeDio` over a mocked Dio — the real client keeps its interceptors and
  error mapping, which is the code most likely to be wrong.
- `mocktail` for mocks. No build_runner-generated mocks.
- Cover the offline path explicitly: a repository test that proves the write
  landed locally and no request was made.

## Before every commit

```bash
cd mobile
dart run build_runner build          # if you touched a freezed/json model
flutter analyze                      # must print: No issues found!
flutter test                         # must be all green
```

Conventional commits, scope `mobile`: `feat(mobile): …`, `test(mobile): …`,
`fix(mobile): …`, `chore(mobile): …`.

**Never add an AI co-author trailer to a commit.** The author is the human
whose branch it is.

## Clinical content

Thresholds in `core/clinical/alert_evaluator.dart` mirror the backend exactly
and are documented defaults **pending clinical sign-off**. Do not invent a
threshold, and do not "improve" one — if the client and server disagree, a
reading changes severity after it syncs. Amharic clinical copy needs
native-speaker review before release; flag new strings rather than assuming
they are final.
