# Mobile Design — M5 (Symptoms, Activity & Guidance)

**Date:** 2026-08-22
**Branch:** `feature/mobile/symptoms-activity`
**Base:** `mobile`
**Status:** Approved for planning
**Depends on:** M0 (merged). Reads `DoseLogs` for one cross-signal; degrades safely without them.

---

## 0. How to use this spec

This is a design document, not a plan. Your first task is to turn it into one.

1. `/superpowers:brainstorming` — settle what is left open below.
2. `/superpowers:writing-plans` → `docs/plans/2026-XX-XX-mobile-m5-symptoms-activity.md`.
3. `/superpowers:subagent-driven-development` — execute task by task.
4. `/superpowers:requesting-code-review`, then
   `/superpowers:finishing-a-development-branch` — PR into `mobile`.

Read `mobile/CONTRIBUTING.md` first. Build bottom-up:
domain → data → presentation.

---

## 1. Context & goal

Three things that belong together because they share one idea: *what the
patient does between clinic visits, and what they need to know to do it
safely.*

The **daily symptom check-in** is the app's early-warning system. **Activity
logging** tracks the exercise that is a first-line CHD intervention. The
**guidance content** — CHD facts, heart attack warning signs, safe exercise,
the Ethiopian diet guide, medication adherence, psychosocial wellbeing — is
what makes the numbers actionable, and it is the only part of the app that
works with no account at all.

Neither symptoms nor activity has a Figma screen. **You are designing them
from scratch**, within the colour and type system. That is real design work,
not a gap in the spec.

### Requirements covered (`FUNCTIONAL_REQUIREMENTS.md` §3, §6, §7, §8)

**Symptoms** FR-SYM-001 to 007 (daily check-in: chest pain + severity,
shortness of breath, resting HR, BP, swelling, energy 0–10), 008 ("worse than
yesterday?"), 009 (history), 010 (interpretation and recommended action), 011
(local, synced).

**Activity** FR-ACT-001 (guidelines), 002 (indications to terminate activity),
003 (log type, duration, intensity), 004 (culturally relevant suggestions),
005 (offline), 006 (history).

**Education** FR-EDU-001 to 011, including the Quiz (008), fully offline (009)
and in both languages (010).

**Diet** FR-DIET-001 to 005, 007, 008.

**Decision support** FR-DEC-003 (missed doses + cardiac symptoms), 008
(emergency on severe chest pain), 009 (recommended action per alert), 011
(entirely offline).

### Deferred / out of scope (and where it lands)

- **FR-ACT-007, steps-goal progress** — P3. The goal is stored by **M2**; show
  progress only if the rest lands comfortably.
- **FR-DIET-006, meal logging** — P3, no backend. Drop for MVP.
- **FR-GRAPH-005, activity trend chart** — **M4** owns charts. Coordinate;
  do not build a second chart widget.
- **FR-EDU-012, server-updatable content** — voided in the requirements.
  Content is bundled at build time.
- **A standalone Alerts screen** — programme decision D4. Severity surfaces
  inline and on Home.

---

## 2. Design decisions

### Decision 1 — The check-in is one screen, not a seven-step wizard

It is meant to be completed *daily*. A wizard that takes seven taps to say
"I'm fine" will be abandoned inside a week, and an abandoned check-in produces
no early warning at all.

One scrollable form, sensible defaults for the common answer (no chest pain,
no breathlessness, no swelling), with severity and detail revealed only when
a symptom is reported. "I'm fine today" should be two taps.

### Decision 2 — Severity is computed by the shared evaluator, and the server agrees by construction

`assessSymptoms` in `core/clinical/alert_evaluator.dart` mirrors the backend's
`SymptomAssessment.java` rule for rule. Use it for the immediate answer on
save; store the server's `assessment` when it arrives.

The two agree, so a check-in completed offline shows the same severity before
and after it syncs. Do not write a second set of rules.

Note that the backend's blood-pressure bands inside a check-in (≥180
emergency; ≥160, ≤90, ≥100 diastolic or ≤60 diastolic urgent) are **not** the
numbers written in FR-DEC-004/005. The shipped backend wins — that is what
keeps the two sides consistent. Do not "fix" it locally.

### Decision 3 — Every severity comes with an action, and emergencies say so unmistakably

FR-SYM-010 and FR-DEC-009. `actionKeyFor(severity)` gives the translation key;
the strings already exist in both languages under `clinical.action.*`.

An `EMERGENCY` result — severe chest pain, systolic ≥180 — must not look like
a status chip. Full-width, critical red, unambiguous, and it should not be
possible to miss by scrolling past. This is the one place in the app where
interrupting the user is correct.

