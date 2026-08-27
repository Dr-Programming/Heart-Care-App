# Mobile Design — M3 Figma Fidelity Rework (Medication Flow)

## 0. How to use this spec

This is a follow-up design to `docs/design/2026-08-22-mobile-m3-medications-reminders-design.md`, written after M3's initial 21-task implementation was complete, reviewed, and running on a real device. It does not replace that spec — it amends the screens/flows below to match the actual Figma design exactly (copy, colors, layout, and two flows the original build was missing), based on a direct comparison against the live Figma file. Everything not listed here (domain layer, sync, offline-first write path, notifications, adherence math, etc.) is unchanged and out of scope for this rework.

**Source of truth:** Figma file `2ulgCN3pghwu6g4bzzi4mw` ("Capstone"), canvas "Medication flow" (node `9:1306`), 5 frames:

| Frame | Node ID | Maps to |
|---|---|---|
| Screen 6.0 | `368:2583` | Medications tab root (empty-afternoon state) |
| Screen 6.1 | `368:2790` | Add medication (search) — **new screen** |
| Screen 6.2 | `368:2706` | Metoprolol 50 mg (dosage/schedule) — existing form, restyled + caregiver field added |
| Screen 6.3 | `368:2651` | Review medication — **new screen** |
| Screen 6.4 | `368:2846` | Medications tab root (populated state, after save) |

Design context (exact copy, colors, spacing) was pulled directly from Figma for frames `368:2583` and `368:2790` via `get_design_context`; the remaining three were read via `get_metadata` (exact text/positions) plus the full-canvas screenshot, and reuse the same color/type tokens confirmed on the first two — no new tokens appear on them.

## 1. Context & goal

The M3 slice (medication CRUD, dose logging, reminders, adherence) was fully implemented, reviewed, and verified running on a real Android device (Galaxy S23 Ultra) before this rework. A direct comparison against the actual Figma design (previously never opened during the build) surfaced real gaps: two missing screens (medication search, review-before-save) and one restructured screen (Today/Schedule/History tabs), plus a caregiver-notify field with no backend counterpart. This spec closes those gaps to bring the built app in line with Figma, without touching anything outside the medication flow.

**Scope: medication flow only.** No other slice's screens, the bottom navigation shell, `lib/core/**`, `backend/**`, or `database/**` are touched.

## 2. Design decisions

### Decision A — Medication search is a bundled static list, not a real drug database

No medication catalog exists in the backend or database (confirmed by reading `backend/src/main/resources/db/migration/V3__create_medications.sql` and `backend/docs/API.md` directly — the `medications` table only stores what a patient is currently taking, and there is no search/catalog endpoint). `MedicationSearchScreen`'s suggestions are powered by a new plain Dart data file (not a JSON asset — see note below), listing ~30-50 common CHD medications (name, typical dose(s), drug class). This is presentation-layer only: picking a suggestion pre-fills the existing add/edit form; saving a medication still goes through the exact same repository → Drift → sync pipeline as today, real database and real backend, unchanged. A medication not in the list is still fully enterable via "Enter manually" or by typing a name the list doesn't suggest.

**Implementation note (found while planning, not during the design conversation):** a `.json` asset would need a new line in `pubspec.yaml`'s `assets:` list (only `assets/translations/` and `assets/images/` are currently registered) — `pubspec.yaml` is off-limits. Ships instead as `lib/features/medication/data/medication_library_data.dart`, a `const List<MedicationLibraryEntry>` — same data, zero pubspec/asset-registration changes, no bundling step. Functionally identical to a JSON asset for this list's size.

### Decision B — Caregiver notify is captured, stored locally, not functional

Figma's dosage screen has a "Notify caregiver if missed" toggle + phone number field. Nothing in the backend, sync contract, or spec supports actually notifying anyone — there's no SMS/push service and no caregiver-contact table. The toggle and phone field are built and their state persists, but only locally, and they do not trigger any real notification yet. Storage: a new `PreferencesDao` key per medication, `m3_caregiver_<clientRecordId>` → JSON `{"enabled": bool, "phone": string}`, using the same local-preferences pattern already established for the pending-edit-set (Task 10) and the reminders-enabled flag (Task 18/final-review fix wave). This does **not** touch `lib/core/db/tables.dart` (the Drift schema) or the backend — it's a pure local-storage addition inside this feature, following an existing pattern rather than inventing a new one.

