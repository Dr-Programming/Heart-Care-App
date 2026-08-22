# Mobile Design — M3 (Medications, Dose Logs & Reminders)

**Date:** 2026-08-22
**Branch:** `feature/mobile/medications`
**Base:** `mobile`
**Status:** Approved for planning
**Depends on:** M0 (merged). Reads `Preferences` keys M2 writes, but degrades safely without them.

---

## 0. How to use this spec

This is a design document, not a plan. Your first task is to turn it into one.

1. `/superpowers:brainstorming` — settle what is left open below.
2. `/superpowers:writing-plans` → `docs/plans/2026-XX-XX-mobile-m3-medications.md`.
3. `/superpowers:subagent-driven-development` — execute task by task.
4. `/superpowers:requesting-code-review`, then
   `/superpowers:finishing-a-development-branch` — PR into `mobile`.

Read `mobile/CONTRIBUTING.md` first. Build bottom-up:
domain → data → presentation.

---

## 1. Context & goal

Medication adherence is the clinical point of the app. A CHD patient who takes
their statin and their antiplatelet as prescribed has a materially different
outcome from one who does not, and the single most effective thing software
can do about it is *remind them at the right moment and make logging trivial*.

This is the largest slice. It owns the medication list, the schedule, dose
logging, adherence maths, and the local notifications that drive all of it.

### Requirements covered (`FUNCTIONAL_REQUIREMENTS.md` §4, §5, §15)

FR-MED-001 (add: name, dose mg, frequency), 002 (scheduled times), 003
(log Taken/Missed/Skipped), 004 (list with today's status), 005 (edit,
deactivate), 006 (dose history with timestamps), 007 (adherence % over 7 and
30 days), 008 (dose notes), 010 (stored locally).

FR-NOT-001 (notification at each scheduled time), 002 (follow-up 1h after a
missed dose), 003 (alert on 2+ consecutive misses), 007 (EN + AM text), 008
(configurable times).

FR-DEC-001 (reminder if unlogged 1h after schedule), 002 (adherence alert).

### Deferred / out of scope (and where it lands)

- **FR-MED-009, caregiver notifications** — voided in the requirements.
- **FR-DEC-003, the missed-dose-plus-symptoms cross-signal** — the evaluator
  exists (`adherenceCrossSignal`) but composing it needs symptom data. **M5**
  owns rendering it; you expose "was a dose missed today" through your Home
  card or a Drift query M5 can run.
- **FR-GRAPH-006, the adherence trend chart** — **M4** owns charts. You
  compute and expose the percentages; M4 plots them if it gets there.
- **Appointment reminders (FR-NOT-004)** — appointments are dropped scope.

---

## 2. Design decisions

### Decision 1 — Medications are mutable, dose logs are not

Two different data shapes hiding under one feature. A medication can be
renamed, re-dosed, rescheduled and deactivated. A dose log is a clinical fact:
once recorded, it is never edited or deleted.

That is also why `DELETE /medications/{id}` is a **soft deactivate** — the
dose history has to survive. Never offer a hard delete; offer "stop taking
this", and keep it visible in history.

### Decision 2 — A dose is derived, not stored, until it is logged

Do not pre-create a row for every future dose. `Medications.scheduleTimesJson`
plus the frequency is enough to compute today's due doses on the fly, and
materialising them would mean a background job to keep them in step with an
edited schedule, plus a migration every time.

So: "today's doses" is a query — active medications × their scheduled times,
left-joined against `DoseLogs` for today's date. A dose with no matching log
is *pending*; past its time with no log, it is *overdue*.

Note the consequence: **`MISSED` only ever exists because someone recorded it**
— the patient, or your missed-dose follow-up. An unlogged past dose is not
automatically a miss. Decide deliberately when (or whether) to auto-record one,
and write the decision down; it changes what the adherence percentage means.

### Decision 3 — The dose log's link to its medication is by client record id