Be careful with the wording. The app must not diagnose, and it must not tell
someone not to seek help. "Call your emergency contact now" is the approved
copy; do not improvise clinical instructions.

### Decision 4 — The cross-signal is composed, never imported

FR-DEC-003: doses missed **and** cardiac symptoms on the same day is more
serious than either alone. `adherenceCrossSignal` takes three booleans and is
already written and tested.

Get "was a dose missed today" by querying the `DoseLogs` table directly — it
lives in `core/db` and belongs to nobody, so this is not a cross-feature
import. Do not import anything from `features/medication/`. Handle M3 not
having landed: no dose rows means no missed dose, which the function already
handles.

### Decision 5 — Guidance content is bundled JSON, not Dart

Content in `assets/content/*.json`, one file per language, loaded through a
local datasource. Not hard-coded in widgets: it has to be reviewable by a
clinician and translatable by someone who does not read Dart, and both of
those need it to be data.

Bundled at build time (FR-EDU-009, FR-OFF-009) — no download, no server, works
before the patient even has an account.

Structure the schema so one renderer handles every module: a topic with a
title, sections, and blocks that are paragraphs, bullet lists, callouts or
reference links. **Reference links only, no embedded video** — an explicit
requirement, and right for users on metered data.

Topics: `chd-basics`, `symptoms`, `heart-attack`, `diet`, `exercise`,
`medication-adherence`, `psychosocial`.

### Decision 6 — Content is where "plain language" is won or lost

FR-EDU-011 and FR-LOC-004 apply hardest here. Short sentences, everyday words,
an illustration or icon per section. The diet guide is specifically about
Ethiopian food — whole-teff injera, shiro, misir, kik, gomen, local fruit —
not a translated Western guide. Cultural specificity is the requirement, not a
nicety.

**The Amharic content needs native-speaker review before release.** Write it,
mark it clearly as needing review, and flag it in your PR. Do not let it ship
unreviewed.

### Decision 7 — "Indications to terminate activity" is safety content, and it is prominent

FR-ACT-002: chest pain, dizziness, BP past threshold, glucose below 6 or above
15 mmol/L. This is the one piece of guidance whose absence could cause harm.
It belongs on the activity screen itself — before and during logging — not
buried three taps into the education section.

### Decision 8 — The quiz reinforces, it does not grade

FR-EDU-008, after the CHD facts module. Multiple choice, immediate feedback,
an explanation for every answer including the correct ones. No score kept, no
pass mark, retakeable. It is a teaching device; a patient who "fails" a quiz
about their own disease should not be made to feel it.

---

## 3. Screens

| Screen | Route | Contents | States |
|---|---|---|---|
| **Check-in (tab root)** | `AppRoutes.checkIn` | Today's prompt or today's result; entry points to the symptom form, activity logging, and both histories | loading · not done today · done today · offline |
| **Symptom check-in** | `symptomCheckIn` | Chest pain (yes/no + 0–10), shortness of breath (None/Mild/Severe), resting HR, BP, swelling (yes/no), energy 0–10, "worse than yesterday?", optional note | idle · validating · saving · result (severity + action) |
| **Symptom history** | `symptomHistory` | Reverse-chronological with severity chips; a day's detail on tap; sync state per row | loading · empty · loaded |
| **Log activity** | `activityLog` | Type, duration (min), intensity, optional steps and distance, measured-at, note. Termination indications visible. | idle · validating · saving |
| **Activity history** | `activityHistory` | Reverse-chronological; weekly totals | loading · empty · loaded |
| **Learn (tab root)** | `AppRoutes.learn` | Topic list with icons and a one-line summary each; diet and exercise surfaced prominently | loaded (always — content is bundled) |
| **Topic** | `learnTopic` (`:topic`) | Rendered sections; reference links open externally; quiz entry from the CHD module | loaded |
| **Quiz** | `quiz` | One question at a time, immediate feedback with explanation, retakeable | idle · answered · finished |
| **Home cards** | — | Today's check-in prompt (order 110); today's activity (order 210) | empty · loaded |

Design symptoms and activity from scratch using `AppScaffold`, `SectionCard`,
`AppButton`, `StatusChip`, `MetricTile` and `iconsax`. A 0–10 severity control
and a yes/no control are genuinely feature-specific — build them in your own
`widgets/`.

Copy in `symptoms.*`, `activity.*` and `education.*`. Long-form content goes in
`assets/content/`, not in the translation files.

---

## 4. API contract

From `backend/docs/API.md` §5 and §6. **Success is always `200`.**