### Decision C — Reminder-time picker stays flexible, restyled only

The app supports `TID`/`Custom` frequencies with 3+ times a day; Figma's dosage screen only shows a 2-slot ("Morning"/"Evening") toggle UI, which can't represent that. The existing `TimeListField` (add/remove any number of times, already tested, already handles the duplicate-time fix from the earlier build) keeps its behavior. Only its visual styling changes to match Figma's chip/card look (rounded chip, clock icon, `AppColors`/`AppSpacing` tokens matching the rest of the redesign).

### Decision D — Medications screen gets in-page Today/Schedule/History tabs

Matches Figma exactly: a segmented tab control (`Today` / `Schedule` / `History`) inside one `MedicationsScreen`, using `IndexedStack` or equivalent to switch content without re-navigating:
- **Today** — today's doses, current behavior, unchanged logic.
- **Schedule** — the medication list (dose/frequency/next time), reusing the existing `MedicationCard` widget, currently rendered as a flat section below Today.
- **History** — the existing dose-history content (controller, filter, sync status — all already built), embedded as a tab instead of navigated to as a separate screen.

`Adherence` and `Reminder Settings` are not part of this Figma flow at all — they stay reachable via an icon/menu in the app bar, routed through their existing `AppRoutes.adherence`/`AppRoutes.reminderSettings` named routes (already wired in `app_wiring.dart` since Task 20 — this rework does not touch that file again).

### Decision E — New screens use plain push navigation, not new named routes

`core/router/routes.dart` (where `AppRoutes` constants live) is `lib/core/**` — off-limits. `MedicationSearchScreen` and `ReviewMedicationScreen` are reached via ordinary `Navigator.of(context).push(MaterialPageRoute(...))` calls from within the feature (search screen pushed from the "+" action; review screen pushed from the form's save flow), not new `AppRoutes`/`GoRoute` entries. No shared router file changes.

### Decision F — Bottom navigation is explicitly out of scope

Figma's bottom nav shows Home/Meds/Vitals/**Alerts/Appts**; the real app shell has Home/Meds/Vitals/**Check-in/Learn** (Alerts/Appointments were dropped from the whole project's scope before M3 started). The shell lives in `lib/core/shell/`, shared across all 5 slices, off-limits. This rework does not touch it — the Figma frame is stale on this one point, left as a known, out-of-scope mismatch.

### Decision G — Colors and type reuse existing tokens exactly

Every color pulled from Figma's actual node data matches an existing `AppColors` token already used throughout M3 and confirmed against Figma originally:

| Figma hex/value | Existing token | Usage |
|---|---|---|
| `#282a2a` | `AppColors.ink` | Headings, primary text, medication names |
| `#6b7280` | `AppColors.textSecondary` | Subtitles, dose/time captions |
| `#9ca3af` | `AppColors.textTertiary` | Empty-state hints, "SUGGESTIONS" label |
| `#fcab10` | `AppColors.primary` | Add-medication button, selected nav label, selected tab |
| `rgba(156,209,247,0.5)` | `AppColors.accent` at reduced opacity | Top-suggestion highlight, info banners ("Reminders set for...", "Next reminder in...") |

No new color tokens are introduced anywhere; nothing under `lib/core/theme/` is touched. Font is Poppins throughout, already the app's font family (`core/theme`), unchanged.

## 3. Screens (detailed)

### 3.1 `MedicationSearchScreen` (new)

Route: pushed, not named. File: `lib/features/medication/presentation/screens/medication_search_screen.dart`.

