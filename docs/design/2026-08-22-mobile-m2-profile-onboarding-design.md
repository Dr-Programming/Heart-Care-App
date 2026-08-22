# Mobile Design — M2 (Profile, Onboarding & Settings)

**Date:** 2026-08-22
**Branch:** `feature/mobile/profile`
**Base:** `mobile`
**Status:** Approved for planning
**Depends on:** M0 (merged). Reads M1's session, but is buildable before M1 lands.

---

## 0. How to use this spec

This is a design document, not a plan. Your first task is to turn it into one.

1. `/superpowers:brainstorming` — settle what is left open below.
2. `/superpowers:writing-plans` → `docs/plans/2026-XX-XX-mobile-m2-profile.md`.
3. `/superpowers:subagent-driven-development` — execute task by task.
4. `/superpowers:requesting-code-review`, then
   `/superpowers:finishing-a-development-branch` — PR into `mobile`.

Read `mobile/CLAUDE.md` and `mobile/CONTRIBUTING.md` first. Build bottom-up:
domain → data → presentation.

---

## 1. Context & goal

The patient's clinical profile is the context everything else is read against:
height turns a weight into a BMI, goals turn a reading into progress, and the
comorbidity list is what a clinician would want to see first.

This slice owns three surfaces that are really one feature: the **onboarding
wizard** that collects the profile right after registration, the **profile
screen** that shows and edits it afterwards, and **settings**, which is where
the language toggle and notification preferences live.

### Requirements covered (`FUNCTIONAL_REQUIREMENTS.md` §2, §16)

FR-PROF-001 (name, birth **year**, language), 002 (disease history, CHD
stage), 003 (comorbidities), 005 (management plan), 006 (goals), 007 (update
any time), 008 (stored locally for offline access).

FR-LOC-001/002 (EN + AM), 003 (change language later), 004 (plain language),
005 (icons alongside labels), 006 (44×44 dp targets), 008 (high contrast).

### Deferred / out of scope (and where it lands)

- **FR-PROF-004, lab results** (cholesterol, HbA1c) — cholesterol is a vitals
  type, logged in **M4**. There is no separate labs endpoint; do not invent one.
- **FR-PROF-009, caregiver contact** — P3, no backend field. Drop for MVP.
- **Notification *scheduling*** — the wizard's third step captures the
  patient's preferred reminder times and stores them in `Preferences`;
  **M3** reads them and actually schedules. Do not schedule here.
- **Goal *progress* rendering on Home** — the goals are stored here and M4
  compares readings against them. Your Home card shows the profile summary.

---

## 2. Design decisions

### Decision 1 — Date of birth is a year, and only a year

A scope decision, not a simplification: a full DOB is identifying information
the app has no clinical use for, and asking for it from users with low digital
literacy costs a date picker's worth of friction for nothing. The backend
column is `birth_year`, validated 1900–2100. Collect it as a year — a picker
or a plain numeric field, not a calendar.

### Decision 2 — `PUT /patients/me` is a full replace, so the local row must always be complete

This is the single easiest way to lose a patient's data in this slice. The
endpoint is not a patch: **any field you omit is cleared to null on the
server.** Editing only the height and sending `{heightCm: 172}` erases the
comorbidities, the management plan and every goal.

So: load the complete profile from Drift, apply the change, send the whole
thing. Model it as one immutable profile object that the edit screen replaces
wholesale, and make it structurally impossible to build a partial request.

### Decision 3 — `GET /patients/me` never 404s, so absence is a shape, not an error

An unsaved profile comes back as a `200` with every field null and
`comorbidities: []`. Treat "no profile yet" as a valid, empty profile rather
than an error state. The profile screen shows empty slots with a prompt to
fill them in; it does not show an error.

### Decision 4 — The wizard is skippable and resumable, and writes once at the end

Blocking a patient inside a three-step medical questionnaire before they can
see the app is the fastest way to lose them. Every step is skippable, and the
whole wizard can be dismissed to Home.

Keep the in-progress answers in `Preferences` (or in controller state persisted
on each step) so killing the app mid-wizard does not lose them, but write the
profile — locally, then enqueued — **once, on finish or skip-to-end**. A
partial profile written on step 1 would be a full-replace request that wipes
what step 2 was about to add.

Clear the `needsOnboarding` flag on completion **or** on skip; otherwise the
router traps the patient in the wizard forever.

### Decision 5 — Language changes take effect immediately and are device-local

Decision D5 for the programme: `LanguageStore` is authoritative. The toggle
writes there and calls `context.setLocale(...)`; the app re-renders, including
the font family, because Poppins has no Ethiopic glyphs and the theme swaps to
Noto Sans Ethiopic.