### `POST /api/v1/symptoms`

```jsonc
{ "data": {
    "chestPain": { "present": true, "severity": 6 },   // severity required when present
    "shortnessOfBreath": "MILD",                       // NONE | MILD | SEVERE
    "heartRate": 88,                                   // 20-300
    "bloodPressure": { "systolic": 148, "diastolic": 92 },
    "swelling": false,
    "energyLevel": 4,                                  // 0-10
    "worseThanYesterday": { "chestPain": true }        // optional
  },
  "measuredAt": "2026-08-22T19:10:00Z",
  "note": "after climbing stairs",
  "clientRecordId": "..." }
// 200 -> the reading plus server-computed
//        assessment: { overall, symptoms: { chestPain, shortnessOfBreath, ... } }
```

`data` is **strictly whitelisted** — an unexpected key is a `400`.
Message: `"Symptom check-in logged"`.

### `GET /api/v1/symptoms` — newest first, `?from=&to=`

### `POST /api/v1/activities`

```jsonc
{ "data": { "type": "WALKING", "durationMinutes": 30, "intensity": "MODERATE",
            "steps": 3400, "distanceMeters": 2600 },
  "measuredAt": "...", "note": "...", "clientRecordId": "..." }
```

`durationMinutes` 1–1440. **The server computes nothing here** — no
assessment, no derived fields. Message: `"Activity logged"`.

### `GET /api/v1/activities` — newest first, `?from=&to=`

Enums, case-sensitive: `Severity{NONE, MONITOR, URGENT, EMERGENCY}` (ordered)
· `ActivityType{WALKING, JOGGING, CYCLING, HOUSEHOLD, FARMING, STRETCHING,
OTHER}` · `Intensity{LIGHT, MODERATE, VIGOROUS}`.

`FARMING` and `HOUSEHOLD` are in that list deliberately — for many patients
they *are* the day's exercise. Surface them as first-class options, not under
"other".

### Sync

```jsonc
{ "clientRecordId": "...", "entityType": "SYMPTOM",  "payload": { /* POST body */ } }
{ "clientRecordId": "...", "entityType": "ACTIVITY", "payload": { /* POST body */ } }
```

---

## 5. Local state & offline behaviour

**Tables:** `SymptomLogs` (`dataJson`, `assessmentJson`, `overallSeverity`
denormalised for filtering) and `ActivityLogs` (typed `type`,
`durationMinutes`, `intensity`, `steps`, `distanceMeters`). Both append-only,
both keyed by `clientRecordId`.

**Write:** mint `newClientRecordId()`, compute the assessment locally, store
`overallSeverity` alongside the JSON so history lists sort and filter without
parsing, write to Drift, then enqueue. Never await the network.

**Read:** Drift only, for both histories and both Home cards.

**Cross-slice read:** `DoseLogs` for the cross-signal. Direct table query, no
feature import.

**Content:** no database, no network. Loaded from the asset bundle, cached in
memory.

---

## 6. Feature layout

Three cohesive areas; keep them as separate folders under one branch rather
than one folder called `misc`.

```
lib/features/symptoms/
  domain/entities/{symptom_check_in,symptom_answer}.dart
  domain/{repositories,usecases}/…
  data/{models,datasources,repositories}/…
  presentation/controllers/{check_in,symptom_history}_controller.dart
  presentation/screens/{check_in_hub,symptom_check_in,symptom_history}_screen.dart
  presentation/widgets/{severity_slider,yes_no_field,severity_result_banner}.dart
  presentation/home/check_in_card.dart          order 110

lib/features/activity/
  domain/entities/activity_session.dart
  domain/{repositories,usecases}/…
  data/{models,datasources,repositories}/…
  presentation/screens/{activity_log,activity_history}_screen.dart
  presentation/widgets/{termination_indications,activity_type_picker}.dart
  presentation/home/activity_card.dart          order 210

lib/features/education/
  data/datasources/content_local_datasource.dart     reads assets/content/
  domain/entities/{topic,section,block,quiz_question}.dart
  presentation/screens/{learn,topic,quiz}_screen.dart
  presentation/widgets/{block_renderer,topic_tile}.dart

assets/content/
  topics_en.json · topics_am.json · quiz_en.json · quiz_am.json
```

`assets/content/` is a new asset directory — it needs a `pubspec.yaml` entry,
which is a shared file. **Ask the maintainer to add it** before you start, so
it is not blocking you later.

Register in `lib/app/app_wiring.dart`, in the two `M5` regions: the check-in
tab, the learn tab, and both Home cards.

---