`DoseLogs.medicationClientRecordId` is always set; `medicationServerId` may be
null. This is not redundancy — it is what makes offline work.

A patient adds a medication and logs its first dose, both offline. Neither has
a server id. On sync, the sync endpoint takes either `medicationId` **or**
`medicationClientRecordId` for a `DOSE_LOG` record (exactly one), and the
server always processes `MEDICATION` records before `DOSE_LOG` records within
a batch regardless of the order you send them. So send the client id whenever
the server id is still null and the pair resolves itself.

### Decision 4 — Notifications are scheduled from the local schedule and nothing else

`flutter_local_notifications` + `timezone`, no server involvement (FR-OFF-010).
Reschedule whenever a medication is added, edited, deactivated or reactivated,
and on app start — Android clears scheduled alarms on reboot and after some
force-stops.

Use an id derivation that is stable and reversible (medication client record
id + time slot hashed to an int) so a reschedule replaces rather than
duplicates. Duplicate reminders are the fastest way to get an app's
notifications switched off entirely.

Respect `PreferenceKeys.notificationsEnabled`. Cancel everything when it is
off; do not just suppress display.

### Decision 5 — Adherence is taken doses over due doses, and the window is honest

`taken / due` over the window, where *due* counts only doses scheduled while
the medication was active, and only up to now — a 7-day figure computed at
09:00 must not count this evening's doses as missed. `SKIPPED` is excluded
from the numerator and, deliberately, also from the denominator: the patient
made a decision and recorded it, which is behaviour worth encouraging rather
than punishing with a lower score.

Say what your denominator is in the UI ("12 of 14 doses this week"), not just
a bare percentage.

### Decision 6 — Logging a dose is one tap from Home

The moment of highest intent is when the reminder fires. If logging takes a
tap on the notification, then a tab, then a screen, then a row, then a
confirmation, it will not happen. Today's doses belong on the Home card with
the action inline; the notification should deep-link straight to it.

### Decision 7 — Consecutive-miss detection uses the shared evaluator

`hasConsecutiveMissedDoses` in `core/clinical/alert_evaluator.dart` already
implements FR-DEC-002, including the rule that `SKIPPED` breaks the run rather
than continuing it. Use it. Do not write a second copy — the symptom slice and
Home both read the same semantics.

---

## 3. Screens

| Screen | Route | Source | Contents | States |
|---|---|---|---|---|
| **Medications (tab root)** | `AppRoutes.medications` | Figma Medications | Today's doses with inline Taken/Missed/Skipped; the medication list below with dose, frequency and next time; add button | loading · empty · loaded · offline |
| **Add / edit medication** | `medicationNew`, `medicationEdit` | — | Name, dose mg, frequency (Once daily / BID / TID / Custom), scheduled times, active toggle | idle · validating · saving |
| **Dose history** | `doseHistory` | — | Reverse-chronological log with status chips, notes, and per-row sync state; filter by medication and date range | loading · empty · loaded |
| **Adherence** | `adherence` | — | 7-day and 30-day percentages with the underlying counts, per medication and overall | loading · insufficient data · loaded |
| **Reminder settings** | `reminderSettings` | — | On/off, per-medication times, follow-up delay | idle |
| **Home card** | — | — | Today's doses, order 100 | empty · loaded |

Frequency should drive the time fields: picking BID offers two times, Custom
offers an editable list. Deactivating asks for confirmation via `ConfirmSheet`
and says plainly that history is kept.

Copy goes in the `meds.*` namespace. Notification titles and bodies are
translated too (FR-NOT-007) — and they are built at *schedule* time, so a
language change must reschedule them.

---

## 4. API contract

From `backend/docs/API.md` §3. **Success is always `200`**, never 201.
Envelope as usual.