Also write the choice into `preferredLanguage` on the profile so the value the
server holds is not stale — but never read it back to decide what to render.
The device wins. There is no `PATCH /users/me/language`; do not ask for one.

### Decision 6 — Comorbidities are a curated list plus free text

A free-text-only field produces "sukar", "ስኳር" and "diabetes" as three
different conditions and is useless to aggregate. Offer the common ones as
selectable chips — diabetes, hypertension, kidney disease, high cholesterol,
previous heart attack, stroke — with an "other" free-text entry. The wire
format is a plain JSON array of strings either way.

The list is UI-side and needs both EN and AM labels; store a stable English
value and translate for display.

### Decision 7 — Accessibility is this slice's job for the whole app

Someone has to own FR-LOC-004 to 008 and it is naturally the person building
settings. `AppButton` and the nav bar already guarantee 44dp targets and the
palette is already high-contrast; your job is to audit, fix what you find in
your own screens, and report anything in `core/` to the maintainer rather than
patching it yourself.

---

## 3. Screens

| Screen | Route | Source | Contents | States |
|---|---|---|---|---|
| **Onboarding 1 — personal** | `AppRoutes.onboarding` | Figma Onboarding 1 | Name (prefilled from the session), birth year, height | idle · validating |
| **Onboarding 2 — medical** | step 2 | Figma Onboarding 2 | CHD stage, disease history, comorbidity chips + other | idle · validating |
| **Onboarding 3 — goals & reminders** | step 3 | Figma Onboarding 3 | Target BP, weight, steps/day, cholesterol, diet note; reminder times; notifications on/off | idle · submitting · offline (still succeeds — writes locally) |
| **Profile** | `AppRoutes.profile` | Figma Profile | Read-only summary of everything, grouped; edit and settings entry points; sign out | loading · empty (nothing saved) · loaded |
| **Profile edit** | `AppRoutes.profileEdit` | — | The same fields as the wizard, as one form | idle · validating · saving |
| **Settings** | `AppRoutes.settings` | — | Language toggle, notification preferences, sync status + "send now", app version, sign out | idle |

One wizard route with internal steps is simpler than three routes and makes
back-navigation between steps free — but that is your call to make in the plan.

Build from `AppScaffold`, `AppTextField`, `AppButton`, `SectionCard`,
`MetricTile`, `EmptyState`. Progress through the wizard needs an indicator;
if it is genuinely reusable, ask the maintainer rather than adding to `core/`.

Copy goes in the `profile.*` namespace of `assets/translations/*.json`.
`profile.title` already exists. Check every screen in Amharic — this slice has
the most labels in the app and they are all longer in Amharic.

---

## 4. API contract

From `backend/docs/API.md` §2. **Success is always `200`.** Envelope as usual.

### `GET /api/v1/patients/me` — authenticated

Never 404s. An unsaved profile returns a full null skeleton:

```jsonc
{ "birthYear": null, "preferredLanguage": null, "heightCm": null,
  "chdStage": null, "diseaseHistory": null, "comorbidities": [],
  "managementPlan": null, "goals": null }
```

### `PUT /api/v1/patients/me` — authenticated

**Full replace. Omitted fields are cleared to null.**

```jsonc
{
  "birthYear": 1968,              // 1900-2100
  "preferredLanguage": "am",      // en | am
  "heightCm": 172,                // 50-250
  "chdStage": "Stable angina",    // <= 50 chars
  "diseaseHistory": "Diagnosed 2019, one stent.",
  "comorbidities": ["diabetes", "hypertension"],
  "managementPlan": "Aspirin, statin, cardiac rehab twice weekly.",
  "goals": {
    "bpSystolic": 130, "bpDiastolic": 80, "totalCholesterol": 4.5,
    "stepsPerDay": 6000, "targetWeightKg": 78, "dietNote": "Less salt"
  }
}
```

Message on success: `"Profile saved"`. `400` returns every violated field in
one message, `field: message` joined by `; ` and sorted.

Mirror the server's ranges client-side so a patient is told before the request
is made, not after.

---

## 5. Local state & offline behaviour

**Table:** `PatientProfiles`, one row keyed by user id. `comorbiditiesJson`
and `goalsJson` hold JSON; everything else is typed.

**Preferences keys** (already declared in `core/db/tables.dart`):
`language`, `languageChosen`, `notificationsEnabled`, `symptomPromptTime`.

**Write path** — Drift first, then `syncEnqueuerProvider.enqueue(...)`. The
profile is not one of the five `SyncEntityType` values the sync endpoint
accepts (`VITAL | SYMPTOM | ACTIVITY | MEDICATION | DOSE_LOG`), which means
**profile changes cannot go through the batch sync endpoint.**

