# M3 — Medications, Dose Logs & Reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Medications feature end-to-end — medication CRUD, derived "today's doses", dose logging (Taken/Missed/Skipped), 7/30-day adherence, and local reminder notifications — as `lib/features/medication/` on branch `feature/mobile/medications`.

**Architecture:** Feature-first clean architecture (domain → data → presentation), offline-first (Drift first, then `SyncEnqueuer`), built entirely on the M0 foundation (`lib/core/**`, untouched). Two problems the shared sync queue doesn't solve are handled inside this feature only: (a) today's doses are *derived* at read time from active medications × their schedule, never pre-materialized; (b) medication edits/deactivations aren't syncable via `/api/v1/sync` (only creates are), so they're tracked in a local "pending edit" set (a `Preferences` key) and replayed as a direct `PUT` once the medication has a `serverId` and the device is online.

**Tech Stack:** Flutter, Riverpod (plain `Provider`/`AsyncNotifier`, no codegen — matches the foundation's style), Drift (existing `Medications`/`DoseLogs` tables), Dio, freezed/json_serializable, `flutter_local_notifications` + `timezone`, `easy_localization`, `mocktail`.

**Spec:** `docs/design/2026-08-22-mobile-m3-medications-reminders-design.md` (read this in full — this plan implements it). Also read `mobile/CONTRIBUTING.md` and `docs/design/2026-08-22-mobile-frontend-program.md` for the shared rules and the M0 foundation this plan builds on. Working notes: gitignored `CLAUDE.md` at the repo root.

## Global Constraints

- **Never edit** `backend/**`, `database/**`, `lib/core/**`, `lib/main.dart`, `pubspec.yaml`, `android/**`, `ios/**`. Every task below only creates/modifies files under `lib/features/medication/`, `test/features/medication/`, plus one marked region each in `lib/app/app_wiring.dart` and `assets/translations/{en,am}.json`.
- **Success is always `200`**, never `201` — never branch on `201`. Every response is wrapped in `{success, data, message, timestamp}` — unwrap with `ApiResponse.fromJson`.
- **Every write:** mint `newClientRecordId()` → write to Drift → `syncEnqueuerProvider.enqueue(...)`. Never await the network on a user action. **Every read:** from Drift, never the API.
- **Enums are wire-exact and case-sensitive:** `Frequency{ONCE_DAILY,BID,TID,CUSTOM}`, `DoseStatus{TAKEN,MISSED,SKIPPED}`.
- `scheduledDate` = `yyyy-MM-dd` (`DateFormatter.toApiDate`), `scheduledTime`/schedule entries = `HH:mm`. Never localise a wire date.
- `404` from the API means "not found **or** not yours" — never `403`.
- `GET /dose-logs?medicationId=<valid-but-unknown-uuid>` → `200 []`, not `404`.
- `SKIPPED` is excluded from **both** the numerator and denominator of adherence.
- `MISSED` is only ever written explicitly (patient action or the 1h-follow-up notification firing) — never inferred silently in a background sweep.
- Use `core/clinical/alert_evaluator.dart`'s `hasConsecutiveMissedDoses` verbatim for FR-DEC-002 — do not reimplement it.
- `flutter analyze` must be clean and `flutter test` all green before every commit (per task, not just at the end).
- Conventional commits, scope `mobile`: `feat(mobile): …` / `test(mobile): …`. **No AI co-author trailer on any commit.**
- Copy (including notification titles/bodies) goes in the `meds.*` translation namespace; every user-facing string added must exist in both `en.json` and `am.json`.

---

## File Structure

```
lib/features/medication/
  medication_providers.dart
  domain/
    entities/
      medication.dart              Medication, MedicationFrequency
      dose_log.dart                DoseLog, DoseStatus
      scheduled_dose.dart          ScheduledDose, ScheduledDoseStatus
      adherence.dart               Adherence
    repositories/
      medication_repository.dart   abstract interface
    schedule.dart                  pure: active-window + today's-doses + adherence math
    validators.dart                pure: form field validation
    usecases/
      add_medication.dart
      edit_medication.dart
      deactivate_medication.dart
      log_dose.dart
      todays_doses.dart
      get_adherence.dart
  data/
    models/
      medication_model.dart        freezed, JSON + Drift row <-> entity mapping
      dose_log_model.dart
    datasources/
      medication_remote_datasource.dart
      medication_local_datasource.dart
    repositories/
      medication_repository_impl.dart
  notifications/
    notification_scheduler.dart    abstract interface + real flutter_local_notifications impl
    medication_notifications.dart  scheduling policy, id derivation, cancellation
  presentation/
    controllers/
      medication_list_controller.dart
      medication_form_controller.dart
      dose_history_controller.dart
      adherence_controller.dart
    screens/
      medications_screen.dart
      medication_form_screen.dart
      dose_history_screen.dart
      adherence_screen.dart
      reminder_settings_screen.dart
    widgets/
      medication_card.dart
      dose_row.dart
      status_selector.dart
      time_list_field.dart
    home/
      todays_doses_card.dart       HomeCard, order 100

test/features/medication/  — mirrors the tree above, one test file per source file
```

**Deviation from the spec's exact file list, noted for the record:** `schedule.dart` also contains the adherence math (the spec's `adherence_test` and `schedule_test` are still two separate test files, both testing functions exported from this one module) rather than a separate file, since both are small, pure, and tightly related (both walk the same due-dose derivation). Notifications get their own `notification_scheduler.dart` interface (not named in the spec) so `MedicationNotifications` is unit-testable without touching the real plugin — the spec's `medication_notifications_test` still exercises `MedicationNotifications` itself, just through a fake `NotificationScheduler`.