- App bar: "Add medication" (title), "Search or enter manually" (subtitle) — `AppScaffold.banded`, matching the existing header-band pattern already used on `MedicationsScreen`.
- Search field (`AppTextField` or equivalent styled to match Figma's rounded search bar with a leading search icon).
- "SUGGESTIONS" label (`AppColors.textTertiary`, small caps).
- Suggestion list: cards from `assets/medication_library.json`, filtered by the search text (case-insensitive substring match on name). Each card: pill icon, name + dose (bold), drug class caption. The single best/first match gets the pale-blue highlight background; others plain white `SectionCard`-style rows. Tapping a card pushes `MedicationFormScreen` pre-filled with that medication's name/dose/class-derived frequency default.
- "Suggestions from offline medication library" caption + "Can't find your medication?" prompt.
- "Enter manually" button (outlined, matches Figma) — pushes `MedicationFormScreen` blank, same as today's "+" behavior.

Test: widget test asserting typing a query filters suggestions, tapping a suggestion navigates to the form pre-filled, "Enter manually" navigates to a blank form.

### 3.2 `MedicationFormScreen` (restyled + one field added)

Existing screen, existing route (`medicationNew`/`medicationEdit`, unchanged — this rework does not touch `app_wiring.dart`). Changes:
- Visual restyle of the dosage/frequency/instructions chip rows to match Figma's exact card/chip look (colors per Decision G, spacing via `AppSpacing`).
- Add the "Notify caregiver if missed" toggle + phone number field (Decision B), persisted via the new `PreferencesDao` key, loaded on `loadForEdit` and on the add path defaulted to off/empty.
- On submit, instead of calling `save()` directly, navigate to `ReviewMedicationScreen` with the current form state; `save()` is called from there.

Test: extend existing `medication_form_controller_test.dart`/`medication_form_screen_test.dart` for the caregiver field's persistence; update the existing "save flow" tests for the new review-screen hop.

### 3.3 `ReviewMedicationScreen` (new)

File: `lib/features/medication/presentation/screens/review_medication_screen.dart`. Pushed from the form, receives the filled-out (not-yet-saved) form data.

- Summary card: medication name/dose/class, frequency, times, instructions, reminder on/off, notify-caregiver on/off — read-only display of what's about to be saved.
- Info banner ("Reminders set for {times} daily" / "Notifications work offline") — pale-blue background per Decision G.
- "Save medication" button — calls the same `MedicationFormController.save()` already built (including its existing error handling from the final-review fix wave), then pops back to `MedicationsScreen` on success exactly as today.
- "Edit details" button — pops back to the form without saving.

Test: widget test asserting the summary reflects the passed-in form state, Save triggers the real save path, Edit details pops without saving.

### 3.4 `MedicationsScreen` (restructured)

- Replace the current flat Today-then-list layout with a segmented `Today`/`Schedule`/`History` tab control (Decision D).
- Today tab: today's doses — existing `DoseRow`/`StatusSelector` logic, unchanged.
- Schedule tab: the medication list — existing `MedicationCard`, unchanged widget, moved under this tab.
- History tab: extract `DoseHistoryScreen`'s current body (everything below its `AppScaffold`/app bar — the filter bar, sync status, list) into a shared private widget, e.g. `_DoseHistoryContent`. The `Today`/`Schedule`/`History` tab embeds that widget directly. `DoseHistoryScreen` itself, and its existing named route (`AppRoutes.doseHistory`, already wired in `app_wiring.dart`), stay exactly as they are — now just a thin wrapper around the same shared content — so no duplicated logic and no route/`app_wiring.dart` change either way.
- App bar gains an overflow/icon action routing to Adherence and Reminder Settings (Decision D) — both already-built screens, already-wired routes.

Test: extend `medications_screen_test.dart` for tab switching, each tab rendering its existing (already-tested) content.

## 4. Testing strategy (TDD, unchanged from the rest of M3)

Same conventions already established: `testDatabase()` for anything touching Drift, `FakeDio`/fakes for anything touching the repository, `pumpApp`/`setUpWidgetTests` for every widget test, real `PreferencesDao` (not mocked) for the caregiver-field persistence tests. New static asset (`medication_library.json`) is loaded and parsed in a plain unit test, no widget needed for that part.

## 5. Explicitly out of scope

- Bottom navigation shell (Decision F).
- Actually sending a caregiver notification (Decision B) — UI + local storage only.
- A real medication database/API (Decision A) — bundled static list only.
- Any change to `lib/core/**`, `backend/**`, `database/**`, `lib/main.dart`, `pubspec.yaml`, `android/**`, `ios/**`.
- Any change to `app_wiring.dart` or the translation files' non-`meds` namespaces (new `meds.*` keys for the new screens/copy are added, same as every prior M3 task).

## 6. Done criteria

- All 5 Figma frames have a corresponding, visually-matching screen/state in the app (colors, copy, layout).
- `flutter analyze` clean, full suite green, no regressions in the 263 existing M3 tests.
- New screens/behavior covered by new tests per §3.
- Caregiver field and medication-library search work end-to-end locally; medication save/sync path is provably unchanged (existing offline-first tests still pass unmodified).