| Method | Path | Notes |
|---|---|---|
| `POST` | `/api/v1/medications` | `{name ≤255, doseMg >0, frequency, scheduleTimes[] "HH:mm", active=true, clientRecordId?}` → `"Medication created"` |
| `GET` | `/api/v1/medications` | Newest first. `?includeInactive=false` |
| `PUT` | `/api/v1/medications/{id}` | Full replace of name/doseMg/frequency/scheduleTimes/active. `active` omitted → unchanged. `404` if not owned. |
| `DELETE` | `/api/v1/medications/{id}` | **Soft deactivate**, idempotent. `"Medication deactivated"` |
| `POST` | `/api/v1/medications/{medicationId}/doses` | `{status, scheduledDate, scheduledTime?, loggedAt?, note ≤500, clientRecordId?}` → `"Dose logged"` |
| `GET` | `/api/v1/dose-logs` | Newest first. `?from=&to=&medicationId=` |

Enums, case-sensitive: `Frequency{ONCE_DAILY, BID, TID, CUSTOM}` ·
`DoseStatus{TAKEN, MISSED, SKIPPED}`.

Traps:

- `GET /dose-logs?medicationId=<valid-but-unknown-uuid>` returns `200 []`,
  **not** a 404. Do not treat an empty list as an error.
- `404` also means "exists but belongs to another user".
- `scheduledDate` is `yyyy-MM-dd`; `scheduledTime` is `HH:mm`. Use
  `DateFormatter.toApiDate`. Never localise a wire date.

### Sync

```jsonc
{ "clientRecordId": "...", "entityType": "MEDICATION", "payload": { /* the POST body */ } }
{ "clientRecordId": "...", "entityType": "DOSE_LOG",
  "payload": { "medicationClientRecordId": "...", "status": "TAKEN",
               "scheduledDate": "2026-08-22", ... } }
```

`DOSE_LOG` takes `medicationId` **or** `medicationClientRecordId` — exactly
one. **Medication *edits* are not syncable**: only creates go through the sync
endpoint. An edit made offline has to be replayed as a `PUT` once online, the
same problem M2 has with the profile. Decide how in your plan.

---

## 5. Local state & offline behaviour

**Tables:** `Medications` (mutable) and `DoseLogs` (append-only), both keyed
by `clientRecordId`.

**Every write:** mint `newClientRecordId()`, write to Drift, then
`syncEnqueuerProvider.enqueue(...)` with `SyncEntityType.medication` or
`.doseLog`. Never await the network on a user action.

**Every read:** from Drift. The medication list and today's doses must render
identically with the radio off.

**Per-row sync state:** `SyncQueueDao.statusFor(clientRecordId)` — show it in
history rather than storing a status column of your own.

Other slices read these tables directly. Home's cross-signal wants to know
whether a dose was missed today; M4 may want the adherence series. Keep the
tables honest and do not hide them behind a repository only you can reach.

---

## 6. Feature layout

```
lib/features/medication/
  medication_providers.dart
  domain/
    entities/{medication,dose_log,scheduled_dose,adherence}.dart
    repositories/medication_repository.dart
    usecases/{add,edit,deactivate,log_dose,todays_doses,adherence}.dart
    schedule.dart            frequency -> due times; pure, heavily tested
    validators.dart
  data/
    models/{medication_model,dose_log_model}.dart
    datasources/medication_remote_datasource.dart
    datasources/medication_local_datasource.dart
    repositories/medication_repository_impl.dart
  presentation/
    controllers/{medication_list,medication_form,dose_log,adherence}_controller.dart
    screens/{medications,medication_form,dose_history,adherence,reminder_settings}_screen.dart
    widgets/{medication_card,dose_row,status_selector,time_list_field}.dart
    home/todays_doses_card.dart          order 100
  notifications/
    medication_notifications.dart        scheduling, ids, cancellation
```

Register in `lib/app/app_wiring.dart`, `M3 medications` region: the tab root
and its sub-routes, plus your Home card.

`flutter_local_notifications` and `timezone` are already in `pubspec.yaml`.
Platform setup (Android channel, iOS permissions) belongs in your notification
file, initialised from your providers — not in `main.dart`.