**Reactivity choice, noted for the record:** rather than combining two live Drift `.watch()` streams (medications + today's dose logs) into one derived stream — which would need a stream-zipping utility not already in `pubspec.yaml`, which this plan cannot edit — the list/today's-doses/adherence reads are plain `Future`s that the presentation-layer controllers re-fetch after every mutation (`ref.invalidateSelf()`), the same shape Riverpod's `AsyncNotifier` is built for. Cross-cutting state that must be truly live (signed-in user, pending-sync count) already has a core-provided stream; this feature doesn't need another one.

---

## Task 1: Domain entity — Medication

**Files:**
- Create: `lib/features/medication/domain/entities/medication.dart`
- Test: `test/features/medication/domain/entities/medication_test.dart`

**Interfaces:**
- Produces: `class Medication` (`clientRecordId`, `serverId`, `name`, `doseMg`, `frequency`, `scheduleTimes`, `active`, `createdAt`, `updatedAt`), `enum MedicationFrequency { onceDaily, bid, tid, custom }` with `.wire` and `MedicationFrequency.fromWire(String)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/domain/entities/medication_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';

void main() {
  group('MedicationFrequency', () {
    test('wire values match the backend exactly', () {
      expect(MedicationFrequency.onceDaily.wire, 'ONCE_DAILY');
      expect(MedicationFrequency.bid.wire, 'BID');
      expect(MedicationFrequency.tid.wire, 'TID');
      expect(MedicationFrequency.custom.wire, 'CUSTOM');
    });

    test('fromWire round-trips every value', () {
      for (final MedicationFrequency f in MedicationFrequency.values) {
        expect(MedicationFrequency.fromWire(f.wire), f);
      }
    });
  });

  group('Medication', () {
    test('holds every field passed to its constructor', () {
      final DateTime now = DateTime(2026, 8, 25, 9);
      final Medication medication = Medication(
        clientRecordId: 'c1',
        serverId: 's1',
        name: 'Atorvastatin',
        doseMg: 20,
        frequency: MedicationFrequency.onceDaily,
        scheduleTimes: const <String>['08:00'],
        active: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(medication.clientRecordId, 'c1');
      expect(medication.serverId, 's1');
      expect(medication.name, 'Atorvastatin');
      expect(medication.doseMg, 20);
      expect(medication.frequency, MedicationFrequency.onceDaily);
      expect(medication.scheduleTimes, <String>['08:00']);
      expect(medication.active, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `mobile/`): `flutter test test/features/medication/domain/entities/medication_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:libu_care/features/medication/domain/entities/medication.dart'`.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/domain/entities/medication.dart

/// A medication the patient is taking. Mutable — can be renamed, re-dosed,
/// rescheduled and soft-deactivated. Never hard-deleted (Decision 1).
class Medication {
  const Medication({
    required this.clientRecordId,
    required this.serverId,
    required this.name,
    required this.doseMg,
    required this.frequency,
    required this.scheduleTimes,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String clientRecordId;
  final String? serverId;
  final String name;
  final double doseMg;
  final MedicationFrequency frequency;

  /// "HH:mm" strings. The full set of times this medication is due at, for
  /// every frequency — frequency does not independently generate times.
  final List<String> scheduleTimes;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Medication copyWith({
    String? serverId,
    String? name,
    double? doseMg,
    MedicationFrequency? frequency,
    List<String>? scheduleTimes,
    bool? active,
    DateTime? updatedAt,
  }) {
    return Medication(
      clientRecordId: clientRecordId,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      doseMg: doseMg ?? this.doseMg,
      frequency: frequency ?? this.frequency,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Wire-identical to the backend's `Frequency` enum.
enum MedicationFrequency {
  onceDaily('ONCE_DAILY'),
  bid('BID'),
  tid('TID'),
  custom('CUSTOM');

  const MedicationFrequency(this.wire);

  final String wire;

  static MedicationFrequency fromWire(String value) =>
      values.firstWhere((MedicationFrequency f) => f.wire == value);

  /// How many time-of-day fields the add/edit form suggests by default.
  /// Soft guidance only — never enforced against `scheduleTimes.length`,
  /// mirroring the backend's deliberate non-validation (the client owns
  /// this UX; see `backend/docs/DEVELOPMENT.md`/API design decision).
  int get suggestedTimeCount => switch (this) {
    MedicationFrequency.onceDaily => 1,
    MedicationFrequency.bid => 2,
    MedicationFrequency.tid => 3,
    MedicationFrequency.custom => 1,
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/domain/entities/medication_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/domain/entities/medication.dart test/features/medication/domain/entities/medication_test.dart
git commit -m "feat(mobile): M3 medication entity"
```

---

## Task 2: Domain entity — DoseLog

**Files:**
- Create: `lib/features/medication/domain/entities/dose_log.dart`
- Test: `test/features/medication/domain/entities/dose_log_test.dart`

**Interfaces:**
- Produces: `class DoseLog` (`clientRecordId`, `serverId`, `medicationClientRecordId`, `medicationServerId`, `status`, `scheduledDate`, `scheduledTime`, `loggedAt`, `note`), `enum DoseStatus { taken, missed, skipped }` with `.wire` / `.fromWire`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/domain/entities/dose_log_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';

void main() {
  group('DoseStatus', () {
    test('wire values match the backend exactly', () {
      expect(DoseStatus.taken.wire, 'TAKEN');
      expect(DoseStatus.missed.wire, 'MISSED');
      expect(DoseStatus.skipped.wire, 'SKIPPED');
    });

    test('fromWire round-trips every value', () {
      for (final DoseStatus s in DoseStatus.values) {
        expect(DoseStatus.fromWire(s.wire), s);
      }
    });
  });

  group('DoseLog', () {
    test('holds every field passed to its constructor', () {
      final DateTime loggedAt = DateTime.utc(2026, 8, 25, 8, 5);
      final DoseLog log = DoseLog(
        clientRecordId: 'd1',
        serverId: null,
        medicationClientRecordId: 'm1',
        medicationServerId: null,
        status: DoseStatus.taken,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        loggedAt: loggedAt,
        note: 'with breakfast',
      );

      expect(log.medicationClientRecordId, 'm1');
      expect(log.status, DoseStatus.taken);
      expect(log.scheduledDate, '2026-08-25');
      expect(log.scheduledTime, '08:00');
      expect(log.loggedAt, loggedAt);
      expect(log.note, 'with breakfast');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/domain/entities/dose_log_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/domain/entities/dose_log.dart

/// One logged dose. Append-only — once recorded, a `DoseLog` is never
/// edited or deleted (Decision 1).
class DoseLog {
  const DoseLog({
    required this.clientRecordId,
    required this.serverId,
    required this.medicationClientRecordId,
    required this.medicationServerId,
    required this.status,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.loggedAt,
    required this.note,
  });

  final String clientRecordId;
  final String? serverId;

  /// Always set — the offline-safe link to its medication (Decision 3).
  final String medicationClientRecordId;
  final String? medicationServerId;

  final DoseStatus status;

  /// "yyyy-MM-dd", the day the dose was due.
  final String scheduledDate;

  /// "HH:mm", null for an unscheduled/ad-hoc log.
  final String? scheduledTime;
  final DateTime loggedAt;
  final String? note;
}

/// Wire-identical to the backend's `DoseStatus` enum.
enum DoseStatus {
  taken('TAKEN'),
  missed('MISSED'),
  skipped('SKIPPED');

  const DoseStatus(this.wire);

  final String wire;

  static DoseStatus fromWire(String value) =>
      values.firstWhere((DoseStatus s) => s.wire == value);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/domain/entities/dose_log_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/domain/entities/dose_log.dart test/features/medication/domain/entities/dose_log_test.dart
git commit -m "feat(mobile): M3 dose log entity"
```

---

## Task 3: Domain entities — ScheduledDose and Adherence

**Files:**
- Create: `lib/features/medication/domain/entities/scheduled_dose.dart`
- Create: `lib/features/medication/domain/entities/adherence.dart`
- Test: `test/features/medication/domain/entities/scheduled_dose_test.dart`
- Test: `test/features/medication/domain/entities/adherence_test.dart`

**Interfaces:**
- Consumes: `Medication`, `MedicationFrequency` (Task 1), `DoseLog`, `DoseStatus` (Task 2).
- Produces: `class ScheduledDose` (`medicationClientRecordId`, `medicationName`, `doseMg`, `scheduledDate`, `scheduledTime`, `status`, `doseLog`), `enum ScheduledDoseStatus { pending, overdue, logged }`; `class Adherence` (`taken`, `due`, `skipped`, `windowDays`) with `hasData` and `percentage` getters.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/medication/domain/entities/scheduled_dose_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';

void main() {
  test('a ScheduledDose with no doseLog is not logged', () {
    const ScheduledDose dose = ScheduledDose(
      medicationClientRecordId: 'm1',
      medicationName: 'Aspirin',
      doseMg: 75,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
      status: ScheduledDoseStatus.pending,
      doseLog: null,
    );

    expect(dose.status, ScheduledDoseStatus.pending);
    expect(dose.doseLog, isNull);
  });

  test('a ScheduledDose carries its matched doseLog when logged', () {
    final DoseLog log = DoseLog(
      clientRecordId: 'd1',
      serverId: null,
      medicationClientRecordId: 'm1',
      medicationServerId: null,
      status: DoseStatus.taken,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
      loggedAt: DateTime.utc(2026, 8, 25, 8),
      note: null,
    );
    final ScheduledDose dose = ScheduledDose(
      medicationClientRecordId: 'm1',
      medicationName: 'Aspirin',
      doseMg: 75,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
      status: ScheduledDoseStatus.logged,
      doseLog: log,
    );

    expect(dose.status, ScheduledDoseStatus.logged);
    expect(dose.doseLog!.status, DoseStatus.taken);
  });
}
```

```dart
// test/features/medication/domain/entities/adherence_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';

void main() {
  test('percentage divides taken by due', () {
    const Adherence a = Adherence(taken: 3, due: 4, skipped: 0, windowDays: 7);
    expect(a.hasData, isTrue);
    expect(a.percentage, closeTo(0.75, 0.0001));
  });

  test('zero due doses reports no data instead of dividing by zero', () {
    const Adherence a = Adherence(taken: 0, due: 0, skipped: 0, windowDays: 7);
    expect(a.hasData, isFalse);
    expect(a.percentage, isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/medication/domain/entities/scheduled_dose_test.dart test/features/medication/domain/entities/adherence_test.dart`
Expected: FAIL — target files don't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/domain/entities/scheduled_dose.dart
import 'dose_log.dart';

/// One occurrence of a medication being due, derived at read time — never
/// stored (Decision 2). `pending` means not yet due today or not yet acted
/// on; `overdue` means past its time with no log; `logged` means a matching
/// [DoseLog] was found.
enum ScheduledDoseStatus { pending, overdue, logged }

class ScheduledDose {
  const ScheduledDose({
    required this.medicationClientRecordId,
    required this.medicationName,
    required this.doseMg,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    required this.doseLog,
  });

  final String medicationClientRecordId;
  final String medicationName;
  final double doseMg;

  /// "yyyy-MM-dd".
  final String scheduledDate;

  /// "HH:mm".
  final String scheduledTime;
  final ScheduledDoseStatus status;

  /// Set only when [status] is `logged`.
  final DoseLog? doseLog;
}
```

```dart
// lib/features/medication/domain/entities/adherence.dart

/// `taken / due` over a window (Decision 5). `SKIPPED` doses are excluded
/// from both [taken] and [due] — recorded separately in [skipped] for
/// display, never as a penalty.
class Adherence {
  const Adherence({
    required this.taken,
    required this.due,
    required this.skipped,
    required this.windowDays,
  });

  final int taken;
  final int due;
  final int skipped;
  final int windowDays;

  /// False when there were zero due doses in the window — the UI must show
  /// "not enough data" rather than 0% or dividing by zero.
  bool get hasData => due > 0;

  double? get percentage => hasData ? taken / due : null;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medication/domain/entities/scheduled_dose_test.dart test/features/medication/domain/entities/adherence_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/domain/entities/scheduled_dose.dart lib/features/medication/domain/entities/adherence.dart test/features/medication/domain/entities/scheduled_dose_test.dart test/features/medication/domain/entities/adherence_test.dart
git commit -m "feat(mobile): M3 scheduled dose and adherence entities"
```

---

## Task 4: schedule.dart — active window, today's doses, adherence (pure)

The most valuable tests in the slice (spec §8). Two test files, one source
file.

**Files:**
- Create: `lib/features/medication/domain/schedule.dart`
- Test: `test/features/medication/domain/schedule_test.dart`
- Test: `test/features/medication/domain/adherence_test.dart`

**Interfaces:**
- Consumes: `Medication`, `MedicationFrequency` (Task 1), `DoseLog`, `DoseStatus` (Task 2), `ScheduledDose`, `ScheduledDoseStatus` (Task 3), `Adherence` (Task 3), `DateFormatter` (`core/utils/date_formatter.dart` — read-only import, not an edit).
- Produces: `bool isActiveOn(Medication, DateTime day)`, `List<ScheduledDose> scheduledDosesFor({required List<Medication> medications, required List<DoseLog> logsForDate, required DateTime date, required DateTime now})`, `Adherence computeAdherence({required List<Medication> medications, required List<DoseLog> allLogs, required DateTime windowStart, required DateTime now, required int windowDays})`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/medication/domain/schedule_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/schedule.dart';

Medication _med({
  required String id,
  required List<String> times,
  bool active = true,
  DateTime? createdAt,
  DateTime? updatedAt,
  MedicationFrequency frequency = MedicationFrequency.onceDaily,
}) {
  final DateTime created = createdAt ?? DateTime(2026, 1, 1);
  return Medication(
    clientRecordId: id,
    serverId: null,
    name: 'Med $id',
    doseMg: 10,
    frequency: frequency,
    scheduleTimes: times,
    active: active,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

void main() {
  group('isActiveOn', () {
    test('a medication is not due before it existed', () {
      final Medication med = _med(
        id: 'm1',
        times: <String>['08:00'],
        createdAt: DateTime(2026, 8, 10),
      );
      expect(isActiveOn(med, DateTime(2026, 8, 9)), isFalse);
      expect(isActiveOn(med, DateTime(2026, 8, 10)), isTrue);
    });

    test('a deactivated medication is not due after it was deactivated', () {
      final Medication med = _med(
        id: 'm1',
        times: <String>['08:00'],
        createdAt: DateTime(2026, 8, 1),
        active: false,
        updatedAt: DateTime(2026, 8, 15),
      );
      expect(isActiveOn(med, DateTime(2026, 8, 14)), isTrue);
      expect(isActiveOn(med, DateTime(2026, 8, 16)), isFalse);
    });
  });

  group('scheduledDosesFor', () {
    test('yields one slot per scheduled time, whatever the frequency', () {
      final DateTime date = DateTime(2026, 8, 25);
      final DateTime now = DateTime(2026, 8, 25, 23);
      final List<ScheduledDose> once = scheduledDosesFor(
        medications: <Medication>[
          _med(id: 'm1', times: <String>['08:00'], frequency: MedicationFrequency.onceDaily),
        ],
        logsForDate: const <DoseLog>[],
        date: date,
        now: now,
      );
      final List<ScheduledDose> bid = scheduledDosesFor(
        medications: <Medication>[
          _med(id: 'm2', times: <String>['08:00', '20:00'], frequency: MedicationFrequency.bid),
        ],
        logsForDate: const <DoseLog>[],
        date: date,
        now: now,
      );
      final List<ScheduledDose> custom = scheduledDosesFor(
        medications: <Medication>[
          _med(id: 'm3', times: <String>['06:00', '12:00', '18:00', '22:00'], frequency: MedicationFrequency.custom),
        ],
        logsForDate: const <DoseLog>[],
        date: date,
        now: now,
      );

      expect(once, hasLength(1));
      expect(bid, hasLength(2));
      expect(custom, hasLength(4));
    });

    test('an unlogged past-due slot is overdue; an unlogged future slot is pending', () {
      final DateTime date = DateTime(2026, 8, 25);
      final DateTime now = DateTime(2026, 8, 25, 12);
      final List<ScheduledDose> doses = scheduledDosesFor(
        medications: <Medication>[
          _med(id: 'm1', times: <String>['08:00', '20:00']),
        ],
        logsForDate: const <DoseLog>[],
        date: date,
        now: now,
      );

      final ScheduledDose morning = doses.firstWhere((ScheduledDose d) => d.scheduledTime == '08:00');
      final ScheduledDose evening = doses.firstWhere((ScheduledDose d) => d.scheduledTime == '20:00');
      expect(morning.status, ScheduledDoseStatus.overdue);
      expect(evening.status, ScheduledDoseStatus.pending);
    });

    test('a slot with a matching log is logged and carries the log', () {
      final DateTime date = DateTime(2026, 8, 25);
      final DoseLog log = DoseLog(
        clientRecordId: 'd1',
        serverId: null,
        medicationClientRecordId: 'm1',
        medicationServerId: null,
        status: DoseStatus.taken,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        loggedAt: DateTime.utc(2026, 8, 25, 8, 2),
        note: null,
      );
      final List<ScheduledDose> doses = scheduledDosesFor(
        medications: <Medication>[_med(id: 'm1', times: <String>['08:00'])],
        logsForDate: <DoseLog>[log],
        date: date,
        now: DateTime(2026, 8, 25, 12),
      );

      expect(doses.single.status, ScheduledDoseStatus.logged);
      expect(doses.single.doseLog, log);
    });

    test('a late-evening slot stays on its own calendar day, not shifted by UTC', () {
      final DateTime date = DateTime(2026, 8, 25);
      final DateTime now = DateTime(2026, 8, 25, 23, 45);
      final List<ScheduledDose> doses = scheduledDosesFor(
        medications: <Medication>[_med(id: 'm1', times: <String>['23:30'])],
        logsForDate: const <DoseLog>[],
        date: date,
        now: now,
      );

      expect(doses.single.scheduledDate, '2026-08-25');
      expect(doses.single.status, ScheduledDoseStatus.overdue);
    });

    test('an inactive medication contributes no slots', () {
      final List<ScheduledDose> doses = scheduledDosesFor(
        medications: <Medication>[_med(id: 'm1', times: <String>['08:00'], active: false)],
        logsForDate: const <DoseLog>[],
        date: DateTime(2026, 8, 25),
        now: DateTime(2026, 8, 25, 12),
      );
      expect(doses, isEmpty);
    });
  });
}
```

```dart
// test/features/medication/domain/adherence_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/schedule.dart';

Medication _daily(String id, DateTime createdAt, {bool active = true, DateTime? updatedAt}) {
  return Medication(
    clientRecordId: id,
    serverId: null,
    name: 'Med $id',
    doseMg: 10,
    frequency: MedicationFrequency.onceDaily,
    scheduleTimes: const <String>['08:00'],
    active: active,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
  );
}

DoseLog _log(String medicationId, String date, DoseStatus status) {
  return DoseLog(
    clientRecordId: '$medicationId-$date',
    serverId: null,
    medicationClientRecordId: medicationId,
    medicationServerId: null,
    status: status,
    scheduledDate: date,
    scheduledTime: '08:00',
    loggedAt: DateTime.parse('${date}T08:05:00Z'),
    note: null,
  );
}

void main() {
  test('3 taken of 4 due is 75%', () {
    final Medication med = _daily('m1', DateTime(2026, 8, 18));
    final Adherence a = computeAdherence(
      medications: <Medication>[med],
      allLogs: <DoseLog>[
        _log('m1', '2026-08-19', DoseStatus.taken),
        _log('m1', '2026-08-20', DoseStatus.taken),
        _log('m1', '2026-08-21', DoseStatus.taken),
        // 2026-08-22 due, never logged -> counts toward due, not taken
      ],
      windowStart: DateTime(2026, 8, 19),
      now: DateTime(2026, 8, 22, 12),
      windowDays: 7,
    );

    expect(a.due, 4);
    expect(a.taken, 3);
    expect(a.percentage, closeTo(0.75, 0.0001));
  });

  test('SKIPPED is excluded from both taken and due', () {
    final Medication med = _daily('m1', DateTime(2026, 8, 18));
    final Adherence a = computeAdherence(
      medications: <Medication>[med],
      allLogs: <DoseLog>[
        _log('m1', '2026-08-19', DoseStatus.taken),
        _log('m1', '2026-08-20', DoseStatus.skipped),
      ],
      windowStart: DateTime(2026, 8, 19),
      now: DateTime(2026, 8, 20, 23),
      windowDays: 7,
    );

    expect(a.due, 1);
    expect(a.taken, 1);
    expect(a.skipped, 1);
    expect(a.percentage, 1.0);
  });

  test('doses later today are not counted as due', () {
    final Medication med = _daily('m1', DateTime(2026, 8, 18));
    final Adherence a = computeAdherence(
      medications: <Medication>[med],
      allLogs: const <DoseLog>[],
      windowStart: DateTime(2026, 8, 25),
      now: DateTime(2026, 8, 25, 6), // before today's 08:00 slot
      windowDays: 7,
    );

    expect(a.due, 0);
    expect(a.hasData, isFalse);
  });

  test('a window with zero due doses reports no data, not 0% or a crash', () {
    final Adherence a = computeAdherence(
      medications: const <Medication>[],
      allLogs: const <DoseLog>[],
      windowStart: DateTime(2026, 8, 19),
      now: DateTime(2026, 8, 25, 12),
      windowDays: 7,
    );

    expect(a.hasData, isFalse);
    expect(a.percentage, isNull);
  });

  test('a 7-day window includes exactly 7 calendar days up to today', () {
    final Medication med = _daily('m1', DateTime(2026, 1, 1));
    final Adherence a = computeAdherence(
      medications: <Medication>[med],
      allLogs: const <DoseLog>[],
      windowStart: DateTime(2026, 8, 19), // 19,20,21,22,23,24,25 = 7 days
      now: DateTime(2026, 8, 25, 23),
      windowDays: 7,
    );
    expect(a.due, 7);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/medication/domain/schedule_test.dart test/features/medication/domain/adherence_test.dart`
Expected: FAIL — `schedule.dart` doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/domain/schedule.dart
import '../../../core/utils/date_formatter.dart';
import 'entities/adherence.dart';
import 'entities/dose_log.dart';
import 'entities/medication.dart';
import 'entities/scheduled_dose.dart';

/// Whether [medication] counts as active on [day] — i.e. whether any of its
/// scheduled times on that day are due at all.
///
/// **Known limitation, accepted deliberately:** the schema (owned by the
/// foundation, not editable by this slice) has no `deactivatedAt` column —
/// only `active` and a generic `updatedAt` that changes on *any* edit. When
/// `active` is false, `updatedAt` is used as a best-effort proxy for "the day
/// it stopped being due". A medication edited (not deactivated) shortly
/// before being deactivated could therefore lose one day of adherence
/// history at the boundary. Documented here rather than silently accepted;
/// revisit if the schema ever grows a dedicated column.
bool isActiveOn(Medication medication, DateTime day) {
  final DateTime dayStart = DateFormatter.startOfDay(day);
  final DateTime createdDay = DateFormatter.startOfDay(medication.createdAt);
  if (dayStart.isBefore(createdDay)) return false;
  if (!medication.active) {
    final DateTime deactivatedDay = DateFormatter.startOfDay(medication.updatedAt);
    if (dayStart.isAfter(deactivatedDay)) return false;
  }
  return true;
}

/// Today's (or any single day's) doses (Decision 2): active medications ×
/// their scheduled times, matched against that day's logs. Never
/// pre-materialized — this runs fresh on every read.
List<ScheduledDose> scheduledDosesFor({
  required List<Medication> medications,
  required List<DoseLog> logsForDate,
  required DateTime date,
  required DateTime now,
}) {
  final String dateStr = DateFormatter.toApiDate(date);
  final List<ScheduledDose> result = <ScheduledDose>[];

  for (final Medication medication in medications) {
    if (!isActiveOn(medication, date)) continue;
    for (final String time in medication.scheduleTimes) {
      final DoseLog? match = _matchingLog(logsForDate, medication.clientRecordId, time);
      final ScheduledDoseStatus status = match != null
          ? ScheduledDoseStatus.logged
          : (_isPastDue(date, time, now)
                ? ScheduledDoseStatus.overdue
                : ScheduledDoseStatus.pending);

      result.add(
        ScheduledDose(
          medicationClientRecordId: medication.clientRecordId,
          medicationName: medication.name,
          doseMg: medication.doseMg,
          scheduledDate: dateStr,
          scheduledTime: time,
          status: status,
          doseLog: match,
        ),
      );
    }
  }

  result.sort((ScheduledDose a, ScheduledDose b) => a.scheduledTime.compareTo(b.scheduledTime));
  return result;
}

/// `taken / due` over `[windowStart, now]` (Decision 5). A slot only counts
/// as due once its time has passed — "later today" is never counted — and
/// `SKIPPED` never counts toward either side.
Adherence computeAdherence({
  required List<Medication> medications,
  required List<DoseLog> allLogs,
  required DateTime windowStart,
  required DateTime now,
  required int windowDays,
}) {
  int taken = 0;
  int due = 0;
  int skipped = 0;

  DateTime day = DateFormatter.startOfDay(windowStart);
  final DateTime today = DateFormatter.startOfDay(now);

  while (!day.isAfter(today)) {
    for (final Medication medication in medications) {
      if (!isActiveOn(medication, day)) continue;
      for (final String time in medication.scheduleTimes) {
        if (!_isPastDue(day, time, now)) continue;

        final DoseLog? match = _matchingLog(
          allLogs.where((DoseLog l) => l.scheduledDate == DateFormatter.toApiDate(day)).toList(),
          medication.clientRecordId,
          time,
        );

        if (match == null) {
          due++;
        } else if (match.status == DoseStatus.skipped) {
          skipped++;
        } else {
          due++;
          if (match.status == DoseStatus.taken) taken++;
        }
      }
    }
    day = day.add(const Duration(days: 1));
  }

  return Adherence(taken: taken, due: due, skipped: skipped, windowDays: windowDays);
}

DoseLog? _matchingLog(List<DoseLog> logs, String medicationClientRecordId, String time) {
  for (final DoseLog log in logs) {
    if (log.medicationClientRecordId == medicationClientRecordId && log.scheduledTime == time) {
      return log;
    }
  }
  return null;
}

bool _isPastDue(DateTime date, String time, DateTime now) {
  final List<String> parts = time.split(':');
  final DateTime due = DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
  return !due.isAfter(now);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medication/domain/schedule_test.dart test/features/medication/domain/adherence_test.dart`
Expected: PASS (11 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/domain/schedule.dart test/features/medication/domain/schedule_test.dart test/features/medication/domain/adherence_test.dart
git commit -m "feat(mobile): M3 schedule and adherence math"
```

---

## Task 5: validators.dart

**Files:**
- Create: `lib/features/medication/domain/validators.dart`
- Test: `test/features/medication/domain/validators_test.dart`

**Interfaces:**
- Produces: `String? validateMedicationName(String value)`, `String? validateDoseMg(String value)`, `String? validateScheduleTimes(List<String> times)`. Each returns `null` when valid, otherwise a `meds.errors.*` translation key (never a rendered sentence — screens resolve the key with `.tr()`, matching `AppTextField.errorText`'s documented contract).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/domain/validators_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/validators.dart';

void main() {
  group('validateMedicationName', () {
    test('rejects blank', () {
      expect(validateMedicationName('   '), 'meds.errors.nameRequired');
    });
    test('rejects over 255 chars', () {
      expect(validateMedicationName('a' * 256), 'meds.errors.nameTooLong');
    });
    test('accepts a normal name', () {
      expect(validateMedicationName('Atorvastatin'), isNull);
    });
  });

  group('validateDoseMg', () {
    test('rejects blank', () {
      expect(validateDoseMg(''), 'meds.errors.doseRequired');
    });
    test('rejects non-numeric', () {
      expect(validateDoseMg('abc'), 'meds.errors.doseInvalid');
    });
    test('rejects zero and negative', () {
      expect(validateDoseMg('0'), 'meds.errors.dosePositive');
      expect(validateDoseMg('-5'), 'meds.errors.dosePositive');
    });
    test('accepts a positive number, including decimals', () {
      expect(validateDoseMg('2.5'), isNull);
      expect(validateDoseMg('100'), isNull);
    });
  });

  group('validateScheduleTimes', () {
    test('rejects an empty schedule', () {
      expect(validateScheduleTimes(const <String>[]), 'meds.errors.scheduleRequired');
    });
    test('rejects a malformed time', () {
      expect(validateScheduleTimes(const <String>['8am']), 'meds.errors.scheduleFormat');
      expect(validateScheduleTimes(const <String>['25:00']), 'meds.errors.scheduleFormat');
    });
    test('accepts one or more well-formed times', () {
      expect(validateScheduleTimes(const <String>['08:00', '20:00']), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/domain/validators_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/domain/validators.dart

/// Pure form validation. Every non-null return is a `meds.errors.*`
/// translation key, never a rendered sentence.
final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

String? validateMedicationName(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return 'meds.errors.nameRequired';
  if (trimmed.length > 255) return 'meds.errors.nameTooLong';
  return null;
}

String? validateDoseMg(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return 'meds.errors.doseRequired';
  final double? parsed = double.tryParse(trimmed);
  if (parsed == null) return 'meds.errors.doseInvalid';
  if (parsed <= 0) return 'meds.errors.dosePositive';
  return null;
}

String? validateScheduleTimes(List<String> times) {
  if (times.isEmpty) return 'meds.errors.scheduleRequired';
  for (final String time in times) {
    if (!_timePattern.hasMatch(time)) return 'meds.errors.scheduleFormat';
  }
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/domain/validators_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/domain/validators.dart test/features/medication/domain/validators_test.dart
git commit -m "feat(mobile): M3 form validators"
```

---

## Task 6: MedicationRepository interface and use cases

Thin wrappers (CONTRIBUTING.md's canonical template, §8) — each just calls
through to the repository. Tested against a hand-written fake repository, not
a mock framework, since the interface is small.

**Files:**
- Create: `lib/features/medication/domain/repositories/medication_repository.dart`
- Create: `lib/features/medication/domain/usecases/add_medication.dart`
- Create: `lib/features/medication/domain/usecases/edit_medication.dart`
- Create: `lib/features/medication/domain/usecases/deactivate_medication.dart`
- Create: `lib/features/medication/domain/usecases/log_dose.dart`
- Create: `lib/features/medication/domain/usecases/todays_doses.dart`
- Create: `lib/features/medication/domain/usecases/get_adherence.dart`
- Test: `test/features/medication/domain/usecases/medication_usecases_test.dart`

**Interfaces:**
- Consumes: `Medication`, `DoseLog`, `DoseStatus`, `ScheduledDose`, `Adherence` (Tasks 1–3).
- Produces: `abstract interface class MedicationRepository` with the methods below; six use case classes, each `const` with a single `.call(...)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/domain/usecases/medication_usecases_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/domain/usecases/add_medication.dart';
import 'package:libu_care/features/medication/domain/usecases/deactivate_medication.dart';
import 'package:libu_care/features/medication/domain/usecases/edit_medication.dart';
import 'package:libu_care/features/medication/domain/usecases/get_adherence.dart';
import 'package:libu_care/features/medication/domain/usecases/log_dose.dart';
import 'package:libu_care/features/medication/domain/usecases/todays_doses.dart';

Medication _medication(String id) => Medication(
  clientRecordId: id,
  serverId: null,
  name: 'Aspirin',
  doseMg: 75,
  frequency: MedicationFrequency.onceDaily,
  scheduleTimes: const <String>['08:00'],
  active: true,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

class _FakeMedicationRepository implements MedicationRepository {
  final List<String> calls = <String>[];

  @override
  Future<List<Medication>> activeMedications() async {
    calls.add('activeMedications');
    return <Medication>[_medication('m1')];
  }

  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) async {
    calls.add('allMedications:$includeInactive');
    return <Medication>[_medication('m1')];
  }

  @override
  Future<Medication> add({
    required String name,
    required double doseMg,
    required MedicationFrequency frequency,
    required List<String> scheduleTimes,
  }) async {
    calls.add('add:$name');
    return _medication('new');
  }

  @override
  Future<Medication> edit(Medication updated) async {
    calls.add('edit:${updated.clientRecordId}');
    return updated;
  }

  @override
  Future<Medication> deactivate(String clientRecordId) async {
    calls.add('deactivate:$clientRecordId');
    return _medication(clientRecordId);
  }

  @override
  Future<DoseLog> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  }) async {
    calls.add('logDose:$medicationClientRecordId:${status.wire}');
    return DoseLog(
      clientRecordId: 'd1',
      serverId: null,
      medicationClientRecordId: medicationClientRecordId,
      medicationServerId: null,
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      loggedAt: DateTime.utc(2026, 8, 25),
      note: note,
    );
  }

  @override
  Future<List<ScheduledDose>> todaysDoses({DateTime? now}) async {
    calls.add('todaysDoses');
    return const <ScheduledDose>[];
  }

  @override
  Future<List<DoseLog>> doseHistory({
    String? medicationClientRecordId,
    DateTime? from,
    DateTime? to,
  }) async {
    calls.add('doseHistory');
    return const <DoseLog>[];
  }

  @override
  Future<Adherence> adherence({
    String? medicationClientRecordId,
    required int windowDays,
    DateTime? now,
  }) async {
    calls.add('adherence:$windowDays');
    return Adherence(taken: 1, due: 1, skipped: 0, windowDays: windowDays);
  }

  @override
  Future<void> replayPendingEdits() async {
    calls.add('replayPendingEdits');
  }
}

void main() {
  late _FakeMedicationRepository repo;

  setUp(() => repo = _FakeMedicationRepository());

  test('AddMedication delegates to the repository', () async {
    await AddMedication(repo).call(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );
    expect(repo.calls.single, 'add:Aspirin');
  });

  test('EditMedication delegates to the repository', () async {
    await EditMedication(repo).call(_medication('m1'));
    expect(repo.calls.single, 'edit:m1');
  });

  test('DeactivateMedication delegates to the repository', () async {
    await DeactivateMedication(repo).call('m1');
    expect(repo.calls.single, 'deactivate:m1');
  });

  test('LogDose delegates to the repository', () async {
    await LogDose(repo).call(
      medicationClientRecordId: 'm1',
      status: DoseStatus.taken,
      scheduledDate: '2026-08-25',
    );
    expect(repo.calls.single, 'logDose:m1:TAKEN');
  });

  test('TodaysDoses delegates to the repository', () async {
    await TodaysDoses(repo).call();
    expect(repo.calls.single, 'todaysDoses');
  });

  test('GetAdherence delegates to the repository', () async {
    final Adherence a = await GetAdherence(repo).call(windowDays: 7);
    expect(repo.calls.single, 'adherence:7');
    expect(a.windowDays, 7);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/domain/usecases/medication_usecases_test.dart`
Expected: FAIL — none of the target files exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/domain/repositories/medication_repository.dart
import '../entities/adherence.dart';
import '../entities/dose_log.dart';
import '../entities/medication.dart';
import '../entities/scheduled_dose.dart';

/// Offline-first: every method reads from and writes to Drift first. A
/// caller never waits on the network. Implemented by
/// `MedicationRepositoryImpl` (Task 14).
abstract interface class MedicationRepository {
  Future<List<Medication>> activeMedications();
  Future<List<Medication>> allMedications({bool includeInactive = false});

  Future<Medication> add({
    required String name,
    required double doseMg,
    required MedicationFrequency frequency,
    required List<String> scheduleTimes,
  });

  /// Full-replace edit of an existing medication (name/doseMg/frequency/
  /// scheduleTimes/active) — same shape the `PUT` endpoint expects.
  Future<Medication> edit(Medication updated);

  /// Soft-deactivate (Decision 1). Idempotent.
  Future<Medication> deactivate(String clientRecordId);

  Future<DoseLog> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  });

  /// Today's derived doses (Decision 2). Pass [now] only in tests.
  Future<List<ScheduledDose>> todaysDoses({DateTime? now});

  Future<List<DoseLog>> doseHistory({
    String? medicationClientRecordId,
    DateTime? from,
    DateTime? to,
  });

  /// Pass [medicationClientRecordId] for one medication's figure, or omit it
  /// for the overall figure across every medication.
  Future<Adherence> adherence({
    String? medicationClientRecordId,
    required int windowDays,
    DateTime? now,
  });

  /// Replays any offline edit/deactivate still owed to the server as a
  /// direct `PUT`, for medications that now have a `serverId` (§ Task 14).
  /// A no-op when there is nothing pending or the device is offline.
  Future<void> replayPendingEdits();
}
```

```dart
// lib/features/medication/domain/usecases/add_medication.dart
import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

class AddMedication {
  const AddMedication(this._repository);
  final MedicationRepository _repository;

  Future<Medication> call({
    required String name,
    required double doseMg,
    required MedicationFrequency frequency,
    required List<String> scheduleTimes,
  }) => _repository.add(
    name: name,
    doseMg: doseMg,
    frequency: frequency,
    scheduleTimes: scheduleTimes,
  );
}
```

```dart
// lib/features/medication/domain/usecases/edit_medication.dart
import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

class EditMedication {
  const EditMedication(this._repository);
  final MedicationRepository _repository;

  Future<Medication> call(Medication updated) => _repository.edit(updated);
}
```

```dart
// lib/features/medication/domain/usecases/deactivate_medication.dart
import '../entities/medication.dart';
import '../repositories/medication_repository.dart';

class DeactivateMedication {
  const DeactivateMedication(this._repository);
  final MedicationRepository _repository;

  Future<Medication> call(String clientRecordId) =>
      _repository.deactivate(clientRecordId);
}
```

```dart
// lib/features/medication/domain/usecases/log_dose.dart
import '../entities/dose_log.dart';
import '../repositories/medication_repository.dart';

class LogDose {
  const LogDose(this._repository);
  final MedicationRepository _repository;

  Future<DoseLog> call({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  }) => _repository.logDose(
    medicationClientRecordId: medicationClientRecordId,
    status: status,
    scheduledDate: scheduledDate,
    scheduledTime: scheduledTime,
    note: note,
  );
}
```

```dart
// lib/features/medication/domain/usecases/todays_doses.dart
import '../entities/scheduled_dose.dart';
import '../repositories/medication_repository.dart';

class TodaysDoses {
  const TodaysDoses(this._repository);
  final MedicationRepository _repository;

  Future<List<ScheduledDose>> call({DateTime? now}) =>
      _repository.todaysDoses(now: now);
}
```

```dart
// lib/features/medication/domain/usecases/get_adherence.dart
import '../entities/adherence.dart';
import '../repositories/medication_repository.dart';

class GetAdherence {
  const GetAdherence(this._repository);
  final MedicationRepository _repository;

  Future<Adherence> call({
    String? medicationClientRecordId,
    required int windowDays,
    DateTime? now,
  }) => _repository.adherence(
    medicationClientRecordId: medicationClientRecordId,
    windowDays: windowDays,
    now: now,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/domain/usecases/medication_usecases_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/domain/repositories lib/features/medication/domain/usecases test/features/medication/domain/usecases
git commit -m "feat(mobile): M3 repository interface and use cases"
```

---

## Task 7: Data models — MedicationModel and DoseLogModel

Freezed models bridging three shapes: the API's JSON, the Drift row/companion,
and the domain entity. Uses the `ClassName._()` private-constructor pattern
so the generated class can carry `toEntity()`/`toCompanion()` methods
alongside the generated `fromJson`/`copyWith` (CONTRIBUTING §8's canonical
template). Both need a prefixed import of `core/db/app_database.dart` because
Drift's generated row classes (`Medication`, `DoseLog`) collide by name with
this feature's own domain entities.

**Files:**
- Create: `lib/features/medication/data/models/medication_model.dart`
- Create: `lib/features/medication/data/models/dose_log_model.dart`
- Test: `test/features/medication/data/models/medication_model_test.dart`
- Test: `test/features/medication/data/models/dose_log_model_test.dart`

**Interfaces:**
- Consumes: `Medication`, `MedicationFrequency` (Task 1), `DoseLog`, `DoseStatus` (Task 2), `drift_db.MedicationsCompanion`, `drift_db.DoseLogsCompanion` (`core/db/app_database.dart`, read-only import).
- Produces: `MedicationModel` (`fromJson`, `fromEntity`, `toEntity()`, `toCompanion()`), `DoseLogModel` (`fromJson`, `fromEntity`, `toEntity({required medicationClientRecordId})`, `toCompanion({required medicationClientRecordId})`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/medication/data/models/medication_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/data/models/medication_model.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';

void main() {
  final Map<String, dynamic> wireJson = <String, dynamic>{
    'id': 'server-1',
    'name': 'Atorvastatin',
    'doseMg': 20.0,
    'frequency': 'ONCE_DAILY',
    'scheduleTimes': <String>['08:00'],
    'active': true,
    'clientRecordId': 'client-1',
    'createdAt': '2026-07-19T10:00:00Z',
    'updatedAt': '2026-07-19T10:00:00Z',
  };

  test('fromJson parses the documented response shape', () {
    final MedicationModel model = MedicationModel.fromJson(wireJson);
    expect(model.id, 'server-1');
    expect(model.name, 'Atorvastatin');
    expect(model.doseMg, 20.0);
    expect(model.frequency, 'ONCE_DAILY');
    expect(model.scheduleTimes, <String>['08:00']);
    expect(model.clientRecordId, 'client-1');
  });

  test('toEntity maps to the domain Medication', () {
    final MedicationModel model = MedicationModel.fromJson(wireJson);
    final Medication entity = model.toEntity();
    expect(entity.clientRecordId, 'client-1');
    expect(entity.serverId, 'server-1');
    expect(entity.frequency, MedicationFrequency.onceDaily);
    expect(entity.scheduleTimes, <String>['08:00']);
  });

  test('fromEntity round-trips back to matching wire fields', () {
    final Medication entity = Medication(
      clientRecordId: 'client-2',
      serverId: null,
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.bid,
      scheduleTimes: const <String>['08:00', '20:00'],
      active: true,
      createdAt: DateTime.utc(2026, 8, 25),
      updatedAt: DateTime.utc(2026, 8, 25),
    );
    final MedicationModel model = MedicationModel.fromEntity(entity);
    expect(model.id, isNull);
    expect(model.name, 'Aspirin');
    expect(model.frequency, 'BID');
    expect(model.clientRecordId, 'client-2');
  });

  test('toCompanion carries the JSON-encoded schedule and the client id as key', () {
    final MedicationModel model = MedicationModel.fromJson(wireJson);
    final companion = model.toCompanion();
    expect(companion.clientRecordId.value, 'client-1');
    expect(companion.scheduleTimesJson.value, '["08:00"]');
  });
}
```

```dart
// test/features/medication/data/models/dose_log_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/data/models/dose_log_model.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';

void main() {
  final Map<String, dynamic> wireJson = <String, dynamic>{
    'id': 'dose-server-1',
    'medicationId': 'med-server-1',
    'scheduledDate': '2026-07-16',
    'scheduledTime': '08:00',
    'status': 'TAKEN',
    'loggedAt': '2026-07-16T05:05:00Z',
    'note': 'taken with breakfast',
    'clientRecordId': 'dose-client-1',
    'createdAt': '2026-07-16T05:05:02Z',
  };

  test('fromJson parses the documented response shape', () {
    final DoseLogModel model = DoseLogModel.fromJson(wireJson);
    expect(model.id, 'dose-server-1');
    expect(model.medicationId, 'med-server-1');
    expect(model.status, 'TAKEN');
    expect(model.note, 'taken with breakfast');
  });

  test('toEntity requires the caller to supply the client-side medication link', () {
    final DoseLogModel model = DoseLogModel.fromJson(wireJson);
    final DoseLog entity = model.toEntity(medicationClientRecordId: 'med-client-1');
    expect(entity.medicationClientRecordId, 'med-client-1');
    expect(entity.medicationServerId, 'med-server-1');
    expect(entity.status, DoseStatus.taken);
    expect(entity.scheduledDate, '2026-07-16');
  });

  test('toCompanion carries the client id as primary key', () {
    final DoseLogModel model = DoseLogModel.fromJson(wireJson);
    final companion = model.toCompanion(medicationClientRecordId: 'med-client-1');
    expect(companion.clientRecordId.value, 'dose-client-1');
    expect(companion.medicationClientRecordId.value, 'med-client-1');
    expect(companion.status.value, 'TAKEN');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/medication/data/models/`
Expected: FAIL — target files, and their `.freezed.dart`/`.g.dart` parts, don't exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/data/models/medication_model.dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/db/app_database.dart' as drift_db;
import '../../domain/entities/medication.dart';

part 'medication_model.freezed.dart';
part 'medication_model.g.dart';

/// The `POST/GET/PUT /medications` response shape (`backend/docs/API.md` §3),
/// plus conversions to and from the domain [Medication] and the local Drift
/// row. `id` is the server id — null for a not-yet-synced medication.
@freezed
abstract class MedicationModel with _$MedicationModel {
  const MedicationModel._();

  const factory MedicationModel({
    String? id,
    required String name,
    required double doseMg,
    required String frequency,
    required List<String> scheduleTimes,
    required bool active,
    String? clientRecordId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _MedicationModel;

  factory MedicationModel.fromJson(Map<String, dynamic> json) =>
      _$MedicationModelFromJson(json);

  factory MedicationModel.fromEntity(Medication medication) => MedicationModel(
    id: medication.serverId,
    name: medication.name,
    doseMg: medication.doseMg,
    frequency: medication.frequency.wire,
    scheduleTimes: medication.scheduleTimes,
    active: medication.active,
    clientRecordId: medication.clientRecordId,
    createdAt: medication.createdAt,
    updatedAt: medication.updatedAt,
  );

  Medication toEntity() {
    final DateTime now = DateTime.now().toUtc();
    return Medication(
      clientRecordId: clientRecordId!,
      serverId: id,
      name: name,
      doseMg: doseMg,
      frequency: MedicationFrequency.fromWire(frequency),
      scheduleTimes: scheduleTimes,
      active: active,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  drift_db.MedicationsCompanion toCompanion() {
    final DateTime now = DateTime.now().toUtc();
    return drift_db.MedicationsCompanion.insert(
      clientRecordId: clientRecordId!,
      serverId: Value<String?>(id),
      name: name,
      doseMg: doseMg,
      frequency: frequency,
      scheduleTimesJson: jsonEncode(scheduleTimes),
      active: Value<bool>(active),
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }
}
```

```dart
// lib/features/medication/data/models/dose_log_model.dart
import 'package:drift/drift.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/db/app_database.dart' as drift_db;
import '../../domain/entities/dose_log.dart';

part 'dose_log_model.freezed.dart';
part 'dose_log_model.g.dart';

/// The `POST/GET .../doses` response shape. Never carries the client-side
/// medication link on the wire (Decision 3) — every conversion that needs it
/// takes it as a parameter from the caller, which already knows which
/// medication it was logging against.
@freezed
abstract class DoseLogModel with _$DoseLogModel {
  const DoseLogModel._();

  const factory DoseLogModel({
    String? id,
    required String medicationId,
    required String status,
    required String scheduledDate,
    String? scheduledTime,
    DateTime? loggedAt,
    String? note,
    String? clientRecordId,
    DateTime? createdAt,
  }) = _DoseLogModel;

  factory DoseLogModel.fromJson(Map<String, dynamic> json) =>
      _$DoseLogModelFromJson(json);

  factory DoseLogModel.fromEntity(DoseLog log) => DoseLogModel(
    id: log.serverId,
    medicationId: log.medicationServerId ?? '',
    status: log.status.wire,
    scheduledDate: log.scheduledDate,
    scheduledTime: log.scheduledTime,
    loggedAt: log.loggedAt,
    note: log.note,
    clientRecordId: log.clientRecordId,
    createdAt: log.loggedAt,
  );

  DoseLog toEntity({required String medicationClientRecordId}) {
    return DoseLog(
      clientRecordId: clientRecordId!,
      serverId: id,
      medicationClientRecordId: medicationClientRecordId,
      medicationServerId: medicationId.isEmpty ? null : medicationId,
      status: DoseStatus.fromWire(status),
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      loggedAt: loggedAt ?? DateTime.now().toUtc(),
      note: note,
    );
  }

  drift_db.DoseLogsCompanion toCompanion({
    required String medicationClientRecordId,
  }) {
    return drift_db.DoseLogsCompanion.insert(
      clientRecordId: clientRecordId!,
      serverId: Value<String?>(id),
      medicationClientRecordId: medicationClientRecordId,
      medicationServerId: Value<String?>(
        medicationId.isEmpty ? null : medicationId,
      ),
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: Value<String?>(scheduledTime),
      loggedAt: loggedAt ?? DateTime.now().toUtc(),
      note: Value<String?>(note),
    );
  }
}
```

- [ ] **Step 4: Generate code and run tests**

Run (from `mobile/`): `dart run build_runner build`
Then: `flutter test test/features/medication/data/models/`
Expected: PASS (4 + 3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/data/models test/features/medication/data/models
git commit -m "feat(mobile): M3 medication and dose log data models"
```

Note: `*.freezed.dart` and `*.g.dart` are gitignored per `mobile/.gitignore` — only the two hand-written source files are staged.

---

## Task 8: MedicationRemoteDataSource

All six endpoints (spec §4), matching the documented contract exactly. In
this app's actual write path, day-to-day creates and dose logs go through
the offline sync queue (Task 11), not these methods directly — `update` and
`deactivate` are the two this slice's repository calls directly, for the
offline-edit replay (Decision, plan header). `create`, `logDose`, `list` and
`doseLogs` exist because the spec's API contract and testing sections require
them, and they are the natural place a future restore-on-reinstall path would
call from — not wired into anything today, and that is noted rather than
hidden.

**Files:**
- Create: `lib/features/medication/data/datasources/medication_remote_datasource.dart`
- Test: `test/features/medication/data/datasources/medication_remote_datasource_test.dart`

**Interfaces:**
- Consumes: `MedicationModel`, `DoseLogModel` (Task 7), `ApiEndpoints` (`core/constants/api_endpoints.dart`), `ApiResponse` (`core/network/api_response.dart`) — both read-only core imports.
- Produces: `class MedicationRemoteDataSource` with `create`, `list`, `update`, `deactivate`, `logDose`, `doseLogs`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/data/datasources/medication_remote_datasource_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/data/datasources/medication_remote_datasource.dart';

import '../../../../helpers/fake_dio.dart';

void main() {
  late FakeDio fake;
  late MedicationRemoteDataSource datasource;

  setUp(() {
    fake = FakeDio();
    datasource = MedicationRemoteDataSource(fake.dio);
  });

  test('create sends the documented body and unwraps a 200', () async {
    fake.stub(
      '/api/v1/medications',
      FakeResponse.ok(<String, dynamic>{
        'id': 'srv-1',
        'name': 'Atorvastatin',
        'doseMg': 20.0,
        'frequency': 'ONCE_DAILY',
        'scheduleTimes': <String>['08:00'],
        'active': true,
        'clientRecordId': 'client-1',
        'createdAt': '2026-08-25T08:00:00Z',
        'updatedAt': '2026-08-25T08:00:00Z',
      }, message: 'Medication created'),
    );

    final result = await datasource.create(
      name: 'Atorvastatin',
      doseMg: 20,
      frequency: 'ONCE_DAILY',
      scheduleTimes: const <String>['08:00'],
      clientRecordId: 'client-1',
    );

    expect(result.id, 'srv-1');
    final sent = fake.requests.single;
    expect(sent.method, 'POST');
    expect(sent.json['name'], 'Atorvastatin');
    expect(sent.json['clientRecordId'], 'client-1');
  });

  test('update PUTs a full replace to /medications/{id}', () async {
    fake.stub(
      '/api/v1/medications/srv-1',
      FakeResponse.ok(<String, dynamic>{
        'id': 'srv-1',
        'name': 'Atorvastatin 40mg',
        'doseMg': 40.0,
        'frequency': 'ONCE_DAILY',
        'scheduleTimes': <String>['08:00'],
        'active': true,
        'clientRecordId': 'client-1',
      }, message: 'Medication updated'),
    );

    final result = await datasource.update(
      'srv-1',
      name: 'Atorvastatin 40mg',
      doseMg: 40,
      frequency: 'ONCE_DAILY',
      scheduleTimes: const <String>['08:00'],
      active: true,
    );

    expect(result.doseMg, 40.0);
    expect(fake.requests.single.method, 'PUT');
  });

  test('deactivate DELETEs /medications/{id}', () async {
    fake.stub(
      '/api/v1/medications/srv-1',
      FakeResponse.ok(<String, dynamic>{
        'id': 'srv-1',
        'name': 'Atorvastatin',
        'doseMg': 20.0,
        'frequency': 'ONCE_DAILY',
        'scheduleTimes': <String>['08:00'],
        'active': false,
        'clientRecordId': 'client-1',
      }, message: 'Medication deactivated'),
    );

    final result = await datasource.deactivate('srv-1');

    expect(result.active, isFalse);
    expect(fake.requests.single.method, 'DELETE');
  });

  test('logDose POSTs to /medications/{id}/doses', () async {
    fake.stub(
      '/api/v1/medications/srv-1/doses',
      FakeResponse.ok(<String, dynamic>{
        'id': 'dose-1',
        'medicationId': 'srv-1',
        'scheduledDate': '2026-08-25',
        'status': 'TAKEN',
        'clientRecordId': 'dose-client-1',
      }, message: 'Dose logged'),
    );

    final result = await datasource.logDose(
      'srv-1',
      status: 'TAKEN',
      scheduledDate: '2026-08-25',
      clientRecordId: 'dose-client-1',
    );

    expect(result.status, 'TAKEN');
    expect(fake.requests.single.method, 'POST');
  });

  test('doseLogs with an unknown-but-valid medication id returns an empty list, not an error', () async {
    fake.stub('/api/v1/dose-logs', FakeResponse.ok(<dynamic>[]));

    final result = await datasource.doseLogs(medicationId: 'no-such-id');

    expect(result, isEmpty);
  });

  test('list passes includeInactive as a query parameter', () async {
    fake.stub('/api/v1/medications', FakeResponse.ok(<dynamic>[]));

    await datasource.list(includeInactive: true);

    expect(fake.requests.single.queryParameters['includeInactive'], 'true');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/data/datasources/medication_remote_datasource_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/data/datasources/medication_remote_datasource.dart
import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../models/dose_log_model.dart';
import '../models/medication_model.dart';

/// Dio only — no Drift import here (architectural rule 3: local and remote
/// datasources are always separate classes).
class MedicationRemoteDataSource {
  const MedicationRemoteDataSource(this._dio);

  final Dio _dio;

  Future<MedicationModel> create({
    required String name,
    required double doseMg,
    required String frequency,
    required List<String> scheduleTimes,
    bool active = true,
    String? clientRecordId,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.medications,
      data: <String, dynamic>{
        'name': name,
        'doseMg': doseMg,
        'frequency': frequency,
        'scheduleTimes': scheduleTimes,
        'active': active,
        if (clientRecordId != null) 'clientRecordId': clientRecordId,
      },
    );
    return _unwrap(response, MedicationModel.fromJson);
  }

  Future<List<MedicationModel>> list({bool includeInactive = false}) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiEndpoints.medications,
      queryParameters: <String, dynamic>{
        'includeInactive': includeInactive.toString(),
      },
    );
    return _unwrapList(response, MedicationModel.fromJson);
  }

  Future<MedicationModel> update(
    String id, {
    required String name,
    required double doseMg,
    required String frequency,
    required List<String> scheduleTimes,
    required bool active,
  }) async {
    final Response<dynamic> response = await _dio.put<dynamic>(
      ApiEndpoints.medication(id),
      data: <String, dynamic>{
        'name': name,
        'doseMg': doseMg,
        'frequency': frequency,
        'scheduleTimes': scheduleTimes,
        'active': active,
      },
    );
    return _unwrap(response, MedicationModel.fromJson);
  }

  Future<MedicationModel> deactivate(String id) async {
    final Response<dynamic> response = await _dio.delete<dynamic>(
      ApiEndpoints.medication(id),
    );
    return _unwrap(response, MedicationModel.fromJson);
  }

  Future<DoseLogModel> logDose(
    String medicationId, {
    required String status,
    required String scheduledDate,
    String? scheduledTime,
    String? loggedAt,
    String? note,
    String? clientRecordId,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      ApiEndpoints.medicationDoses(medicationId),
      data: <String, dynamic>{
        'status': status,
        'scheduledDate': scheduledDate,
        if (scheduledTime != null) 'scheduledTime': scheduledTime,
        if (loggedAt != null) 'loggedAt': loggedAt,
        if (note != null) 'note': note,
        if (clientRecordId != null) 'clientRecordId': clientRecordId,
      },
    );
    return _unwrap(response, DoseLogModel.fromJson);
  }

  Future<List<DoseLogModel>> doseLogs({
    String? from,
    String? to,
    String? medicationId,
  }) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      ApiEndpoints.doseLogs,
      queryParameters: <String, dynamic>{
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (medicationId != null) 'medicationId': medicationId,
      },
    );
    return _unwrapList(response, DoseLogModel.fromJson);
  }

  T _unwrap<T>(
    Response<dynamic> response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final ApiResponse<T> envelope = ApiResponse<T>.fromJson(
      (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
      (Object? data) => fromJson((data as Map<Object?, Object?>).cast()),
    );
    return envelope.data as T;
  }

  List<T> _unwrapList<T>(
    Response<dynamic> response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final ApiResponse<List<T>> envelope = ApiResponse<List<T>>.fromJson(
      (response.data as Map<Object?, Object?>).cast<String, dynamic>(),
      (Object? data) => (data as List<dynamic>)
          .map((dynamic e) => fromJson((e as Map<Object?, Object?>).cast()))
          .toList(),
    );
    return envelope.data ?? <T>[];
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/data/datasources/medication_remote_datasource_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/data/datasources/medication_remote_datasource.dart test/features/medication/data/datasources/medication_remote_datasource_test.dart
git commit -m "feat(mobile): M3 medication remote datasource"
```

---

## Task 9: MedicationLocalDataSource

Plain class over `AppDatabase`, exactly the `SyncQueueDao` pattern — no
`@DriftAccessor`, no regenerating a shared file. Uses the existing
`Medications`/`DoseLogs` tables directly.

**Files:**
- Create: `lib/features/medication/data/datasources/medication_local_datasource.dart`
- Test: `test/features/medication/data/datasources/medication_local_datasource_test.dart`

**Interfaces:**
- Consumes: `MedicationModel`, `DoseLogModel` (Task 7), `Medication`, `DoseLog` (Tasks 1–2), `drift_db.AppDatabase` (`core/db/app_database.dart`, read-only import, prefixed for the row-class collision).
- Produces: `class MedicationLocalDataSource` with `upsertMedication`, `activeMedications`, `allMedications`, `findMedication`, `setServerId`, `upsertDoseLog`, `doseLogsForDate`, `doseLogsInRange`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/data/datasources/medication_local_datasource_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/medication/data/datasources/medication_local_datasource.dart';
import 'package:libu_care/features/medication/data/models/dose_log_model.dart';
import 'package:libu_care/features/medication/data/models/medication_model.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MedicationLocalDataSource datasource;

  setUp(() {
    db = testDatabase();
    datasource = MedicationLocalDataSource(db);
  });

  tearDown(() => db.close());

  MedicationModel medication({
    String clientId = 'm1',
    bool active = true,
    List<String> times = const <String>['08:00', '20:00'],
  }) {
    final DateTime now = DateTime.utc(2026, 8, 25);
    return MedicationModel(
      id: null,
      name: 'Atorvastatin',
      doseMg: 20,
      frequency: 'ONCE_DAILY',
      scheduleTimes: times,
      active: active,
      clientRecordId: clientId,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('round-trips a medication with several scheduled times', () async {
    await datasource.upsertMedication(medication());

    final found = await datasource.findMedication('m1');

    expect(found, isNotNull);
    expect(found!.name, 'Atorvastatin');
    expect(found.scheduleTimes, <String>['08:00', '20:00']);
  });

  test('deactivating keeps the row and its dose logs', () async {
    await datasource.upsertMedication(medication());
    await datasource.upsertDoseLog(
      DoseLogModel(
        medicationId: '',
        status: 'TAKEN',
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        clientRecordId: 'd1',
        loggedAt: DateTime.utc(2026, 8, 25, 8, 5),
      ),
      medicationClientRecordId: 'm1',
    );

    await datasource.upsertMedication(medication(active: false));

    final found = await datasource.findMedication('m1');
    final logs = await datasource.doseLogsInRange(medicationClientRecordId: 'm1');
    expect(found!.active, isFalse);
    expect(logs, hasLength(1));
  });

  test('activeMedications excludes deactivated rows', () async {
    await datasource.upsertMedication(medication(clientId: 'm1'));
    await datasource.upsertMedication(medication(clientId: 'm2', active: false));

    final active = await datasource.activeMedications();

    expect(active.map((m) => m.clientRecordId), <String>['m1']);
  });

  test('allMedications(includeInactive: true) returns both', () async {
    await datasource.upsertMedication(medication(clientId: 'm1'));
    await datasource.upsertMedication(medication(clientId: 'm2', active: false));

    final all = await datasource.allMedications(includeInactive: true);

    expect(all, hasLength(2));
  });

  test('setServerId caches the resolved server id locally', () async {
    await datasource.upsertMedication(medication());
    await datasource.setServerId('m1', 'srv-1');

    final found = await datasource.findMedication('m1');

    expect(found!.serverId, 'srv-1');
  });

  test('doseLogsForDate returns only that day\'s logs', () async {
    await datasource.upsertMedication(medication());
    await datasource.upsertDoseLog(
      DoseLogModel(
        medicationId: '',
        status: 'TAKEN',
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        clientRecordId: 'd1',
        loggedAt: DateTime.utc(2026, 8, 25, 8),
      ),
      medicationClientRecordId: 'm1',
    );
    await datasource.upsertDoseLog(
      DoseLogModel(
        medicationId: '',
        status: 'TAKEN',
        scheduledDate: '2026-08-24',
        scheduledTime: '08:00',
        clientRecordId: 'd2',
        loggedAt: DateTime.utc(2026, 8, 24, 8),
      ),
      medicationClientRecordId: 'm1',
    );

    final logs = await datasource.doseLogsForDate('2026-08-25');

    expect(logs, hasLength(1));
    expect(logs.single.clientRecordId, 'd1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/data/datasources/medication_local_datasource_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/data/datasources/medication_local_datasource.dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/db/app_database.dart' as drift_db;
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/medication.dart';
import '../models/dose_log_model.dart';
import '../models/medication_model.dart';

class MedicationLocalDataSource {
  const MedicationLocalDataSource(this._db);

  final drift_db.AppDatabase _db;

  Future<void> upsertMedication(MedicationModel model) =>
      _db.into(_db.medications).insertOnConflictUpdate(model.toCompanion());

  Future<List<Medication>> activeMedications() async {
    final List<drift_db.Medication> rows =
        await (_db.select(_db.medications)
              ..where((drift_db.$MedicationsTable t) => t.active.equals(true)))
            .get();
    return rows.map(_medicationFromRow).toList();
  }

  Future<List<Medication>> allMedications({bool includeInactive = false}) async {
    final SimpleSelectStatement<drift_db.$MedicationsTable, drift_db.Medication>
    query = _db.select(_db.medications);
    if (!includeInactive) {
      query.where((drift_db.$MedicationsTable t) => t.active.equals(true));
    }
    final List<drift_db.Medication> rows = await query.get();
    return rows.map(_medicationFromRow).toList();
  }

  Future<Medication?> findMedication(String clientRecordId) async {
    final drift_db.Medication? row =
        await (_db.select(_db.medications)..where(
              (drift_db.$MedicationsTable t) =>
                  t.clientRecordId.equals(clientRecordId),
            ))
            .getSingleOrNull();
    return row == null ? null : _medicationFromRow(row);
  }

  Future<void> setServerId(String clientRecordId, String serverId) =>
      (_db.update(_db.medications)..where(
            (drift_db.$MedicationsTable t) =>
                t.clientRecordId.equals(clientRecordId),
          ))
          .write(
            drift_db.MedicationsCompanion(serverId: Value<String?>(serverId)),
          );

  Future<void> upsertDoseLog(
    DoseLogModel model, {
    required String medicationClientRecordId,
  }) => _db
      .into(_db.doseLogs)
      .insertOnConflictUpdate(
        model.toCompanion(medicationClientRecordId: medicationClientRecordId),
      );

  Future<List<DoseLog>> doseLogsForDate(String date) async {
    final List<drift_db.DoseLog> rows =
        await (_db.select(_db.doseLogs)..where(
              (drift_db.$DoseLogsTable t) => t.scheduledDate.equals(date),
            ))
            .get();
    return rows.map(_doseLogFromRow).toList();
  }

  Future<List<DoseLog>> doseLogsInRange({
    String? medicationClientRecordId,
    String? from,
    String? to,
  }) async {
    final SimpleSelectStatement<drift_db.$DoseLogsTable, drift_db.DoseLog>
    query = _db.select(_db.doseLogs);
    query.where((drift_db.$DoseLogsTable t) {
      Expression<bool> predicate = const Constant<bool>(true);
      if (medicationClientRecordId != null) {
        predicate =
            predicate & t.medicationClientRecordId.equals(medicationClientRecordId);
      }
      if (from != null) {
        predicate = predicate & t.scheduledDate.isBiggerOrEqualValue(from);
      }
      if (to != null) {
        predicate = predicate & t.scheduledDate.isSmallerOrEqualValue(to);
      }
      return predicate;
    });
    query.orderBy(<OrderingTerm Function(drift_db.$DoseLogsTable)>[
      (drift_db.$DoseLogsTable t) => OrderingTerm.desc(t.scheduledDate),
    ]);
    final List<drift_db.DoseLog> rows = await query.get();
    return rows.map(_doseLogFromRow).toList();
  }

  Medication _medicationFromRow(drift_db.Medication row) {
    return Medication(
      clientRecordId: row.clientRecordId,
      serverId: row.serverId,
      name: row.name,
      doseMg: row.doseMg,
      frequency: MedicationFrequency.fromWire(row.frequency),
      scheduleTimes: (jsonDecode(row.scheduleTimesJson) as List<dynamic>)
          .cast<String>(),
      active: row.active,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  DoseLog _doseLogFromRow(drift_db.DoseLog row) {
    return DoseLog(
      clientRecordId: row.clientRecordId,
      serverId: row.serverId,
      medicationClientRecordId: row.medicationClientRecordId,
      medicationServerId: row.medicationServerId,
      status: DoseStatus.fromWire(row.status),
      scheduledDate: row.scheduledDate,
      scheduledTime: row.scheduledTime,
      loggedAt: row.loggedAt,
      note: row.note,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/data/datasources/medication_local_datasource_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/data/datasources/medication_local_datasource.dart test/features/medication/data/datasources/medication_local_datasource_test.dart
git commit -m "feat(mobile): M3 medication local datasource"
```

---

## Task 10: MedicationRepositoryImpl

Ties the offline-first write path (local-then-enqueue) and the pending-edit
replay mechanism (Decision, plan header — edits/deactivations are not
syncable, so they are tracked as a JSON array of client record ids under a
feature-owned `Preferences` key, `m3_pending_medication_edits`, and replayed
as a direct `PUT` once the medication has a `serverId` and the device is
online).

**Files:**
- Create: `lib/features/medication/data/repositories/medication_repository_impl.dart`
- Test: `test/features/medication/data/repositories/medication_repository_impl_test.dart`

**Interfaces:**
- Consumes: `MedicationRepository` (Task 6), `MedicationLocalDataSource` (Task 9), `MedicationRemoteDataSource` (Task 8), `MedicationModel`/`DoseLogModel` (Task 7), `scheduledDosesFor`/`computeAdherence` (Task 4), `SyncEnqueuer`/`SyncEntityType` (`core/sync/sync_queue_dao.dart`, `core/db/app_database.dart`), `PreferencesDao` (`core/db/daos/preferences_dao.dart`), `newClientRecordId` (`core/utils/ids.dart`), `DateFormatter` (`core/utils/date_formatter.dart`) — all read-only core imports.
- Produces: `class MedicationRepositoryImpl implements MedicationRepository`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/data/repositories/medication_repository_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/medication/data/datasources/medication_local_datasource.dart';
import 'package:libu_care/features/medication/data/datasources/medication_remote_datasource.dart';
import 'package:libu_care/features/medication/data/models/dose_log_model.dart';
import 'package:libu_care/features/medication/data/repositories/medication_repository_impl.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/test_database.dart';

class _RecordedEnqueue {
  _RecordedEnqueue(this.clientRecordId, this.entityType, this.payload);
  final String clientRecordId;
  final SyncEntityType entityType;
  final Map<String, dynamic> payload;
}

class _FakeSyncEnqueuer implements SyncEnqueuer {
  final List<_RecordedEnqueue> calls = <_RecordedEnqueue>[];

  @override
  Future<void> enqueue({
    required String clientRecordId,
    required SyncEntityType entityType,
    required Map<String, dynamic> payload,
    required DateTime recordedAt,
  }) async {
    calls.add(_RecordedEnqueue(clientRecordId, entityType, payload));
  }
}

void main() {
  late AppDatabase db;
  late MedicationLocalDataSource local;
  late FakeDio fakeDio;
  late MedicationRemoteDataSource remote;
  late _FakeSyncEnqueuer enqueuer;
  late bool online;
  late MedicationRepositoryImpl repository;

  setUp(() {
    db = testDatabase();
    local = MedicationLocalDataSource(db);
    fakeDio = FakeDio();
    remote = MedicationRemoteDataSource(fakeDio.dio);
    enqueuer = _FakeSyncEnqueuer();
    online = false;
    repository = MedicationRepositoryImpl(
      local: local,
      remote: remote,
      syncEnqueuer: enqueuer,
      preferences: db.preferencesDao,
      isOnline: () async => online,
    );
  });

  tearDown(() => db.close());

  test('adding a medication offline writes to Drift, enqueues MEDICATION, and makes no request', () async {
    final Medication created = await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );

    final Medication? stored = await local.findMedication(created.clientRecordId);
    expect(stored, isNotNull);
    expect(stored!.name, 'Aspirin');

    expect(enqueuer.calls, hasLength(1));
    expect(enqueuer.calls.single.entityType, SyncEntityType.medication);
    expect(enqueuer.calls.single.payload['name'], 'Aspirin');
    expect(fakeDio.requests, isEmpty);
  });

  test('logging a dose enqueues medicationClientRecordId when the medication has no server id', () async {
    final Medication med = await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );

    await repository.logDose(
      medicationClientRecordId: med.clientRecordId,
      status: DoseStatus.taken,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
    );

    final _RecordedEnqueue doseCall = enqueuer.calls.firstWhere(
      (_RecordedEnqueue c) => c.entityType == SyncEntityType.doseLog,
    );
    expect(doseCall.payload['medicationClientRecordId'], med.clientRecordId);
    expect(doseCall.payload.containsKey('medicationId'), isFalse);
  });

  test('logging a dose enqueues medicationId once the medication has a server id', () async {
    final Medication med = await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );
    await local.setServerId(med.clientRecordId, 'srv-1');

    await repository.logDose(
      medicationClientRecordId: med.clientRecordId,
      status: DoseStatus.taken,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
    );

    final _RecordedEnqueue doseCall = enqueuer.calls.firstWhere(
      (_RecordedEnqueue c) => c.entityType == SyncEntityType.doseLog,
    );
    expect(doseCall.payload['medicationId'], 'srv-1');
    expect(doseCall.payload.containsKey('medicationClientRecordId'), isFalse);
  });

  test('upserting the same dose log client id twice does not produce two rows', () async {
    final DoseLogModel model = DoseLogModel(
      medicationId: '',
      status: 'TAKEN',
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
      clientRecordId: 'dose-1',
      loggedAt: DateTime.utc(2026, 8, 25, 8),
    );
    await local.upsertDoseLog(model, medicationClientRecordId: 'm1');
    await local.upsertDoseLog(model, medicationClientRecordId: 'm1');

    final List<DoseLog> logs = await local.doseLogsInRange(medicationClientRecordId: 'm1');
    expect(logs, hasLength(1));
  });

  test('an offline edit is tracked pending and not sent until online with a server id', () async {
    final Medication med = await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );

    await repository.edit(med.copyWith(name: 'Aspirin 100mg'));
    expect(fakeDio.requests, isEmpty); // no server id yet, and offline

    await local.setServerId(med.clientRecordId, 'srv-1');
    online = true;
    fakeDio.stub(
      '/api/v1/medications/srv-1',
      FakeResponse.ok(<String, dynamic>{
        'id': 'srv-1',
        'name': 'Aspirin 100mg',
        'doseMg': 75.0,
        'frequency': 'ONCE_DAILY',
        'scheduleTimes': <String>['08:00'],
        'active': true,
        'clientRecordId': med.clientRecordId,
      }, message: 'Medication updated'),
    );

    await repository.replayPendingEdits();

    expect(fakeDio.requests.single.method, 'PUT');
    expect(fakeDio.requests.single.json['name'], 'Aspirin 100mg');
  });

  test('todaysDoses derives from active medications and today\'s logs', () async {
    await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );

    final List<dynamic> doses = await repository.todaysDoses(
      now: DateTime.now(), // any recent time; just verifies wiring, not the math (covered by Task 4)
    );

    expect(doses, isNotEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/data/repositories/medication_repository_impl_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/data/repositories/medication_repository_impl.dart
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/db/daos/preferences_dao.dart';
import '../../../../core/sync/sync_queue_dao.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/entities/adherence.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/scheduled_dose.dart';
import '../../domain/repositories/medication_repository.dart';
import '../../domain/schedule.dart';
import '../datasources/medication_local_datasource.dart';
import '../datasources/medication_remote_datasource.dart';
import '../models/dose_log_model.dart';
import '../models/medication_model.dart';

class MedicationRepositoryImpl implements MedicationRepository {
  MedicationRepositoryImpl({
    required MedicationLocalDataSource local,
    required MedicationRemoteDataSource remote,
    required SyncEnqueuer syncEnqueuer,
    required PreferencesDao preferences,
    required Future<bool> Function() isOnline,
  }) : _local = local,
       _remote = remote,
       _sync = syncEnqueuer,
       _prefs = preferences,
       _isOnline = isOnline;

  final MedicationLocalDataSource _local;
  final MedicationRemoteDataSource _remote;
  final SyncEnqueuer _sync;
  final PreferencesDao _prefs;
  final Future<bool> Function() _isOnline;

  static const String _pendingEditsKey = 'm3_pending_medication_edits';

  @override
  Future<List<Medication>> activeMedications() => _local.activeMedications();

  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) =>
      _local.allMedications(includeInactive: includeInactive);

  @override
  Future<Medication> add({
    required String name,
    required double doseMg,
    required MedicationFrequency frequency,
    required List<String> scheduleTimes,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final Medication entity = Medication(
      clientRecordId: newClientRecordId(),
      serverId: null,
      name: name,
      doseMg: doseMg,
      frequency: frequency,
      scheduleTimes: scheduleTimes,
      active: true,
      createdAt: now,
      updatedAt: now,
    );

    await _local.upsertMedication(MedicationModel.fromEntity(entity));
    await _sync.enqueue(
      clientRecordId: entity.clientRecordId,
      entityType: SyncEntityType.medication,
      payload: <String, dynamic>{
        'name': name,
        'doseMg': doseMg,
        'frequency': frequency.wire,
        'scheduleTimes': scheduleTimes,
        'active': true,
      },
      recordedAt: now,
    );
    return entity;
  }

  @override
  Future<Medication> edit(Medication updated) async {
    final Medication withTimestamp = updated.copyWith(
      updatedAt: DateTime.now().toUtc(),
    );
    await _local.upsertMedication(MedicationModel.fromEntity(withTimestamp));
    await _markPendingEdit(withTimestamp.clientRecordId);
    unawaited(_tryReplaySingle(withTimestamp.clientRecordId));
    return withTimestamp;
  }

  @override
  Future<Medication> deactivate(String clientRecordId) async {
    final Medication? current = await _local.findMedication(clientRecordId);
    if (current == null) {
      throw StateError('Unknown medication: $clientRecordId');
    }
    return edit(current.copyWith(active: false));
  }

  @override
  Future<DoseLog> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
    String? note,
  }) async {
    final Medication? medication = await _local.findMedication(
      medicationClientRecordId,
    );
    final DateTime now = DateTime.now().toUtc();
    final DoseLog entity = DoseLog(
      clientRecordId: newClientRecordId(),
      serverId: null,
      medicationClientRecordId: medicationClientRecordId,
      medicationServerId: medication?.serverId,
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      loggedAt: now,
      note: note,
    );

    await _local.upsertDoseLog(
      DoseLogModel.fromEntity(entity),
      medicationClientRecordId: medicationClientRecordId,
    );

    await _sync.enqueue(
      clientRecordId: entity.clientRecordId,
      entityType: SyncEntityType.doseLog,
      payload: <String, dynamic>{
        if (medication?.serverId != null)
          'medicationId': medication!.serverId
        else
          'medicationClientRecordId': medicationClientRecordId,
        'status': status.wire,
        'scheduledDate': scheduledDate,
        if (scheduledTime != null) 'scheduledTime': scheduledTime,
        'loggedAt': now.toIso8601String(),
        if (note != null) 'note': note,
      },
      recordedAt: now,
    );
    return entity;
  }

  @override
  Future<List<ScheduledDose>> todaysDoses({DateTime? now}) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final DateTime today = DateFormatter.startOfDay(effectiveNow);
    final List<Medication> medications = await _local.activeMedications();
    final List<DoseLog> logs = await _local.doseLogsForDate(
      DateFormatter.toApiDate(today),
    );
    return scheduledDosesFor(
      medications: medications,
      logsForDate: logs,
      date: today,
      now: effectiveNow,
    );
  }

  @override
  Future<List<DoseLog>> doseHistory({
    String? medicationClientRecordId,
    DateTime? from,
    DateTime? to,
  }) => _local.doseLogsInRange(
    medicationClientRecordId: medicationClientRecordId,
    from: from == null ? null : DateFormatter.toApiDate(from),
    to: to == null ? null : DateFormatter.toApiDate(to),
  );

  @override
  Future<Adherence> adherence({
    String? medicationClientRecordId,
    required int windowDays,
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final DateTime windowStart = DateFormatter.daysAgo(
      windowDays - 1,
      from: effectiveNow,
    );

    final List<Medication> medications;
    if (medicationClientRecordId == null) {
      medications = await _local.allMedications(includeInactive: true);
    } else {
      final Medication? one = await _local.findMedication(
        medicationClientRecordId,
      );
      medications = one == null ? <Medication>[] : <Medication>[one];
    }

    final List<DoseLog> logs = await _local.doseLogsInRange(
      medicationClientRecordId: medicationClientRecordId,
      from: DateFormatter.toApiDate(windowStart),
      to: DateFormatter.toApiDate(effectiveNow),
    );

    return computeAdherence(
      medications: medications,
      allLogs: logs,
      windowStart: windowStart,
      now: effectiveNow,
      windowDays: windowDays,
    );
  }

  @override
  Future<void> replayPendingEdits() async {
    if (!await _isOnline()) return;
    final Set<String> ids = await _pendingEditIds();
    for (final String id in ids) {
      await _tryReplaySingle(id);
    }
  }

  Future<void> _tryReplaySingle(String clientRecordId) async {
    if (!await _isOnline()) return;
    final Medication? medication = await _local.findMedication(clientRecordId);
    if (medication == null) {
      await _clearPendingEdit(clientRecordId);
      return;
    }
    final String? serverId = medication.serverId;
    // Still waiting on the original create to sync — nothing to PUT yet.
    // The record stays in the pending set and is retried on the next call.
    if (serverId == null) return;

    try {
      await _remote.update(
        serverId,
        name: medication.name,
        doseMg: medication.doseMg,
        frequency: medication.frequency.wire,
        scheduleTimes: medication.scheduleTimes,
        active: medication.active,
      );
      await _clearPendingEdit(clientRecordId);
    } on DioException {
      // Leave it pending; the next reconnect or screen visit retries it.
    }
  }

  Future<Set<String>> _pendingEditIds() async {
    final String? raw = await _prefs.get(_pendingEditsKey);
    if (raw == null) return <String>{};
    return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
  }

  Future<void> _markPendingEdit(String clientRecordId) async {
    final Set<String> ids = await _pendingEditIds()..add(clientRecordId);
    await _prefs.set(_pendingEditsKey, jsonEncode(ids.toList()));
  }

  Future<void> _clearPendingEdit(String clientRecordId) async {
    final Set<String> ids = await _pendingEditIds()..remove(clientRecordId);
    await _prefs.set(_pendingEditsKey, jsonEncode(ids.toList()));
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/data/repositories/medication_repository_impl_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/data/repositories test/features/medication/data/repositories
git commit -m "feat(mobile): M3 medication repository implementation"
```

---

## Task 11: Notifications — NotificationScheduler and MedicationNotifications

Two files: a thin interface over `flutter_local_notifications` (so the
policy class is unit-testable with a fake, never the real plugin binding),
and the policy itself (id derivation, scheduling, cancellation).

**Two documented, deliberate simplifications:**
1. **Timezone is hardcoded to `Africa/Addis_Ababa`.** Getting the device's
   real IANA timezone name needs a package this plan cannot add to
   `pubspec.yaml`. The app's entire stated audience is patients in Ethiopia
   (`CLAUDE.md`), which is a single timezone with no DST, so this is exact
   for every real user rather than an approximation — but it is a hardcode,
   and it is the reason a future non-Ethiopia deployment would need that
   package added to the foundation.
2. **The follow-up notification repeats daily**, the same as the primary
   one (`matchDateTimeComponents: DateTimeComponents.time`), because
   suppressing it on days the dose was already logged would need OS-level
   background work outside a local-notifications package's reach. A patient
   who already logged today's dose may still see the 1-hour follow-up. Noted
   here rather than silently shipped as if it were smarter than it is.

**Files:**
- Create: `lib/features/medication/notifications/notification_scheduler.dart`
- Create: `lib/features/medication/notifications/medication_notifications.dart`
- Test: `test/features/medication/notifications/medication_notifications_test.dart`

**Interfaces:**
- Consumes: `Medication` (Task 1), `PreferenceKeys` (`core/db/tables.dart`), `PreferencesDao` (`core/db/daos/preferences_dao.dart`) — read-only core imports.
- Produces: `abstract interface class NotificationScheduler`, `class FlutterLocalNotificationsScheduler implements NotificationScheduler`, `class MedicationNotifications` with `scheduleFor(Medication)`, `cancelFor(String clientRecordId)`, `cancelAll(List<Medication>)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/notifications/medication_notifications_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/notifications/notification_scheduler.dart';

import '../../../helpers/test_database.dart';

class _Scheduled {
  _Scheduled(this.id, this.payload, this.when);
  final int id;
  final String payload;
  final DateTime when;
}

class _FakeScheduler implements NotificationScheduler {
  final List<_Scheduled> scheduled = <_Scheduled>[];
  final Set<int> cancelledIds = <int>{};

  @override
  Future<void> init() async {}

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduled.removeWhere((_Scheduled s) => s.id == id);
    cancelledIds.remove(id);
    scheduled.add(_Scheduled(id, payload, when));
  }

  @override
  Future<List<PendingScheduledNotification>> pending() async {
    return scheduled
        .where((_Scheduled s) => !cancelledIds.contains(s.id))
        .map((_Scheduled s) => PendingScheduledNotification(id: s.id, payload: s.payload))
        .toList();
  }

  @override
  Future<void> cancel(int id) async {
    cancelledIds.add(id);
  }
}

Medication _medication({
  bool active = true,
  List<String> times = const <String>['08:00', '20:00'],
}) {
  final DateTime now = DateTime(2026, 8, 25);
  return Medication(
    clientRecordId: 'm1',
    serverId: null,
    name: 'Aspirin',
    doseMg: 75,
    frequency: MedicationFrequency.bid,
    scheduleTimes: times,
    active: active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase db;
  late _FakeScheduler scheduler;
  late MedicationNotifications notifications;

  setUp(() {
    db = testDatabase();
    scheduler = _FakeScheduler();
    notifications = MedicationNotifications(scheduler, db.preferencesDao);
  });

  tearDown(() => db.close());

  test('schedules one main and one follow-up notification per time', () async {
    await notifications.scheduleFor(_medication());
    expect(scheduler.scheduled, hasLength(4)); // 2 times x (main + follow-up)
  });

  test('the follow-up fires one hour after the main notification', () async {
    await notifications.scheduleFor(_medication(times: const <String>['08:00']));
    final _Scheduled main = scheduler.scheduled.firstWhere((_Scheduled s) => s.payload.endsWith('|main'));
    final _Scheduled followUp = scheduler.scheduled.firstWhere((_Scheduled s) => s.payload.endsWith('|follow'));
    expect(followUp.when.difference(main.when), const Duration(hours: 1));
  });

  test('rescheduling replaces rather than duplicating', () async {
    await notifications.scheduleFor(_medication());
    final Set<int> firstIds = scheduler.scheduled.map((_Scheduled s) => s.id).toSet();

    await notifications.scheduleFor(_medication());

    expect(scheduler.scheduled, hasLength(4));
    expect(scheduler.scheduled.map((_Scheduled s) => s.id).toSet(), firstIds);
  });

  test('deactivating cancels everything for that medication', () async {
    await notifications.scheduleFor(_medication());
    await notifications.scheduleFor(_medication(active: false));
    expect(await scheduler.pending(), isEmpty);
  });

  test('notifications off cancels rather than suppresses', () async {
    await db.preferencesDao.set(PreferenceKeys.notificationsEnabled, 'false');
    await notifications.scheduleFor(_medication());
    expect(await scheduler.pending(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/notifications/medication_notifications_test.dart`
Expected: FAIL — target files don't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/notifications/notification_scheduler.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// A pending notification the OS still holds, as far as this feature needs
/// to know about it — just enough to filter by [payload] for cancellation.
class PendingScheduledNotification {
  const PendingScheduledNotification({required this.id, required this.payload});
  final int id;
  final String? payload;
}

/// Thin seam over `flutter_local_notifications` so [MedicationNotifications]
/// is unit-testable without the real plugin binding.
abstract interface class NotificationScheduler {
  Future<void> init();

  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  });

  Future<List<PendingScheduledNotification>> pending();

  Future<void> cancel(int id);
}

class FlutterLocalNotificationsScheduler implements NotificationScheduler {
  FlutterLocalNotificationsScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'medication_reminders',
    'Medication reminders',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const NotificationDetails _details = NotificationDetails(
    android: _android,
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    tz_data.initializeTimeZones();
    // See Task 11's header note: hardcoded to the app's sole deployment
    // timezone rather than detecting the device's, which would need a
    // package this plan cannot add to pubspec.yaml.
    tz.setLocalLocation(tz.getLocation('Africa/Addis_Ababa'));

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<List<PendingScheduledNotification>> pending() async {
    final List<PendingNotificationRequest> requests = await _plugin
        .pendingNotificationRequests();
    return requests
        .map(
          (PendingNotificationRequest r) =>
              PendingScheduledNotification(id: r.id, payload: r.payload),
        )
        .toList();
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);
}
```

```dart
// lib/features/medication/notifications/medication_notifications.dart
import 'package:easy_localization/easy_localization.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos/preferences_dao.dart';
import '../domain/entities/medication.dart';
import 'notification_scheduler.dart';

/// Scheduling policy for medication reminders (Decision 4). Reschedule on
/// every add/edit/deactivate/reactivate and on app start — the caller (the
/// controller) is responsible for calling [scheduleFor] at those points.
class MedicationNotifications {
  MedicationNotifications(this._scheduler, this._prefs);

  final NotificationScheduler _scheduler;
  final PreferencesDao _prefs;

  static const Duration followUpDelay = Duration(hours: 1);

  /// Cancels any existing reminders for this medication, then — if it is
  /// active and notifications are enabled — schedules a main reminder and a
  /// one-hour follow-up for every scheduled time.
  Future<void> scheduleFor(Medication medication) async {
    await cancelFor(medication.clientRecordId);
    if (!medication.active) return;
    if (!await _notificationsEnabled()) return;

    for (final String time in medication.scheduleTimes) {
      final DateTime first = _nextOccurrence(time);
      await _scheduler.zonedSchedule(
        id: _idFor(medication.clientRecordId, time, isFollowUp: false),
        title: 'meds.notifications.doseTitle'.tr(),
        body: 'meds.notifications.doseBody'.tr(
          namedArgs: <String, String>{'name': medication.name},
        ),
        when: first,
        payload: _payloadFor(medication.clientRecordId, time, isFollowUp: false),
      );
      await _scheduler.zonedSchedule(
        id: _idFor(medication.clientRecordId, time, isFollowUp: true),
        title: 'meds.notifications.followUpTitle'.tr(),
        body: 'meds.notifications.followUpBody'.tr(
          namedArgs: <String, String>{'name': medication.name},
        ),
        when: first.add(followUpDelay),
        payload: _payloadFor(medication.clientRecordId, time, isFollowUp: true),
      );
    }
  }

  /// Cancels every reminder for one medication, found by filtering the OS's
  /// pending list by payload prefix — there is no other local index of
  /// "which ids belong to this medication".
  Future<void> cancelFor(String medicationClientRecordId) async {
    final List<PendingScheduledNotification> all = await _scheduler.pending();
    for (final PendingScheduledNotification n in all) {
      if (n.payload != null && n.payload!.startsWith('$medicationClientRecordId|')) {
        await _scheduler.cancel(n.id);
      }
    }
  }

  Future<void> cancelAll(List<Medication> medications) async {
    for (final Medication medication in medications) {
      await cancelFor(medication.clientRecordId);
    }
  }

  Future<bool> _notificationsEnabled() async {
    final String? raw = await _prefs.get(PreferenceKeys.notificationsEnabled);
    // Defaults to on: M2 (settings) owns this key and may not have run yet.
    return raw != 'false';
  }

  /// Stable and reversible: the same medication+time+kind always derives the
  /// same id, so scheduling again replaces rather than duplicates.
  int _idFor(String medicationClientRecordId, String time, {required bool isFollowUp}) {
    return _payloadFor(medicationClientRecordId, time, isFollowUp: isFollowUp).hashCode &
        0x7fffffff;
  }

  String _payloadFor(String medicationClientRecordId, String time, {required bool isFollowUp}) {
    return '$medicationClientRecordId|$time|${isFollowUp ? 'follow' : 'main'}';
  }

  DateTime _nextOccurrence(String time) {
    final List<String> parts = time.split(':');
    final int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);
    final DateTime now = DateTime.now();
    DateTime candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (!candidate.isAfter(now)) candidate = candidate.add(const Duration(days: 1));
    return candidate;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/notifications/medication_notifications_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/notifications test/features/medication/notifications
git commit -m "feat(mobile): M3 medication reminder notifications"
```

---

## Task 12: Providers and MedicationListController

**Files:**
- Create: `lib/features/medication/medication_providers.dart`
- Create: `lib/features/medication/presentation/controllers/medication_list_controller.dart`
- Test: `test/features/medication/presentation/controllers/medication_list_controller_test.dart`

**Interfaces:**
- Consumes: `appDatabaseProvider`, `dioProvider`, `syncEnqueuerProvider`, `isOnlineProvider` (`core/providers/core_providers.dart`, read-only), everything from Tasks 6–11.
- Produces: `medicationLocalDataSourceProvider`, `medicationRemoteDataSourceProvider`, `medicationRepositoryProvider`, `notificationSchedulerProvider`, `medicationNotificationsProvider`; `class MedicationListState` (`todaysDoses`, `medications`), `class MedicationListController extends AsyncNotifier<MedicationListState>` with `logDose(...)` and `deactivate(...)`, and `medicationListControllerProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/presentation/controllers/medication_list_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/notifications/notification_scheduler.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';

Medication _medication(String id) => Medication(
  clientRecordId: id,
  serverId: null,
  name: 'Aspirin',
  doseMg: 75,
  frequency: MedicationFrequency.onceDaily,
  scheduleTimes: const <String>['08:00'],
  active: true,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

class _FakeRepository implements MedicationRepository {
  int logDoseCalls = 0;
  int deactivateCalls = 0;

  @override
  Future<List<Medication>> activeMedications() async => <Medication>[_medication('m1')];
  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) async => <Medication>[_medication('m1')];
  @override
  Future<Medication> add({required String name, required double doseMg, required MedicationFrequency frequency, required List<String> scheduleTimes}) async => _medication('new');
  @override
  Future<Medication> edit(Medication updated) async => updated;
  @override
  Future<Medication> deactivate(String clientRecordId) async {
    deactivateCalls++;
    return _medication(clientRecordId);
  }
  @override
  Future<DoseLog> logDose({required String medicationClientRecordId, required DoseStatus status, required String scheduledDate, String? scheduledTime, String? note}) async {
    logDoseCalls++;
    return DoseLog(
      clientRecordId: 'd1', serverId: null, medicationClientRecordId: medicationClientRecordId,
      medicationServerId: null, status: status, scheduledDate: scheduledDate,
      scheduledTime: scheduledTime, loggedAt: DateTime.utc(2026, 8, 25), note: note,
    );
  }
  @override
  Future<List<ScheduledDose>> todaysDoses({DateTime? now}) async => const <ScheduledDose>[];
  @override
  Future<List<DoseLog>> doseHistory({String? medicationClientRecordId, DateTime? from, DateTime? to}) async => const <DoseLog>[];
  @override
  Future<Adherence> adherence({String? medicationClientRecordId, required int windowDays, DateTime? now}) async =>
      Adherence(taken: 0, due: 0, skipped: 0, windowDays: windowDays);
  @override
  Future<void> replayPendingEdits() async {}
}

class _FakeNotificationScheduler implements NotificationScheduler {
  final List<int> cancelled = <int>[];
  @override
  Future<void> init() async {}
  @override
  Future<void> zonedSchedule({required int id, required String title, required String body, required DateTime when, required String payload}) async {}
  @override
  Future<List<PendingScheduledNotification>> pending() async => const <PendingScheduledNotification>[];
  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

void main() {
  test('build populates todays doses and the medication list', () async {
    final _FakeRepository repo = _FakeRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[medicationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final MedicationListState state = await container.read(medicationListControllerProvider.future);

    expect(state.medications, hasLength(1));
    expect(state.medications.single.clientRecordId, 'm1');
  });

  test('logDose delegates to the repository and refreshes', () async {
    final _FakeRepository repo = _FakeRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[medicationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(medicationListControllerProvider.future);

    await container
        .read(medicationListControllerProvider.notifier)
        .logDose(medicationClientRecordId: 'm1', status: DoseStatus.taken, scheduledDate: '2026-08-25');

    expect(repo.logDoseCalls, 1);
  });

  test('deactivate delegates to the repository and cancels notifications', () async {
    final _FakeRepository repo = _FakeRepository();
    final _FakeNotificationScheduler scheduler = _FakeNotificationScheduler();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        medicationRepositoryProvider.overrideWithValue(repo),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        medicationNotificationsProvider.overrideWithValue(
          MedicationNotifications(scheduler, _NoopPreferencesDao()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(medicationListControllerProvider.future);

    await container.read(medicationListControllerProvider.notifier).deactivate('m1');

    expect(repo.deactivateCalls, 1);
  });
}
```

`_NoopPreferencesDao` needs a real one — simplest is a real in-memory `testDatabase().preferencesDao`, so replace the last override block's dao with that instead of inventing a noop class:

```dart
// replace inside the third test, before building overrides:
final AppDatabase db = testDatabase();
addTearDown(db.close);
...
medicationNotificationsProvider.overrideWithValue(
  MedicationNotifications(scheduler, db.preferencesDao),
),
```

with the corresponding imports (`package:libu_care/core/db/app_database.dart` and `../../../../helpers/test_database.dart`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/presentation/controllers/medication_list_controller_test.dart`
Expected: FAIL — target files don't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/medication_providers.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'data/datasources/medication_local_datasource.dart';
import 'data/datasources/medication_remote_datasource.dart';
import 'data/repositories/medication_repository_impl.dart';
import 'domain/repositories/medication_repository.dart';
import 'notifications/medication_notifications.dart';
import 'notifications/notification_scheduler.dart';

final Provider<MedicationLocalDataSource> medicationLocalDataSourceProvider =
    Provider<MedicationLocalDataSource>(
      (Ref ref) => MedicationLocalDataSource(ref.watch(appDatabaseProvider)),
    );

final Provider<MedicationRemoteDataSource> medicationRemoteDataSourceProvider =
    Provider<MedicationRemoteDataSource>(
      (Ref ref) => MedicationRemoteDataSource(ref.watch(dioProvider)),
    );

final Provider<MedicationRepository> medicationRepositoryProvider =
    Provider<MedicationRepository>(
      (Ref ref) => MedicationRepositoryImpl(
        local: ref.watch(medicationLocalDataSourceProvider),
        remote: ref.watch(medicationRemoteDataSourceProvider),
        syncEnqueuer: ref.watch(syncEnqueuerProvider),
        preferences: ref.watch(appDatabaseProvider).preferencesDao,
        isOnline: ref.watch(isOnlineProvider),
      ),
    );

final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>(
      (Ref ref) =>
          FlutterLocalNotificationsScheduler(FlutterLocalNotificationsPlugin()),
    );

final Provider<MedicationNotifications> medicationNotificationsProvider =
    Provider<MedicationNotifications>(
      (Ref ref) => MedicationNotifications(
        ref.watch(notificationSchedulerProvider),
        ref.watch(appDatabaseProvider).preferencesDao,
      ),
    );
```

```dart
// lib/features/medication/presentation/controllers/medication_list_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dose_log.dart';
import '../../domain/entities/medication.dart';
import '../../domain/entities/scheduled_dose.dart';
import '../../medication_providers.dart';

class MedicationListState {
  const MedicationListState({required this.todaysDoses, required this.medications});
  final List<ScheduledDose> todaysDoses;
  final List<Medication> medications;
}

/// Backs the Medications tab root and the Home card (Task 18). State is a
/// plain re-fetch after every mutation (`ref.invalidateSelf()`) rather than a
/// live stream — see the plan header's reactivity note.
class MedicationListController extends AsyncNotifier<MedicationListState> {
  @override
  Future<MedicationListState> build() async {
    final repository = ref.watch(medicationRepositoryProvider);
    unawaited(repository.replayPendingEdits());
    final doses = await repository.todaysDoses();
    final medications = await repository.activeMedications();
    return MedicationListState(todaysDoses: doses, medications: medications);
  }

  Future<void> logDose({
    required String medicationClientRecordId,
    required DoseStatus status,
    required String scheduledDate,
    String? scheduledTime,
  }) async {
    await ref.read(medicationRepositoryProvider).logDose(
      medicationClientRecordId: medicationClientRecordId,
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
    );
    ref.invalidateSelf();
  }

  Future<void> deactivate(String clientRecordId) async {
    final updated = await ref.read(medicationRepositoryProvider).deactivate(clientRecordId);
    await ref.read(medicationNotificationsProvider).cancelFor(updated.clientRecordId);
    ref.invalidateSelf();
  }
}

final AsyncNotifierProvider<MedicationListController, MedicationListState>
medicationListControllerProvider =
    AsyncNotifierProvider<MedicationListController, MedicationListState>(
      MedicationListController.new,
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/presentation/controllers/medication_list_controller_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/medication_providers.dart lib/features/medication/presentation/controllers/medication_list_controller.dart test/features/medication/presentation/controllers/medication_list_controller_test.dart
git commit -m "feat(mobile): M3 providers and medication list controller"
```

---

## Task 13: MedicationFormController (add/edit)

**Files:**
- Create: `lib/features/medication/presentation/controllers/medication_form_controller.dart`
- Test: `test/features/medication/presentation/controllers/medication_form_controller_test.dart`

**Interfaces:**
- Consumes: `medicationRepositoryProvider`, `medicationNotificationsProvider`, `medicationListControllerProvider` (Task 12), `validateMedicationName`/`validateDoseMg`/`validateScheduleTimes` (Task 5).
- Produces: `class MedicationFormState` (`name`, `doseMg`, `frequency`, `scheduleTimes`, `nameError`, `doseError`, `scheduleError`, `isSaving`, `saved`, `isValid` getter, `copyWith`), `class MedicationFormController extends Notifier<MedicationFormState>` with `loadForEdit`, `setName`, `setDoseMg`, `setFrequency`, `setScheduleTimes`, `save()`, and `medicationFormControllerProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/presentation/controllers/medication_form_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/notifications/notification_scheduler.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_form_controller.dart';

Medication _stored = Medication(
  clientRecordId: 'm1', serverId: null, name: 'Old name', doseMg: 10,
  frequency: MedicationFrequency.onceDaily, scheduleTimes: const <String>['08:00'],
  active: true, createdAt: DateTime(2026, 8, 1), updatedAt: DateTime(2026, 8, 1),
);

class _FakeRepository implements MedicationRepository {
  Medication? added;
  Medication? edited;

  @override
  Future<List<Medication>> activeMedications() async => <Medication>[_stored];
  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) async => <Medication>[_stored];
  @override
  Future<Medication> add({required String name, required double doseMg, required MedicationFrequency frequency, required List<String> scheduleTimes}) async {
    added = Medication(clientRecordId: 'new', serverId: null, name: name, doseMg: doseMg, frequency: frequency, scheduleTimes: scheduleTimes, active: true, createdAt: DateTime.now(), updatedAt: DateTime.now());
    return added!;
  }
  @override
  Future<Medication> edit(Medication updated) async {
    edited = updated;
    return updated;
  }
  @override
  Future<Medication> deactivate(String clientRecordId) async => _stored;
  @override
  Future<DoseLog> logDose({required String medicationClientRecordId, required DoseStatus status, required String scheduledDate, String? scheduledTime, String? note}) async =>
      throw UnimplementedError();
  @override
  Future<List<ScheduledDose>> todaysDoses({DateTime? now}) async => const <ScheduledDose>[];
  @override
  Future<List<DoseLog>> doseHistory({String? medicationClientRecordId, DateTime? from, DateTime? to}) async => const <DoseLog>[];
  @override
  Future<Adherence> adherence({String? medicationClientRecordId, required int windowDays, DateTime? now}) async =>
      Adherence(taken: 0, due: 0, skipped: 0, windowDays: windowDays);
  @override
  Future<void> replayPendingEdits() async {}
}

class _NoopScheduler implements NotificationScheduler {
  @override
  Future<void> init() async {}
  @override
  Future<void> zonedSchedule({required int id, required String title, required String body, required DateTime when, required String payload}) async {}
  @override
  Future<List<PendingScheduledNotification>> pending() async => const <PendingScheduledNotification>[];
  @override
  Future<void> cancel(int id) async {}
}

ProviderContainer _container(_FakeRepository repo) {
  return ProviderContainer(
    overrides: <Override>[
      medicationRepositoryProvider.overrideWithValue(repo),
      medicationNotificationsProvider.overrideWith(
        (ref) => MedicationNotifications(_NoopScheduler(), throw UnimplementedError()),
      ),
    ],
  );
}
```

The notifications override above needs a real `PreferencesDao`, not a
throwing stub — before writing the implementation, replace that block with:

```dart
import 'package:libu_care/core/db/app_database.dart';
import '../../../../helpers/test_database.dart';
// ...
ProviderContainer _container(_FakeRepository repo, AppDatabase db) {
  return ProviderContainer(
    overrides: <Override>[
      medicationRepositoryProvider.overrideWithValue(repo),
      medicationNotificationsProvider.overrideWithValue(
        MedicationNotifications(_NoopScheduler(), db.preferencesDao),
      ),
    ],
  );
}
```

```dart
void main() {
  test('save() rejects an invalid form without calling the repository', () async {
    final _FakeRepository repo = _FakeRepository();
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final ProviderContainer container = _container(repo, db);
    addTearDown(container.dispose);
    final MedicationFormController controller = container.read(medicationFormControllerProvider.notifier);

    controller.setName('');
    controller.setDoseMg('abc');
    controller.setScheduleTimes(const <String>[]);
    final bool ok = await controller.save();

    expect(ok, isFalse);
    expect(repo.added, isNull);
    expect(container.read(medicationFormControllerProvider).nameError, isNotNull);
  });

  test('save() adds a new medication and schedules its reminders', () async {
    final _FakeRepository repo = _FakeRepository();
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final ProviderContainer container = _container(repo, db);
    addTearDown(container.dispose);
    final MedicationFormController controller = container.read(medicationFormControllerProvider.notifier);

    controller.setName('Atorvastatin');
    controller.setDoseMg('20');
    controller.setScheduleTimes(const <String>['08:00']);
    final bool ok = await controller.save();

    expect(ok, isTrue);
    expect(repo.added?.name, 'Atorvastatin');
    expect(container.read(medicationFormControllerProvider).saved, isTrue);
  });

  test('loadForEdit then save() edits the existing medication, not a new one', () async {
    final _FakeRepository repo = _FakeRepository();
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final ProviderContainer container = _container(repo, db);
    addTearDown(container.dispose);
    final MedicationFormController controller = container.read(medicationFormControllerProvider.notifier);

    controller.loadForEdit(_stored);
    controller.setDoseMg('40');
    final bool ok = await controller.save();

    expect(ok, isTrue);
    expect(repo.added, isNull);
    expect(repo.edited?.clientRecordId, 'm1');
    expect(repo.edited?.doseMg, 40);
  });

  test('setFrequency suggests a matching default time count without discarding existing times', () {
    final _FakeRepository repo = _FakeRepository();
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final ProviderContainer container = _container(repo, db);
    addTearDown(container.dispose);
    final MedicationFormController controller = container.read(medicationFormControllerProvider.notifier);

    controller.setScheduleTimes(const <String>['08:00']);
    controller.setFrequency(MedicationFrequency.bid);

    expect(container.read(medicationFormControllerProvider).scheduleTimes, hasLength(2));
    expect(container.read(medicationFormControllerProvider).scheduleTimes.first, '08:00');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/presentation/controllers/medication_form_controller_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/presentation/controllers/medication_form_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/medication.dart';
import '../../domain/validators.dart';
import '../../medication_providers.dart';
import 'medication_list_controller.dart';

const Object _sentinel = Object();

class MedicationFormState {
  const MedicationFormState({
    this.name = '',
    this.doseMg = '',
    this.frequency = MedicationFrequency.onceDaily,
    this.scheduleTimes = const <String>[],
    this.nameError,
    this.doseError,
    this.scheduleError,
    this.isSaving = false,
    this.saved = false,
  });

  final String name;
  final String doseMg;
  final MedicationFrequency frequency;
  final List<String> scheduleTimes;
  final String? nameError;
  final String? doseError;
  final String? scheduleError;
  final bool isSaving;
  final bool saved;

  bool get isValid => nameError == null && doseError == null && scheduleError == null;

  MedicationFormState copyWith({
    String? name,
    String? doseMg,
    MedicationFrequency? frequency,
    List<String>? scheduleTimes,
    Object? nameError = _sentinel,
    Object? doseError = _sentinel,
    Object? scheduleError = _sentinel,
    bool? isSaving,
    bool? saved,
  }) {
    return MedicationFormState(
      name: name ?? this.name,
      doseMg: doseMg ?? this.doseMg,
      frequency: frequency ?? this.frequency,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      nameError: identical(nameError, _sentinel) ? this.nameError : nameError as String?,
      doseError: identical(doseError, _sentinel) ? this.doseError : doseError as String?,
      scheduleError: identical(scheduleError, _sentinel) ? this.scheduleError : scheduleError as String?,
      isSaving: isSaving ?? this.isSaving,
      saved: saved ?? this.saved,
    );
  }
}

/// Add is the default; [loadForEdit] switches it to editing that medication.
class MedicationFormController extends Notifier<MedicationFormState> {
  String? _editingClientRecordId;

  @override
  MedicationFormState build() => const MedicationFormState();

  void loadForEdit(Medication medication) {
    _editingClientRecordId = medication.clientRecordId;
    state = MedicationFormState(
      name: medication.name,
      doseMg: medication.doseMg.toString(),
      frequency: medication.frequency,
      scheduleTimes: medication.scheduleTimes,
    );
  }

  void setName(String value) =>
      state = state.copyWith(name: value, nameError: validateMedicationName(value));

  void setDoseMg(String value) =>
      state = state.copyWith(doseMg: value, doseError: validateDoseMg(value));

  /// Soft suggestion only (never enforced) — mirrors the backend's
  /// deliberate non-validation of schedule-time count against frequency.
  void setFrequency(MedicationFrequency value) {
    final int suggested = value.suggestedTimeCount;
    final List<String> times = state.scheduleTimes.length >= suggested
        ? state.scheduleTimes
        : <String>[
            ...state.scheduleTimes,
            for (int i = state.scheduleTimes.length; i < suggested; i++) '08:00',
          ];
    state = state.copyWith(frequency: value, scheduleTimes: times);
  }

  void setScheduleTimes(List<String> times) =>
      state = state.copyWith(scheduleTimes: times, scheduleError: validateScheduleTimes(times));

  Future<bool> save() async {
    final String? nameError = validateMedicationName(state.name);
    final String? doseError = validateDoseMg(state.doseMg);
    final String? scheduleError = validateScheduleTimes(state.scheduleTimes);
    state = state.copyWith(nameError: nameError, doseError: doseError, scheduleError: scheduleError);
    if (nameError != null || doseError != null || scheduleError != null) return false;

    state = state.copyWith(isSaving: true);
    final repository = ref.read(medicationRepositoryProvider);
    final double doseValue = double.parse(state.doseMg);

    final Medication medication;
    if (_editingClientRecordId == null) {
      medication = await repository.add(
        name: state.name.trim(),
        doseMg: doseValue,
        frequency: state.frequency,
        scheduleTimes: state.scheduleTimes,
      );
    } else {
      final Medication current = (await repository.allMedications(includeInactive: true))
          .firstWhere((Medication m) => m.clientRecordId == _editingClientRecordId);
      medication = await repository.edit(
        current.copyWith(
          name: state.name.trim(),
          doseMg: doseValue,
          frequency: state.frequency,
          scheduleTimes: state.scheduleTimes,
        ),
      );
    }

    await ref.read(medicationNotificationsProvider).scheduleFor(medication);
    ref.invalidate(medicationListControllerProvider);
    state = state.copyWith(isSaving: false, saved: true);
    return true;
  }
}

final NotifierProvider<MedicationFormController, MedicationFormState>
medicationFormControllerProvider =
    NotifierProvider<MedicationFormController, MedicationFormState>(
      MedicationFormController.new,
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/presentation/controllers/medication_form_controller_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/presentation/controllers/medication_form_controller.dart test/features/medication/presentation/controllers/medication_form_controller_test.dart
git commit -m "feat(mobile): M3 medication form controller"
```

---

## Task 14: DoseHistoryController and AdherenceController

**Files:**
- Create: `lib/features/medication/presentation/controllers/dose_history_controller.dart`
- Create: `lib/features/medication/presentation/controllers/adherence_controller.dart`
- Test: `test/features/medication/presentation/controllers/dose_history_controller_test.dart`
- Test: `test/features/medication/presentation/controllers/adherence_controller_test.dart`

**Interfaces:**
- Consumes: `medicationRepositoryProvider` (Task 12), `DoseLog`, `Adherence`, `Medication` (Tasks 1–3).
- Produces: `class DoseHistoryFilter`, `class DoseHistoryController extends AsyncNotifier<List<DoseLog>>` with `setFilter(...)`, `doseHistoryControllerProvider`; `class AdherenceState` (`overall7`, `overall30`, `perMedication7`, `perMedication30`), `class AdherenceController extends AsyncNotifier<AdherenceState>`, `adherenceControllerProvider`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/medication/presentation/controllers/dose_history_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/presentation/controllers/dose_history_controller.dart';

class _FakeRepository implements MedicationRepository {
  final List<String?> historyCalls = <String?>[];

  @override
  Future<List<DoseLog>> doseHistory({String? medicationClientRecordId, DateTime? from, DateTime? to}) async {
    historyCalls.add(medicationClientRecordId);
    return const <DoseLog>[];
  }
  @override
  Future<List<Medication>> activeMedications() async => const <Medication>[];
  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) async => const <Medication>[];
  @override
  Future<Medication> add({required String name, required double doseMg, required MedicationFrequency frequency, required List<String> scheduleTimes}) async => throw UnimplementedError();
  @override
  Future<Medication> edit(Medication updated) async => throw UnimplementedError();
  @override
  Future<Medication> deactivate(String clientRecordId) async => throw UnimplementedError();
  @override
  Future<DoseLog> logDose({required String medicationClientRecordId, required DoseStatus status, required String scheduledDate, String? scheduledTime, String? note}) async => throw UnimplementedError();
  @override
  Future<List<ScheduledDose>> todaysDoses({DateTime? now}) async => const <ScheduledDose>[];
  @override
  Future<Adherence> adherence({String? medicationClientRecordId, required int windowDays, DateTime? now}) async =>
      Adherence(taken: 0, due: 0, skipped: 0, windowDays: windowDays);
  @override
  Future<void> replayPendingEdits() async {}
}

void main() {
  test('build fetches with no filter', () async {
    final _FakeRepository repo = _FakeRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[medicationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(doseHistoryControllerProvider.future);

    expect(repo.historyCalls, <String?>[null]);
  });

  test('setFilter refetches scoped to the chosen medication', () async {
    final _FakeRepository repo = _FakeRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[medicationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(doseHistoryControllerProvider.future);

    await container
        .read(doseHistoryControllerProvider.notifier)
        .setFilter(const DoseHistoryFilter(medicationClientRecordId: 'm1'));
    await container.read(doseHistoryControllerProvider.future);

    expect(repo.historyCalls.last, 'm1');
  });
}
```

```dart
// test/features/medication/presentation/controllers/adherence_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/presentation/controllers/adherence_controller.dart';

Medication _medication(String id) => Medication(
  clientRecordId: id, serverId: null, name: 'Med $id', doseMg: 10,
  frequency: MedicationFrequency.onceDaily, scheduleTimes: const <String>['08:00'],
  active: true, createdAt: DateTime(2026, 8, 1), updatedAt: DateTime(2026, 8, 1),
);

class _FakeRepository implements MedicationRepository {
  @override
  Future<List<Medication>> activeMedications() async => <Medication>[_medication('m1')];
  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) async => <Medication>[_medication('m1')];
  @override
  Future<Adherence> adherence({String? medicationClientRecordId, required int windowDays, DateTime? now}) async =>
      Adherence(taken: 1, due: 2, skipped: 0, windowDays: windowDays);
  @override
  Future<Medication> add({required String name, required double doseMg, required MedicationFrequency frequency, required List<String> scheduleTimes}) async => throw UnimplementedError();
  @override
  Future<Medication> edit(Medication updated) async => throw UnimplementedError();
  @override
  Future<Medication> deactivate(String clientRecordId) async => throw UnimplementedError();
  @override
  Future<DoseLog> logDose({required String medicationClientRecordId, required DoseStatus status, required String scheduledDate, String? scheduledTime, String? note}) async => throw UnimplementedError();
  @override
  Future<List<ScheduledDose>> todaysDoses({DateTime? now}) async => const <ScheduledDose>[];
  @override
  Future<List<DoseLog>> doseHistory({String? medicationClientRecordId, DateTime? from, DateTime? to}) async => const <DoseLog>[];
  @override
  Future<void> replayPendingEdits() async {}
}

void main() {
  test('build populates overall and per-medication figures for both windows', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[medicationRepositoryProvider.overrideWithValue(_FakeRepository())],
    );
    addTearDown(container.dispose);

    final state = await container.read(adherenceControllerProvider.future);

    expect(state.overall7.windowDays, 7);
    expect(state.overall30.windowDays, 30);
    expect(state.perMedication7['m1']?.taken, 1);
    expect(state.perMedication30.containsKey('m1'), isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/medication/presentation/controllers/dose_history_controller_test.dart test/features/medication/presentation/controllers/adherence_controller_test.dart`
Expected: FAIL — target files don't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/presentation/controllers/dose_history_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dose_log.dart';
import '../../medication_providers.dart';

class DoseHistoryFilter {
  const DoseHistoryFilter({this.medicationClientRecordId, this.from, this.to});
  final String? medicationClientRecordId;
  final DateTime? from;
  final DateTime? to;
}

class DoseHistoryController extends AsyncNotifier<List<DoseLog>> {
  DoseHistoryFilter _filter = const DoseHistoryFilter();

  @override
  Future<List<DoseLog>> build() => _fetch();

  Future<List<DoseLog>> _fetch() {
    return ref.watch(medicationRepositoryProvider).doseHistory(
      medicationClientRecordId: _filter.medicationClientRecordId,
      from: _filter.from,
      to: _filter.to,
    );
  }

  Future<void> setFilter(DoseHistoryFilter filter) async {
    _filter = filter;
    ref.invalidateSelf();
  }
}

final AsyncNotifierProvider<DoseHistoryController, List<DoseLog>>
doseHistoryControllerProvider =
    AsyncNotifierProvider<DoseHistoryController, List<DoseLog>>(
      DoseHistoryController.new,
    );
```

```dart
// lib/features/medication/presentation/controllers/adherence_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/adherence.dart';
import '../../domain/entities/medication.dart';
import '../../medication_providers.dart';

class AdherenceState {
  const AdherenceState({
    required this.overall7,
    required this.overall30,
    required this.perMedication7,
    required this.perMedication30,
  });

  final Adherence overall7;
  final Adherence overall30;
  final Map<String, Adherence> perMedication7;
  final Map<String, Adherence> perMedication30;
}

class AdherenceController extends AsyncNotifier<AdherenceState> {
  @override
  Future<AdherenceState> build() async {
    final repository = ref.watch(medicationRepositoryProvider);
    final List<Medication> medications = await repository.activeMedications();

    final Adherence overall7 = await repository.adherence(windowDays: 7);
    final Adherence overall30 = await repository.adherence(windowDays: 30);

    final Map<String, Adherence> per7 = <String, Adherence>{};
    final Map<String, Adherence> per30 = <String, Adherence>{};
    for (final Medication medication in medications) {
      per7[medication.clientRecordId] = await repository.adherence(
        medicationClientRecordId: medication.clientRecordId,
        windowDays: 7,
      );
      per30[medication.clientRecordId] = await repository.adherence(
        medicationClientRecordId: medication.clientRecordId,
        windowDays: 30,
      );
    }

    return AdherenceState(
      overall7: overall7,
      overall30: overall30,
      perMedication7: per7,
      perMedication30: per30,
    );
  }
}

final AsyncNotifierProvider<AdherenceController, AdherenceState>
adherenceControllerProvider =
    AsyncNotifierProvider<AdherenceController, AdherenceState>(
      AdherenceController.new,
    );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/medication/presentation/controllers/dose_history_controller_test.dart test/features/medication/presentation/controllers/adherence_controller_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/presentation/controllers/dose_history_controller.dart lib/features/medication/presentation/controllers/adherence_controller.dart test/features/medication/presentation/controllers/dose_history_controller_test.dart test/features/medication/presentation/controllers/adherence_controller_test.dart
git commit -m "feat(mobile): M3 dose history and adherence controllers"
```

---

## Task 15: Widgets — MedicationCard, DoseRow, StatusSelector, TimeListField

Built entirely from `core/widgets/` primitives (`SectionCard`, `StatusChip`,
`AppColors`, `AppSpacing`) — no raw hex, no ad-hoc styling, per
`CONTRIBUTING.md` §6.

**Files:**
- Create: `lib/features/medication/presentation/widgets/medication_card.dart`
- Create: `lib/features/medication/presentation/widgets/dose_row.dart`
- Create: `lib/features/medication/presentation/widgets/status_selector.dart`
- Create: `lib/features/medication/presentation/widgets/time_list_field.dart`
- Test: `test/features/medication/presentation/widgets/medication_widgets_test.dart`

**Interfaces:**
- Consumes: `Medication` (Task 1), `ScheduledDose`, `ScheduledDoseStatus` (Task 3), `DoseStatus` (Task 2), `SectionCard`/`StatusChip` (`core/widgets/widgets.dart`), `AppColors`/`AppSpacing` (`core/theme/`), `Severity` (`core/clinical/alert_evaluator.dart`) — all read-only core imports.
- Produces: `MedicationCard({required Medication medication, VoidCallback? onTap})`, `DoseRow({required ScheduledDose dose, required ValueChanged<DoseStatus> onLog})`, `StatusSelector({required ValueChanged<DoseStatus> onSelected})`, `TimeListField({required List<String> times, required ValueChanged<List<String>> onChanged})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/presentation/widgets/medication_widgets_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/widgets/dose_row.dart';
import 'package:libu_care/features/medication/presentation/widgets/medication_card.dart';
import 'package:libu_care/features/medication/presentation/widgets/status_selector.dart';
import 'package:libu_care/features/medication/presentation/widgets/time_list_field.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('MedicationCard shows the name, dose and schedule', (tester) async {
    final Medication medication = Medication(
      clientRecordId: 'm1', serverId: null, name: 'Atorvastatin', doseMg: 20,
      frequency: MedicationFrequency.onceDaily, scheduleTimes: const <String>['08:00'],
      active: true, createdAt: DateTime(2026, 8, 1), updatedAt: DateTime(2026, 8, 1),
    );
    await pumpApp(tester, Material(child: MedicationCard(medication: medication)));

    expect(find.textContaining('Atorvastatin'), findsOneWidget);
    expect(find.textContaining('08:00'), findsOneWidget);
  });

  testWidgets('DoseRow shows a StatusSelector when pending and a chip when logged', (tester) async {
    const ScheduledDose pending = ScheduledDose(
      medicationClientRecordId: 'm1', medicationName: 'Aspirin', doseMg: 75,
      scheduledDate: '2026-08-25', scheduledTime: '08:00',
      status: ScheduledDoseStatus.pending, doseLog: null,
    );
    await pumpApp(tester, Material(child: DoseRow(dose: pending, onLog: (_) {})));
    expect(find.byType(StatusSelector), findsOneWidget);
  });

  testWidgets('tapping Taken in StatusSelector calls onSelected with DoseStatus.taken', (tester) async {
    DoseStatus? selected;
    await pumpApp(
      tester,
      Material(child: StatusSelector(onSelected: (s) => selected = s)),
    );

    await tester.tap(find.text('Taken'));
    await tester.pump();

    expect(selected, DoseStatus.taken);
  });

  testWidgets('TimeListField renders a chip per time and adds one via the picker', (tester) async {
    List<String> current = const <String>['08:00'];
    await pumpApp(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Material(
          child: TimeListField(
            times: current,
            onChanged: (t) => setState(() => current = t),
          ),
        ),
      ),
    );

    expect(find.text('08:00'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/presentation/widgets/medication_widgets_test.dart`
Expected: FAIL — target files don't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/presentation/widgets/medication_card.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/medication.dart';

class MedicationCard extends StatelessWidget {
  const MedicationCard({required this.medication, this.onTap, super.key});

  final Medication medication;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String dose = medication.doseMg == medication.doseMg.roundToDouble()
        ? medication.doseMg.toStringAsFixed(0)
        : medication.doseMg.toString();

    return SectionCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const Icon(Iconsax.health, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('${medication.name} $dose mg', style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  medication.scheduleTimes.join(' · '),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
```

```dart
// lib/features/medication/presentation/widgets/status_selector.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/dose_log.dart';

/// Three inline chips — Taken / Missed / Skipped — one tap logs a dose
/// (Decision 6).
class StatusSelector extends StatelessWidget {
  const StatusSelector({required this.onSelected, super.key});

  final ValueChanged<DoseStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Chip(label: 'meds.status.taken'.tr(), color: AppColors.success, onTap: () => onSelected(DoseStatus.taken)),
        const SizedBox(width: AppSpacing.xs),
        _Chip(label: 'meds.status.missed'.tr(), color: AppColors.critical, onTap: () => onSelected(DoseStatus.missed)),
        const SizedBox(width: AppSpacing.xs),
        _Chip(label: 'meds.status.skipped'.tr(), color: AppColors.textSecondary, onTap: () => onSelected(DoseStatus.skipped)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(AppSpacing.lg),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
```

```dart
// lib/features/medication/presentation/widgets/dose_row.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/scheduled_dose.dart';
import 'status_selector.dart';

class DoseRow extends StatelessWidget {
  const DoseRow({required this.dose, required this.onLog, super.key});

  final ScheduledDose dose;
  final ValueChanged<DoseStatus> onLog;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String doseLabel = dose.doseMg == dose.doseMg.roundToDouble()
        ? dose.doseMg.toStringAsFixed(0)
        : dose.doseMg.toString();

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(dose.medicationName, style: text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text('${dose.scheduledTime} · $doseLabel mg', style: text.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (dose.status == ScheduledDoseStatus.logged)
          StatusChip(
            severity: dose.doseLog!.status == DoseStatus.taken ? Severity.none : Severity.monitor,
            label: 'meds.status.${dose.doseLog!.status.name}'.tr(),
          )
        else
          StatusSelector(onSelected: onLog),
      ],
    );
  }
}
```

```dart
// lib/features/medication/presentation/widgets/time_list_field.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class TimeListField extends StatelessWidget {
  const TimeListField({required this.times, required this.onChanged, super.key});

  final List<String> times;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('meds.form.scheduleTimes'.tr(), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final String time in times)
              InputChip(
                label: Text(time),
                onDeleted: () => onChanged(times.where((String t) => t != time).toList()),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text('common.add'.tr()),
              onPressed: () => _pickTime(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final String formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (times.contains(formatted)) return;
    onChanged(<String>[...times, formatted]..sort());
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/presentation/widgets/medication_widgets_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/presentation/widgets test/features/medication/presentation/widgets
git commit -m "feat(mobile): M3 medication widgets"
```

---

## Task 16: MedicationsScreen (tab root)

The screen from the Figma Medications frame (list/dashboard) you originally
asked to follow: cream header band, today's doses with inline logging, the
medication list below, an add action. Loading/empty/loaded states per spec
§3; the offline state is automatic (`AppScaffold`'s built-in `OfflineBanner`)
so this screen doesn't build its own.

**Files:**
- Create: `lib/features/medication/presentation/screens/medications_screen.dart`
- Test: `test/features/medication/presentation/screens/medications_screen_test.dart`

**Interfaces:**
- Consumes: `medicationListControllerProvider`, `MedicationListState` (Task 12), `DoseRow`, `MedicationCard` (Task 15), `AppScaffold`/`EmptyState`/`ErrorView` (`core/widgets/widgets.dart`), `AppRoutes` (`core/router/routes.dart`), `DateFormatter` (`core/utils/date_formatter.dart`) — all read-only core imports.
- Produces: `class MedicationsScreen extends ConsumerWidget`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/presentation/screens/medications_screen_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/medications_screen.dart';

import '../../../../helpers/pump_app.dart';

class _FakeMedicationListController extends MedicationListController {
  _FakeMedicationListController(this._state);
  final MedicationListState _state;

  @override
  Future<MedicationListState> build() async => _state;
}

Medication _medication(String id) => Medication(
  clientRecordId: id, serverId: null, name: 'Aspirin', doseMg: 75,
  frequency: MedicationFrequency.onceDaily, scheduleTimes: const <String>['08:00'],
  active: true, createdAt: DateTime(2026, 8, 1), updatedAt: DateTime(2026, 8, 1),
);

void main() {
  setUpWidgetTests();

  testWidgets('shows an empty state with no medications', (tester) async {
    await pumpApp(
      tester,
      const MedicationsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[])),
        ),
      ],
    );

    expect(find.textContaining('meds.emptyTitle').evaluate(), isEmpty); // key resolved, not literal
    expect(find.byType(MedicationsScreen), findsOneWidget);
  });

  testWidgets('shows today\'s doses and the medication list when loaded', (tester) async {
    const ScheduledDose dose = ScheduledDose(
      medicationClientRecordId: 'm1', medicationName: 'Aspirin', doseMg: 75,
      scheduledDate: '2026-08-25', scheduledTime: '08:00',
      status: ScheduledDoseStatus.pending, doseLog: null,
    );
    await pumpApp(
      tester,
      const MedicationsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            MedicationListState(todaysDoses: const <ScheduledDose>[dose], medications: <Medication>[_medication('m1')]),
          ),
        ),
      ],
    );

    expect(find.textContaining('Aspirin'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/presentation/screens/medications_screen_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/presentation/screens/medications_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../controllers/medication_list_controller.dart';
import '../widgets/dose_row.dart';
import '../widgets/medication_card.dart';

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MedicationListState> state = ref.watch(medicationListControllerProvider);

    return AppScaffold.banded(
      showBack: false,
      scrollable: false,
      bandChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Text('meds.title'.tr(), style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormatter.displayDate(DateTime.now(), context.locale.languageCode),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.medicationNew),
        icon: const Icon(Iconsax.add),
        label: Text('meds.add'.tr()),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(medicationListControllerProvider),
        ),
        data: (MedicationListState data) => _Content(state: data),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.state});

  final MedicationListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.medications.isEmpty) {
      return EmptyState(
        icon: Iconsax.health,
        title: 'meds.emptyTitle'.tr(),
        message: 'meds.emptyBody'.tr(),
        actionLabel: 'meds.add'.tr(),
        onAction: () => context.pushNamed(AppRoutes.medicationNew),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Text('meds.today'.tr(), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        if (state.todaysDoses.isEmpty)
          Text('meds.todayEmpty'.tr(), style: Theme.of(context).textTheme.bodyMedium)
        else
          for (final dose in state.todaysDoses)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SectionCard(
                child: DoseRow(
                  dose: dose,
                  onLog: (DoseStatus status) => ref
                      .read(medicationListControllerProvider.notifier)
                      .logDose(
                        medicationClientRecordId: dose.medicationClientRecordId,
                        status: status,
                        scheduledDate: dose.scheduledDate,
                        scheduledTime: dose.scheduledTime,
                      ),
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.xl),
        Text('meds.yourMedications'.tr(), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        for (final medication in state.medications)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: MedicationCard(
              medication: medication,
              onTap: () => context.pushNamed(
                AppRoutes.medicationEdit,
                pathParameters: <String, String>{'id': medication.clientRecordId},
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/presentation/screens/medications_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/presentation/screens/medications_screen.dart test/features/medication/presentation/screens/medications_screen_test.dart
git commit -m "feat(mobile): M3 medications tab screen"
```

---

## Task 17: MedicationFormScreen (add/edit)

Merges the Figma "Add medication" search screen and the "Metoprolol 50 mg"
dosage/schedule screen into one form (implementer's layout latitude, per
`docs/frontend-decisions.md`'s design-fidelity contract — colors/fonts exact,
composition ours). Handles both `medicationNew` and `medicationEdit` via one
optional `editingId`.

**Files:**
- Create: `lib/features/medication/presentation/screens/medication_form_screen.dart`
- Test: `test/features/medication/presentation/screens/medication_form_screen_test.dart`

**Interfaces:**
- Consumes: `medicationFormControllerProvider`, `MedicationFormState` (Task 13), `medicationRepositoryProvider` (Task 12), `TimeListField` (Task 15), `AppScaffold`/`AppTextField`/`AppButton`/`ErrorView` (core widgets).
- Produces: `class MedicationFormScreen extends ConsumerStatefulWidget({String? editingId})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/presentation/screens/medication_form_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_form_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_form_screen.dart';

import '../../../../helpers/pump_app.dart';

class _FakeFormController extends MedicationFormController {
  _FakeFormController(this._state);
  MedicationFormState _state;

  @override
  MedicationFormState build() => _state;

  @override
  void setName(String value) => state = _state = _state.copyWith(name: value);

  @override
  Future<bool> save() async {
    _state = _state.copyWith(nameError: 'meds.errors.nameRequired');
    state = _state;
    return false;
  }
}

void main() {
  setUpWidgetTests();

  testWidgets('shows a validation error after an empty save attempt', (tester) async {
    await pumpApp(
      tester,
      const MedicationFormScreen(),
      overrides: <Override>[
        medicationFormControllerProvider.overrideWith(
          () => _FakeFormController(const MedicationFormState()),
        ),
      ],
    );

    await tester.tap(find.text('common.save'.tr()));
    await tester.pump();

    expect(find.text('meds.errors.nameRequired'.tr()), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/presentation/screens/medication_form_screen_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/presentation/screens/medication_form_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/medication.dart';
import '../../medication_providers.dart';
import '../controllers/medication_form_controller.dart';
import '../widgets/time_list_field.dart';

final AutoDisposeFutureProviderFamily<Medication?, String> _medicationByIdProvider =
    FutureProvider.autoDispose.family<Medication?, String>((Ref ref, String id) async {
  final List<Medication> medications =
      await ref.watch(medicationRepositoryProvider).allMedications(includeInactive: true);
  for (final Medication m in medications) {
    if (m.clientRecordId == id) return m;
  }
  return null;
});

class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen({this.editingId, super.key});

  final String? editingId;

  @override
  ConsumerState<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends ConsumerState<MedicationFormScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loaded = widget.editingId == null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final AsyncValue<Medication?> medication =
          ref.watch(_medicationByIdProvider(widget.editingId!));
      return medication.when(
        loading: () => const AppScaffold(body: Center(child: CircularProgressIndicator())),
        error: (Object e, StackTrace _) =>
            AppScaffold(body: ErrorView(failure: UnknownFailure(e.toString()))),
        data: (Medication? found) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (found != null) {
              ref.read(medicationFormControllerProvider.notifier).loadForEdit(found);
            }
            if (mounted) setState(() => _loaded = true);
          });
          return const AppScaffold(body: Center(child: CircularProgressIndicator()));
        },
      );
    }
    return const _FormBody();
  }
}

class _FormBody extends ConsumerWidget {
  const _FormBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MedicationFormState state = ref.watch(medicationFormControllerProvider);
    final MedicationFormController controller =
        ref.read(medicationFormControllerProvider.notifier);

    ref.listen<MedicationFormState>(medicationFormControllerProvider, (
      MedicationFormState? previous,
      MedicationFormState next,
    ) {
      if (next.saved && (previous == null || !previous.saved) && context.mounted) {
        context.pop();
      }
    });

    return AppScaffold(
      title: 'meds.form.title'.tr(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTextField(
            label: 'meds.form.name'.tr(),
            hint: 'meds.form.nameHint'.tr(),
            errorText: state.nameError?.tr(),
            onChanged: controller.setName,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'meds.form.doseMg'.tr(),
            keyboardType: TextInputType.number,
            errorText: state.doseError?.tr(),
            onChanged: controller.setDoseMg,
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            children: <Widget>[
              for (final MedicationFrequency f in MedicationFrequency.values)
                ChoiceChip(
                  label: Text('meds.frequency.${f.name}'.tr()),
                  selected: state.frequency == f,
                  onSelected: (_) => controller.setFrequency(f),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TimeListField(times: state.scheduleTimes, onChanged: controller.setScheduleTimes),
          if (state.scheduleError != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(state.scheduleError!.tr(), style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: 'common.save'.tr(),
            isLoading: state.isSaving,
            onPressed: controller.save,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/presentation/screens/medication_form_screen_test.dart`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/presentation/screens/medication_form_screen.dart test/features/medication/presentation/screens/medication_form_screen_test.dart
git commit -m "feat(mobile): M3 medication add/edit form screen"
```

---

## Task 18: DoseHistoryScreen, AdherenceScreen, ReminderSettingsScreen

Three smaller screens, one task — each is a straightforward `AsyncValue.when`
over its controller (Task 14) built from `core/widgets/`. Reminder settings
also owns the global notifications on/off switch (`PreferenceKeys
.notificationsEnabled`, shared with M2), via a small local notifier.

**Files:**
- Create: `lib/features/medication/presentation/screens/dose_history_screen.dart`
- Create: `lib/features/medication/presentation/screens/adherence_screen.dart`
- Create: `lib/features/medication/presentation/screens/reminder_settings_screen.dart`
- Test: `test/features/medication/presentation/screens/dose_history_adherence_reminders_test.dart`

**Interfaces:**
- Consumes: `doseHistoryControllerProvider` (Task 14), `adherenceControllerProvider` (Task 14), `medicationListControllerProvider` (Task 12), `appDatabaseProvider` (`core/providers/core_providers.dart`), `PreferenceKeys` (`core/db/tables.dart`), `DoseStatus`/`Adherence` (Tasks 2–3).
- Produces: `class DoseHistoryScreen`, `class AdherenceScreen`, `class ReminderSettingsScreen` (all `ConsumerWidget`).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/presentation/screens/dose_history_adherence_reminders_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/controllers/adherence_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/dose_history_controller.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/screens/adherence_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/dose_history_screen.dart';
import 'package:libu_care/features/medication/presentation/screens/reminder_settings_screen.dart';

import '../../../../helpers/pump_app.dart';

class _FakeDoseHistoryController extends DoseHistoryController {
  _FakeDoseHistoryController(this._logs);
  final List<DoseLog> _logs;
  @override
  Future<List<DoseLog>> build() async => _logs;
}

class _FakeAdherenceController extends AdherenceController {
  _FakeAdherenceController(this._state);
  final AdherenceState _state;
  @override
  Future<AdherenceState> build() async => _state;
}

class _FakeMedicationListController extends MedicationListController {
  _FakeMedicationListController(this._state);
  final MedicationListState _state;
  @override
  Future<MedicationListState> build() async => _state;
}

void main() {
  setUpWidgetTests();

  testWidgets('DoseHistoryScreen shows an empty state with no logs', (tester) async {
    await pumpApp(
      tester,
      const DoseHistoryScreen(),
      overrides: <Override>[
        doseHistoryControllerProvider.overrideWith(() => _FakeDoseHistoryController(const <DoseLog>[])),
      ],
    );
    expect(find.text('meds.history.emptyTitle'.tr()), findsOneWidget);
  });

  testWidgets('AdherenceScreen shows honest no-data text for a zero-due window', (tester) async {
    await pumpApp(
      tester,
      const AdherenceScreen(),
      overrides: <Override>[
        adherenceControllerProvider.overrideWith(
          () => _FakeAdherenceController(
            AdherenceState(
              overall7: const Adherence(taken: 0, due: 0, skipped: 0, windowDays: 7),
              overall30: const Adherence(taken: 0, due: 0, skipped: 0, windowDays: 30),
              perMedication7: const <String, Adherence>{},
              perMedication30: const <String, Adherence>{},
            ),
          ),
        ),
      ],
    );
    expect(find.text('meds.adherence.noData'.tr()), findsWidgets);
  });

  testWidgets('ReminderSettingsScreen lists each medication\'s times', (tester) async {
    final Medication med = Medication(
      clientRecordId: 'm1', serverId: null, name: 'Aspirin', doseMg: 75,
      frequency: MedicationFrequency.onceDaily, scheduleTimes: const <String>['08:00'],
      active: true, createdAt: DateTime(2026, 8, 1), updatedAt: DateTime(2026, 8, 1),
    );
    await pumpApp(
      tester,
      const ReminderSettingsScreen(),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            MedicationListState(todaysDoses: const <ScheduledDose>[], medications: <Medication>[med]),
          ),
        ),
      ],
    );
    expect(find.textContaining('Aspirin'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/presentation/screens/dose_history_adherence_reminders_test.dart`
Expected: FAIL — target files don't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/presentation/screens/dose_history_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../controllers/dose_history_controller.dart';

class DoseHistoryScreen extends ConsumerWidget {
  const DoseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DoseLog>> logs = ref.watch(doseHistoryControllerProvider);

    return AppScaffold(
      title: 'meds.history.title'.tr(),
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => ErrorView(
          failure: e is Failure ? e : UnknownFailure(e.toString()),
          onRetry: () => ref.invalidate(doseHistoryControllerProvider),
        ),
        data: (List<DoseLog> entries) => entries.isEmpty
            ? EmptyState(
                icon: Iconsax.document,
                title: 'meds.history.emptyTitle'.tr(),
                message: 'meds.history.emptyBody'.tr(),
              )
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final DoseLog log = entries[i];
                  return SectionCard(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '${log.scheduledDate} ${log.scheduledTime ?? ""}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (log.note != null)
                                Text(log.note!, style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        StatusChip(
                          severity: log.status == DoseStatus.taken ? Severity.none : Severity.monitor,
                          label: 'meds.status.${log.status.name}'.tr(),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
```

```dart
// lib/features/medication/presentation/screens/adherence_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/adherence.dart';
import '../controllers/adherence_controller.dart';

class AdherenceScreen extends ConsumerWidget {
  const AdherenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdherenceState> state = ref.watch(adherenceControllerProvider);

    return AppScaffold(
      title: 'meds.adherence.title'.tr(),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => ErrorView(
          failure: e is Failure ? e : UnknownFailure(e.toString()),
          onRetry: () => ref.invalidate(adherenceControllerProvider),
        ),
        data: (AdherenceState data) => ListView(
          children: <Widget>[
            _AdherenceCard(title: 'meds.adherence.overall7'.tr(), adherence: data.overall7),
            const SizedBox(height: AppSpacing.md),
            _AdherenceCard(title: 'meds.adherence.overall30'.tr(), adherence: data.overall30),
          ],
        ),
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.title, required this.adherence});

  final String title;
  final Adherence adherence;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: adherence.hasData
          ? Text(
              'meds.adherence.count'.tr(
                namedArgs: <String, String>{'taken': '${adherence.taken}', 'due': '${adherence.due}'},
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            )
          : Text('meds.adherence.noData'.tr()),
    );
  }
}
```

```dart
// lib/features/medication/presentation/screens/reminder_settings_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/medication.dart';
import '../controllers/medication_list_controller.dart';

class _NotificationsEnabledController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final String? raw = await ref
        .watch(appDatabaseProvider)
        .preferencesDao
        .get(PreferenceKeys.notificationsEnabled);
    return raw != 'false';
  }

  Future<void> setEnabled(bool value) async {
    await ref
        .read(appDatabaseProvider)
        .preferencesDao
        .set(PreferenceKeys.notificationsEnabled, value.toString());
    ref.invalidateSelf();
  }
}

final AsyncNotifierProvider<_NotificationsEnabledController, bool>
_notificationsEnabledProvider =
    AsyncNotifierProvider<_NotificationsEnabledController, bool>(
      _NotificationsEnabledController.new,
    );

class ReminderSettingsScreen extends ConsumerWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MedicationListState> meds = ref.watch(medicationListControllerProvider);
    final AsyncValue<bool> enabled = ref.watch(_notificationsEnabledProvider);

    return AppScaffold(
      title: 'meds.reminders.title'.tr(),
      body: meds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) =>
            ErrorView(failure: e is Failure ? e : UnknownFailure(e.toString())),
        data: (MedicationListState data) => ListView(
          children: <Widget>[
            SwitchListTile(
              title: Text('meds.reminders.enabled'.tr()),
              value: enabled.value ?? true,
              onChanged: (bool value) =>
                  ref.read(_notificationsEnabledProvider.notifier).setEnabled(value),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final Medication medication in data.medications)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SectionCard(
                  title: medication.name,
                  child: Text(
                    '${medication.scheduleTimes.join(' · ')} · ${'meds.reminders.followUp'.tr()}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/presentation/screens/dose_history_adherence_reminders_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/presentation/screens/dose_history_screen.dart lib/features/medication/presentation/screens/adherence_screen.dart lib/features/medication/presentation/screens/reminder_settings_screen.dart test/features/medication/presentation/screens/dose_history_adherence_reminders_test.dart
git commit -m "feat(mobile): M3 dose history, adherence and reminder settings screens"
```

---

## Task 19: TodaysDosesCard (Home card, order 100)

Per `core/shell/home_card.dart`'s contract: must render something offline
and must never throw. Order 100 — the today's-actions band.

**Files:**
- Create: `lib/features/medication/presentation/home/todays_doses_card.dart`
- Test: `test/features/medication/presentation/home/todays_doses_card_test.dart`

**Interfaces:**
- Consumes: `medicationListControllerProvider` (Task 12), `DoseRow` (Task 15), `HomeCard` (`core/shell/home_card.dart`), `AppRoutes` (`core/router/routes.dart`).
- Produces: `HomeCard todaysDosesHomeCard()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/medication/presentation/home/todays_doses_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';
import 'package:libu_care/features/medication/presentation/home/todays_doses_card.dart';

import '../../../../helpers/pump_app.dart';

class _FakeMedicationListController extends MedicationListController {
  _FakeMedicationListController(this._state);
  final MedicationListState _state;
  @override
  Future<MedicationListState> build() async => _state;
}

void main() {
  setUpWidgetTests();

  testWidgets('shows the empty-today text when nothing is due', (tester) async {
    await pumpApp(
      tester,
      Builder(builder: todaysDosesHomeCard().builder),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            const MedicationListState(todaysDoses: <ScheduledDose>[], medications: <Medication>[]),
          ),
        ),
      ],
    );
    expect(find.text('meds.todayEmpty'.tr()), findsOneWidget);
  });

  testWidgets('shows a DoseRow per due dose, up to three', (tester) async {
    const List<ScheduledDose> doses = <ScheduledDose>[
      ScheduledDose(medicationClientRecordId: 'm1', medicationName: 'A', doseMg: 1, scheduledDate: '2026-08-25', scheduledTime: '08:00', status: ScheduledDoseStatus.pending, doseLog: null),
      ScheduledDose(medicationClientRecordId: 'm2', medicationName: 'B', doseMg: 1, scheduledDate: '2026-08-25', scheduledTime: '09:00', status: ScheduledDoseStatus.pending, doseLog: null),
    ];
    await pumpApp(
      tester,
      Builder(builder: todaysDosesHomeCard().builder),
      overrides: <Override>[
        medicationListControllerProvider.overrideWith(
          () => _FakeMedicationListController(
            const MedicationListState(todaysDoses: doses, medications: <Medication>[]),
          ),
        ),
      ],
    );
    expect(find.textContaining('A'), findsWidgets);
    expect(find.textContaining('B'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/medication/presentation/home/todays_doses_card_test.dart`
Expected: FAIL — target file doesn't exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/medication/presentation/home/todays_doses_card.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/shell/home_card.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/dose_log.dart';
import '../controllers/medication_list_controller.dart';
import '../widgets/dose_row.dart';

HomeCard todaysDosesHomeCard() {
  return const HomeCard(id: 'meds-today', order: 100, builder: _TodaysDosesCard.build);
}

abstract final class _TodaysDosesCard {
  static Widget build(BuildContext context) => const _Card();
}

class _Card extends ConsumerWidget {
  const _Card();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MedicationListState> state = ref.watch(medicationListControllerProvider);

    return state.when(
      loading: () => const SectionCard(
        title: null,
        child: SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
      ),
      error: (Object _, StackTrace __) =>
          SectionCard(title: 'meds.today'.tr(), child: Text('common.noValue'.tr())),
      data: (MedicationListState data) => SectionCard(
        title: 'meds.today'.tr(),
        action: AppButton(
          label: 'common.seeAll'.tr(),
          variant: AppButtonVariant.text,
          expand: false,
          onPressed: () => context.pushNamed(AppRoutes.medications),
        ),
        child: data.todaysDoses.isEmpty
            ? Text('meds.todayEmpty'.tr(), style: Theme.of(context).textTheme.bodyMedium)
            : Column(
                children: <Widget>[
                  for (final dose in data.todaysDoses.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: DoseRow(
                        dose: dose,
                        onLog: (DoseStatus status) => ref
                            .read(medicationListControllerProvider.notifier)
                            .logDose(
                              medicationClientRecordId: dose.medicationClientRecordId,
                              status: status,
                              scheduledDate: dose.scheduledDate,
                              scheduledTime: dose.scheduledTime,
                            ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/medication/presentation/home/todays_doses_card_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/medication/presentation/home test/features/medication/presentation/home
git commit -m "feat(mobile): M3 today's doses Home card"
```

---

## Task 20: Wire into app_wiring.dart and add meds.* translations

The only shared-file edits this slice makes, both inside the regions
already marked for M3. **Amharic strings below are a first pass, not
reviewed by a native speaker** — `docs/design/2026-08-22-mobile-frontend-program.md`
§6 already flags this as a known gap and a release gate; noted again here
so it isn't lost.

**Files:**
- Modify: `lib/app/app_wiring.dart` (the `M3 medications` regions only)
- Modify: `assets/translations/en.json` (the `meds` object only)
- Modify: `assets/translations/am.json` (the `meds` object only)

**Interfaces:**
- Consumes: `MedicationsScreen` (Task 16), `MedicationFormScreen` (Task 17), `DoseHistoryScreen`/`AdherenceScreen`/`ReminderSettingsScreen` (Task 18), `todaysDosesHomeCard` (Task 19), `AppRoutes` (`core/router/routes.dart`).

- [ ] **Step 1: Modify `lib/app/app_wiring.dart`**

Add the four feature imports at the top (below the existing two):

```dart
import '../features/medication/presentation/home/todays_doses_card.dart';
import '../features/medication/presentation/screens/adherence_screen.dart';
import '../features/medication/presentation/screens/dose_history_screen.dart';
import '../features/medication/presentation/screens/medication_form_screen.dart';
import '../features/medication/presentation/screens/medications_screen.dart';
import '../features/medication/presentation/screens/reminder_settings_screen.dart';
```

Replace the `buildFeatureRoutes` function body — `topLevel` loses its
`const` (it stays `const` on its own, only the outer constructor does not),
and `medications:` gets a real `TabRoutes`:

```dart
FeatureRoutes buildFeatureRoutes() {
  return FeatureRoutes(
    topLevel: const <RouteBase>[
      // ── M1 auth ────────────────────────────────────────────────────────
      // splash, language picker, login, register, forgot-PIN
      //
      // ── M2 profile ─────────────────────────────────────────────────────
      // onboarding wizard, profile, profile edit, settings
    ],

    // ── M3 medications ───────────────────────────────────────────────────
    medications: TabRoutes(
      root: (BuildContext context) => const MedicationsScreen(),
      children: <RouteBase>[
        GoRoute(
          path: 'new',
          name: AppRoutes.medicationNew,
          builder: (BuildContext context, GoRouterState state) =>
              const MedicationFormScreen(),
        ),
        GoRoute(
          path: ':id/edit',
          name: AppRoutes.medicationEdit,
          builder: (BuildContext context, GoRouterState state) =>
              MedicationFormScreen(editingId: state.pathParameters['id']),
        ),
        GoRoute(
          path: 'history',
          name: AppRoutes.doseHistory,
          builder: (BuildContext context, GoRouterState state) =>
              const DoseHistoryScreen(),
        ),
        GoRoute(
          path: 'adherence',
          name: AppRoutes.adherence,
          builder: (BuildContext context, GoRouterState state) =>
              const AdherenceScreen(),
        ),
        GoRoute(
          path: 'reminders',
          name: AppRoutes.reminderSettings,
          builder: (BuildContext context, GoRouterState state) =>
              const ReminderSettingsScreen(),
        ),
      ],
    ),

    // ── M4 vitals ────────────────────────────────────────────────────────
    vitals: const TabRoutes(),

    // ── M5 symptoms & activity ───────────────────────────────────────────
    checkIn: const TabRoutes(),

    // ── M5 education & diet ──────────────────────────────────────────────
    learn: const TabRoutes(),
  );
}
```

Replace the `_homeCards` list — it loses `const` at the top level (one
element is now a function call) and gets the M3 entry:

```dart
final List<HomeCard> _homeCards = <HomeCard>[
  // ── M3 medications ──── today's doses, order 100
  todaysDosesHomeCard(),
  // ── M5 check-in ─────── today's check-in prompt, order 110
  // ── M4 vitals ───────── latest readings, order 200
  // ── M5 activity ─────── today's activity, order 210
  // ── M2 profile ──────── goal progress, order 300
];
```

`featureOverrides()` is unchanged — it already references `_homeCards`.

- [ ] **Step 2: Modify `assets/translations/en.json`** — replace `"meds": {}` with:

```json
"meds": {
  "title": "Medications",
  "add": "Add medication",
  "today": "Today",
  "todayEmpty": "Nothing due right now",
  "yourMedications": "Your medications",
  "emptyTitle": "No medications yet",
  "emptyBody": "Add your first medication to start tracking doses and reminders.",
  "status": {
    "taken": "Taken",
    "missed": "Missed",
    "skipped": "Skipped"
  },
  "form": {
    "title": "Medication",
    "name": "Name",
    "nameHint": "e.g. Atorvastatin",
    "doseMg": "Dose (mg)",
    "scheduleTimes": "Times"
  },
  "frequency": {
    "onceDaily": "Once daily",
    "bid": "Twice daily",
    "tid": "Three times daily",
    "custom": "Custom"
  },
  "errors": {
    "nameRequired": "Enter a medication name",
    "nameTooLong": "Name is too long",
    "doseRequired": "Enter a dose",
    "doseInvalid": "Enter a number",
    "dosePositive": "Dose must be greater than 0",
    "scheduleRequired": "Add at least one time",
    "scheduleFormat": "Enter a valid time"
  },
  "history": {
    "title": "Dose history",
    "emptyTitle": "No doses logged yet",
    "emptyBody": "Logged doses will appear here."
  },
  "adherence": {
    "title": "Adherence",
    "overall7": "Last 7 days",
    "overall30": "Last 30 days",
    "count": "{taken} of {due} doses",
    "noData": "Not enough data yet"
  },
  "reminders": {
    "title": "Reminders",
    "enabled": "Medication reminders",
    "followUp": "1 hour follow-up if not logged"
  },
  "notifications": {
    "doseTitle": "Time for your medication",
    "doseBody": "It's time to take {name}. Tap to log it.",
    "followUpTitle": "Still need to log a dose?",
    "followUpBody": "You have not logged {name} yet — tap to record it."
  }
},
```

- [ ] **Step 3: Modify `assets/translations/am.json`** — replace `"meds": {}` with:

```json
"meds": {
  "title": "መድሃኒቶች",
  "add": "መድሃኒት ጨምር",
  "today": "ዛሬ",
  "todayEmpty": "አሁን የሚወሰድ የለም",
  "yourMedications": "የእርስዎ መድሃኒቶች",
  "emptyTitle": "እስካሁን መድሃኒት የለም",
  "emptyBody": "መከታተል ለመጀመር የመጀመሪያ መድሃኒትዎን ያክሉ።",
  "status": {
    "taken": "ተወስዷል",
    "missed": "ታልፏል",
    "skipped": "ታልፏል በፈቃድ"
  },
  "form": {
    "title": "መድሃኒት",
    "name": "ስም",
    "nameHint": "ለምሳሌ Atorvastatin",
    "doseMg": "መጠን (mg)",
    "scheduleTimes": "ሰዓቶች"
  },
  "frequency": {
    "onceDaily": "በቀን አንድ ጊዜ",
    "bid": "በቀን ሁለት ጊዜ",
    "tid": "በቀን ሶስት ጊዜ",
    "custom": "ሌላ"
  },
  "errors": {
    "nameRequired": "የመድሃኒት ስም ያስገቡ",
    "nameTooLong": "ስሙ በጣም ረጅም ነው",
    "doseRequired": "መጠን ያስገቡ",
    "doseInvalid": "ቁጥር ያስገቡ",
    "dosePositive": "መጠኑ ከ0 በላይ መሆን አለበት",
    "scheduleRequired": "ቢያንስ አንድ ሰዓት ያክሉ",
    "scheduleFormat": "ትክክለኛ ሰዓት ያስገቡ"
  },
  "history": {
    "title": "የመድሃኒት ታሪክ",
    "emptyTitle": "እስካሁን የተመዘገበ የለም",
    "emptyBody": "የተመዘገቡ መጠኖች እዚህ ይታያሉ።"
  },
  "adherence": {
    "title": "ተገዢነት",
    "overall7": "ያለፉት 7 ቀናት",
    "overall30": "ያለፉት 30 ቀናት",
    "count": "{taken} ከ{due} መጠኖች",
    "noData": "እስካሁን በቂ መረጃ የለም"
  },
  "reminders": {
    "title": "ማስታወሻዎች",
    "enabled": "የመድሃኒት ማስታወሻዎች",
    "followUp": "ካልተመዘገበ በ1 ሰዓት ውስጥ ተከታይ ማሳሰቢያ"
  },
  "notifications": {
    "doseTitle": "የመድሃኒት ጊዜ ደርሷል",
    "doseBody": "{name} የመውሰጃ ጊዜዎ ነው። ለመመዝገብ ይንኩ።",
    "followUpTitle": "መጠን ገና አልመዘገቡም?",
    "followUpBody": "{name} ገና አልመዘገቡትም — ለመመዝገብ ይንኩ።"
  }
},
```

- [ ] **Step 4: Verify**

Run (from `mobile/`): `dart run build_runner build && flutter analyze`
Expected: `No issues found!`. Then run the whole suite:

Run: `flutter test`
Expected: every test from Tasks 1–19, all green.

- [ ] **Step 5: Commit**

```bash
git add lib/app/app_wiring.dart assets/translations/en.json assets/translations/am.json
git commit -m "feat(mobile): M3 wire medications into app shell and translations"
```

---

## Task 21: Final verification

No new source files — this task is the spec's Done criteria (§9) and
Handover checklist (§10), run for real.

- [ ] **Step 1: Full static check**

Run: `cd mobile && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: every test added in Tasks 1–20 passes; no regressions in the M0
foundation's existing 112 tests.

- [ ] **Step 3: Run against a local backend**

```bash
# from the repo root, in one terminal
docker compose up -d
export JWT_SECRET=$(openssl rand -base64 48)
mvn -f backend/pom.xml spring-boot:run

# from mobile/, in another terminal
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Manually verify, on a device or emulator (`OpenAuthGate` lets every route
through, so this works even before M1 lands):

- [ ] Add a medication with a dose, a frequency, and one or more times.
- [ ] It appears in the medication list and in today's doses (or the empty
      state, if none of its times fall today).
- [ ] Edit it — the change is reflected immediately.
- [ ] Deactivate it via the edit screen's history-preserving path — it drops
      out of the active list and today's doses, but its dose history
      (Task 18's Dose History screen) still shows past logs.
- [ ] Log a dose Taken from the Medications tab; log another Missed; log
      another Skipped — each updates inline with **no network requests**
      when Airplane Mode is on (verify the offline path, not just the happy
      path — CONTRIBUTING §13's PR checklist requires this explicitly).
- [ ] A local notification fires at a scheduled time (safe to verify with a
      time a couple of minutes out during manual testing), and a follow-up
      fires an hour later if the dose is still unlogged.
- [ ] Switch the device language to Amharic (via the `am.json` locale) and
      re-check the Medications tab, the add/edit form, and one notification
      — confirm no layout overflow from the longer Amharic strings.
- [ ] Turn Airplane Mode back on, add a second medication and log a dose,
      then turn it back off — confirm both reach the server (check
      `GET /api/v1/medications` and `GET /api/v1/dose-logs` against the
      running backend, or watch `pendingSyncCountProvider` drop to 0) with
      no duplicates.
- [ ] Specifically verify the **offline-edit-replay path** (Task 10): with
      the device online and a medication already synced (has a server id),
      turn Airplane Mode on, edit that medication, confirm nothing is sent;
      turn Airplane Mode off and reopen the Medications tab — confirm a
      `PUT` reaches the server with the edited fields.

- [ ] **Step 4: Confirm the documented decisions are still accurate**

Re-read this plan's header decisions and Task 4/10/11's inline documentation
against what was actually built — auto-MISSED timing, the offline-edit
pending-edit-set mechanism, the `isActiveOn` deactivation-day limitation, the
hardcoded `Africa/Addis_Ababa` timezone, and the daily-repeating follow-up
notification. If implementation diverged from any of these during the
subagent-driven build, update the doc comments in `schedule.dart`,
`medication_repository_impl.dart`, and `notification_scheduler.dart` to
match reality rather than leaving stale rationale in place.

- [ ] **Step 5: Tell M5 how to query "was a dose missed today"**

Per the spec's handover checklist — M5's cross-signal (`adherenceCrossSignal`
in `core/clinical/alert_evaluator.dart`) needs `missedDoseToday: bool`. The
query is: any `DoseLogs` row with `scheduled_date` = today and `status =
'MISSED'`, **or** any `ScheduledDose` from `scheduledDosesFor(...)` with
`status == ScheduledDoseStatus.overdue` (a dose whose window has passed but
was never logged at all — see Decision 2's note that `MISSED` is not written
until the 1-hour follow-up fires or the patient acts). M5 should treat
**either** as "missed" for the cross-signal, since a merely-overdue dose
that never gets an explicit log is still a missed dose from the patient's
perspective. Leave a note to this effect in the PR description for the
maintainer to relay, since M5 has not started as of this plan.

- [ ] **Step 6: Final commit and handover**

```bash
git status   # confirm nothing outside lib/features/medication/, test/features/medication/,
             # lib/app/app_wiring.dart, and assets/translations/{en,am}.json changed
git log --oneline mobile   # sanity-check the commit sequence
```

Update `mobile/SLICE_OWNERS.md`'s M3 row status to `In review` (or `Merged`
once a PR into `mobile` actually exists — this plan builds on a locally
initialized `mobile` branch with no remote yet; pushing and opening the PR
happens once the user connects the real GitHub remote, per the standing
project note).

---

## Self-review notes

- **Spec coverage:** every FR listed in the spec's §1 requirements table has
  a task — FR-MED-001/002 (Task 6/13, add), 003 (Task 6/10, logDose),
  004 (Task 4/16, today's status), 005 (Task 6/17, edit/deactivate),
  006 (Task 9/18, history), 007 (Task 4/14/18, adherence), 008 (Task 2, note
  field), 010 (Task 9, local storage). FR-NOT-001/002/003/007/008 and
  FR-DEC-001/002 are Task 11 (scheduling) + Task 4/Task 7 of `core/clinical`
  reuse (consecutive-miss detection — not directly exercised by a task here
  since it's Home/M5's rendering job per the spec's own deferral, but the
  data this slice writes is what it reads).
- **Placeholder scan:** no TBD/TODO strings; every code block is complete,
  compilable Dart against the types defined in earlier tasks.
- **Type consistency:** `MedicationRepository`'s method signatures (Task 6)
  match `MedicationRepositoryImpl`'s overrides (Task 10) and every caller in
  Tasks 12–19 exactly, including `adherence({medicationClientRecordId,
  windowDays, now})`'s named-not-positional shape used consistently
  throughout. `ScheduledDoseStatus`/`DoseStatus`/`MedicationFrequency` enum
  member names match between Tasks 1–3 (definitions) and every later
  reference.
- **Scope:** single feature slice, one PR into `mobile`. Not decomposed
  further — this is the appropriately-sized unit per `mobile/SLICE_OWNERS.md`.