Handle it explicitly: write locally and always succeed, then attempt
`PUT /patients/me` opportunistically. If that fails, mark the local row dirty
and retry when connectivity returns. Say how in your plan — this is the one
genuinely novel piece of data plumbing in the slice, and the reviewer will
look at it first.

**Read path** — always from Drift. `GET /patients/me` refreshes the local row
when online; it never gates rendering.

Other slices read `PatientProfiles` directly for height and goals. Keep the
row complete and current; do not hide it behind a repository only you can use.

---

## 6. Feature layout

```
lib/features/profile/
  profile_providers.dart
  domain/
    entities/{patient_profile,health_goals}.dart
    repositories/profile_repository.dart
    usecases/{get_profile,save_profile,set_language}.dart
    validators.dart
  data/
    models/patient_profile_model.dart        freezed + json
    datasources/profile_remote_datasource.dart
    datasources/profile_local_datasource.dart
    repositories/profile_repository_impl.dart
  presentation/
    controllers/{onboarding_controller,profile_controller,settings_controller}.dart
    screens/{onboarding,profile,profile_edit,settings}_screen.dart
    widgets/{comorbidity_chips,year_field,goal_field,wizard_progress}.dart
    home/profile_home_card.dart              order 300
```

Register in `lib/app/app_wiring.dart`, `M2 profile` region: four routes in
`topLevel`, and your Home card.

---

## 7. Files this slice may NOT touch

`lib/core/**` · `lib/main.dart` · `pubspec.yaml` · `tables.dart` ·
`api_endpoints.dart`. `PatientProfiles`, the `Preferences` keys,
`ApiEndpoints.patientMe` and `LanguageStore` all already exist.

Allowed, in your marked region only: `lib/app/app_wiring.dart`, and the
`profile.*` namespace in `assets/translations/*.json`.

Do not implement `AuthGate` or touch the session — that is M1. You read
`cachedUserProvider` for the user's id and name.

---

## 8. Testing strategy (TDD)

**`validators_test`** — birth year inside and outside 1900–2100 and the
current year; height 50–250 inclusive; CHD stage over 50 characters; goal
values non-negative; every failure returns a key that exists in `en.json`.

**`profile_local_datasource_test`** (`testDatabase()`) — round-trips a full
profile including comorbidities and goals; an empty comorbidity list survives;
null goals survive; saving twice replaces rather than accumulating.

**`profile_remote_datasource_test`** (`FakeDio`) — `GET` parses the all-null
skeleton without throwing; `PUT` sends **every** field, including the ones the
user did not change; unwraps a **200**.

**`profile_repository_impl_test`** — saving while offline writes locally,
enqueues or marks dirty, and makes no request; saving while online writes
locally *and* PUTs; a failed PUT leaves the local row intact and still dirty;
a `400` surfaces as `ValidationFailure` with the server's field list.

**`onboarding_controller_test`** — answers survive a step change; skipping
step 2 still produces a valid profile; finishing clears `needsOnboarding`;
**skipping also clears it** (the trap: otherwise the router loops).

**`settings_controller_test`** — the language toggle writes `LanguageStore`
and updates the profile's `preferredLanguage`; it does **not** read the server
value back.

**Widget tests** (`pumpApp`) — the wizard advances and goes back with answers
intact; an invalid birth year blocks the step; the profile screen shows the
empty state with nothing saved and the summary with a profile; the edit form
prefills every field; the language toggle re-renders in Amharic (assert with
`language: AppLanguage.am` and after toggling); tap targets on settings rows
are at least 44dp.

---

## 9. "Done" criteria

- A newly registered patient is taken into the wizard, can complete or skip
  it, and reaches Home either way — and is not sent back into it on relaunch.
- The profile screen shows everything the patient entered, and an inviting
  empty state when they entered nothing.
- Editing one field and saving **does not clear any other field** — verified
  by a test and by hand against a running backend.
- The whole flow works with the radio off; changes reach the server after
  reconnecting.
- The language toggle switches the app between English and አማርኛ immediately,
  including the font, and survives a relaunch.
- Every screen renders correctly in both languages; touch targets are ≥44dp.
- `flutter analyze` clean; whole suite green; CI passing.

---

## 10. Handover checklist

- [ ] Plan committed to `docs/plans/`
- [ ] `flutter analyze` clean, `flutter test` green
- [ ] Ran the app against a local backend; specifically verified that a
      single-field edit preserves the rest of the profile
- [ ] No edits to shared files outside the marked regions
- [ ] Screenshots in the PR, English and Amharic
- [ ] No AI co-author trailer on any commit
- [ ] PR into `mobile`, title `feat(mobile): M2 — Profile, onboarding & settings`
- [ ] Told M3 which `Preferences` keys hold the reminder times