## 7. Files this slice may NOT touch

`backend/**` and `database/**` are **read-only and frozen at `v1.0.0`** — reading the Java is encouraged (this spec asks you to), changing it is not, and CI blocks it.

`lib/core/**` · `lib/main.dart` · `pubspec.yaml` · `tables.dart` ·
`api_endpoints.dart`. `SymptomLogs`, `ActivityLogs`, both endpoint pairs and
the whole clinical evaluator already exist.

**Especially do not edit `core/clinical/alert_evaluator.dart`.** It mirrors the
backend; changing a rule here makes a check-in's severity change after it
syncs.

Do not import from `features/medication/`. Query `DoseLogs` directly.

Allowed, in your marked region only: `lib/app/app_wiring.dart`, and the
`symptoms.*`, `activity.*` and `education.*` namespaces in
`assets/translations/*.json`.

---

## 8. Testing strategy (TDD)

**`symptom_validators_test`** — severity is required when chest pain is
present and ignored when it is not; HR 20–300; BP 40–300 with systolic >
diastolic; energy 0–10; an unexpected key never reaches the payload (the
server whitelists strictly).

**`symptom_local_datasource_test`** (`testDatabase()`) — round-trips a full
check-in including `worseThanYesterday`; `overallSeverity` is stored and
filterable; history is newest-first; "was there a check-in today" is correct
across a midnight boundary.

**`symptom_remote_datasource_test`** (`FakeDio`) — the posted `data` contains
exactly the whitelisted keys; the server's `assessment` is parsed into the
same shape the local evaluator produces; unwraps a **200**.

**`symptom_repository_impl_test`** — a check-in saved offline writes to Drift
with a locally computed assessment, enqueues a `SYMPTOM` record, and makes
**no request**; the locally computed severity equals what the server returns
for the same payload (the test that protects offline/online agreement); the
server's assessment replaces the local one on sync.

**`cross_signal_test`** — a missed dose today plus reported chest pain is
urgent; a missed dose alone is a watch; symptoms with no missed dose is none;
**no dose rows at all behaves as no missed dose** (M3 not yet landed).

**`activity_*_test`** — duration 1–1440 enforced; steps and distance optional;
weekly totals sum only the window; the seven activity types round-trip.

**`content_local_datasource_test`** — every topic parses; every topic exists
in both `en` and `am` with the same ids and the same section count; every
block type renders; every quiz question has exactly one correct answer and an
explanation; no topic references a missing asset.

**Widget tests** (`pumpApp`) — "I'm fine today" is completable in two taps;
reporting chest pain reveals the severity control; a severity of 8 shows the
emergency banner with the emergency action; the check-in hub shows today's
result once completed; termination indications are visible on the activity
screen without scrolling; the quiz explains a wrong answer *and* a right one;
at least one screen and one content topic asserted in Amharic.

---

## 9. "Done" criteria

- A patient completes a daily check-in in seconds when nothing is wrong, and
  is asked for detail only when something is.
- Every check-in produces a severity and a recommended action, in the
  patient's language, immediately and **with the radio off**.
- Severe chest pain produces an unmissable emergency response.
- Missed doses plus cardiac symptoms on the same day escalate above either
  alone.
- Check-in history is browsable, with severity visible at a glance.
- A patient logs an activity session with type, duration and intensity, sees
  their history and weekly total, and can see the indications to terminate
  activity without hunting for them.
- All seven education topics and the diet guide are readable **with the app
  offline and no account**, in both languages, with reference links and no
  embedded video.
- The quiz gives immediate, explained feedback and can be retaken.
- Everything created offline reaches the server after reconnecting, with no
  duplicates.
- `flutter analyze` clean; whole suite green; CI passing.

---

## 10. Handover checklist

- [ ] Plan committed to `docs/plans/`
- [ ] Asked the maintainer to declare `assets/content/` in `pubspec.yaml`
      **before** starting the education work
- [ ] `flutter analyze` clean, `flutter test` green
- [ ] Ran the app against a local backend; specifically verified that a
      check-in's severity is identical before and after sync
- [ ] **Flagged the Amharic content as needing native-speaker review**, and
      said which files
- [ ] Confirmed no clinical instruction was improvised beyond the approved
      action strings
- [ ] No edits to `core/clinical/`, no imports from `features/medication/`,
      no shared-file edits outside the marked regions
- [ ] Screenshots in the PR, English and Amharic, including the emergency
      state and one content topic
- [ ] No AI co-author trailer on any commit
- [ ] PR into `mobile`, title `feat(mobile): M5 — Symptoms, activity & guidance`