---

## 7. Files this slice may NOT touch

`lib/core/**` · `lib/main.dart` · `pubspec.yaml` · `tables.dart` ·
`api_endpoints.dart`. `Medications`, `DoseLogs`, all six medication paths, the
sync enqueuer and `hasConsecutiveMissedDoses` already exist.

Allowed, in your marked region only: `lib/app/app_wiring.dart`, and the
`meds.*` namespace in `assets/translations/*.json`.

The Android manifest may need a notification permission entry — that is a
shared platform file. Raise it with the maintainer rather than editing it.

---

## 8. Testing strategy (TDD)

**`schedule_test`** (pure, the most valuable tests in the slice) — ONCE_DAILY
yields one due time, BID two, TID three; CUSTOM yields exactly the stored
times; a medication activated mid-window is not due before it existed; a
deactivated medication is not due after; times are local wall clock and do not
shift across a day boundary.

**`adherence_test`** — 3 taken of 4 due is 75%; SKIPPED is excluded from both
numerator and denominator; doses later today are not counted as due; a window
with zero due doses reports "no data" rather than 0% or a divide-by-zero;
7-day and 30-day windows have the right bounds.

**`medication_local_datasource_test`** (`testDatabase()`) — round-trips a
medication with several scheduled times; deactivating keeps the row and its
dose logs; today's-doses query returns pending, overdue and logged correctly.

**`medication_remote_datasource_test`** (`FakeDio`) — create sends the
documented body and unwraps a **200**; `DELETE` is treated as a deactivate;
`GET /dose-logs` with an unknown medication id returns an empty list, **not**
an error.

**`medication_repository_impl_test`** — adding a medication offline writes to
Drift, enqueues a `MEDICATION` record, and makes **no request**; logging a
dose offline enqueues a `DOSE_LOG` carrying `medicationClientRecordId` when
the medication has no server id yet, and `medicationId` when it does; logging
the same dose twice does not produce two rows.

**`medication_notifications_test`** — a schedule produces one notification per
time; rescheduling replaces rather than duplicating (same derived ids);
deactivating cancels; notifications off cancels everything; titles and bodies
come from translations.

**Widget tests** (`pumpApp`) — the list shows today's doses with their status;
tapping Taken updates immediately and offline; the form validates a
non-positive dose and an empty schedule; changing frequency changes the number
of time fields; deactivating asks for confirmation and says history is kept;
the empty state invites adding a first medication; at least one screen
asserted in Amharic.

---

## 9. "Done" criteria

- A patient adds a medication with a dose, a frequency and one or more times,
  edits it, and stops taking it — with the dose history preserved.
- Today's doses appear on Home and on the tab, and can be logged Taken, Missed
  or Skipped in one tap, **with the radio off**.
- A local notification fires at each scheduled time, and again an hour later
  if the dose is still unlogged. Both are in the patient's language.
- Two consecutive missed doses of the same medication produce an adherence
  alert.
- Adherence shows a 7-day and a 30-day figure with the counts behind it, and
  says so honestly when there is not enough data.
- Everything created offline reaches the server after reconnecting, with no
  duplicates, and a dose logged before its medication synced still attaches to
  the right medication.
- `flutter analyze` clean; whole suite green; CI passing.

---

## 10. Handover checklist

- [ ] Plan committed to `docs/plans/`
- [ ] `flutter analyze` clean, `flutter test` green
- [ ] Ran the app against a local backend; specifically verified the offline
      add-then-log-then-reconnect path and that reminders fire on a device
- [ ] Documented your decision on auto-recording an unlogged past dose
- [ ] No edits to shared files outside the marked regions
- [ ] Screenshots in the PR, English and Amharic, including a notification
- [ ] No AI co-author trailer on any commit
- [ ] PR into `mobile`, title `feat(mobile): M3 — Medications, dose logs & reminders`
- [ ] Told M5 how to query "was a dose missed today" for the cross-signal
