import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart' hide Medication, DoseLog;
import 'package:libu_care/features/medication/data/caregiver_notify_store.dart';
import 'package:libu_care/features/medication/data/medication_instructions_store.dart';
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/domain/schedule.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/notifications/notification_scheduler.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_form_controller.dart';

import '../../../../helpers/test_database.dart';

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

class _ThrowingAddRepository implements MedicationRepository {
  Medication? added;
  Medication? edited;

  @override
  Future<List<Medication>> activeMedications() async => <Medication>[_stored];
  @override
  Future<List<Medication>> allMedications({bool includeInactive = false}) async => <Medication>[_stored];
  @override
  Future<Medication> add({required String name, required double doseMg, required MedicationFrequency frequency, required List<String> scheduleTimes}) async {
    throw StateError('simulated local write failure');
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

/// Simulates a missing `SCHEDULE_EXACT_ALARM` permission: the OS-level
/// scheduling call throws, exactly as `flutter_local_notifications` does on
/// a real device when the permission isn't granted.
class _ThrowingScheduler implements NotificationScheduler {
  @override
  Future<void> init() async {}
  @override
  Future<void> zonedSchedule({required int id, required String title, required String body, required DateTime when, required String payload}) async {
    throw StateError('simulated missing SCHEDULE_EXACT_ALARM permission');
  }
  @override
  Future<List<PendingScheduledNotification>> pending() async => const <PendingScheduledNotification>[];
  @override
  Future<void> cancel(int id) async {}
}

ProviderContainer _container(MedicationRepository repo, AppDatabase db) {
  return ProviderContainer(
    overrides: <Override>[
      medicationRepositoryProvider.overrideWithValue(repo),
      medicationNotificationsProvider.overrideWithValue(
        MedicationNotifications(_NoopScheduler(), db.preferencesDao),
      ),
    ],
  );
}

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

  test('setFrequency never produces duplicate schedule times (I3)', () {
    final _FakeRepository repo = _FakeRepository();
    final AppDatabase db = testDatabase();
    addTearDown(db.close);

    // Every reachable transition, including from the untouched default empty
    // state — which is what used to pad with '08:00' repeated.
    for (final List<String> start in <List<String>>[
      const <String>[],
      const <String>['08:00'],
      const <String>['09:30'],
      const <String>['08:00', '20:00'],
    ]) {
      for (final MedicationFrequency frequency in MedicationFrequency.values) {
        final ProviderContainer container = _container(repo, db);
        addTearDown(container.dispose);
        final MedicationFormController controller = container.read(
          medicationFormControllerProvider.notifier,
        );

        if (start.isNotEmpty) controller.setScheduleTimes(start);
        controller.setFrequency(frequency);

        final List<String> times =
            container.read(medicationFormControllerProvider).scheduleTimes;
        expect(
          times.toSet(),
          hasLength(times.length),
          reason: 'start=$start frequency=${frequency.name} -> $times',
        );
        expect(times.length, greaterThanOrEqualTo(frequency.suggestedTimeCount));
      }
    }
  });

  test(
    'a BID schedule built by setFrequency counts two due doses a day, not one '
    '(I3)',
    () {
      final _FakeRepository repo = _FakeRepository();
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final ProviderContainer container = _container(repo, db);
      addTearDown(container.dispose);
      final MedicationFormController controller = container.read(
        medicationFormControllerProvider.notifier,
      );

      controller.setFrequency(MedicationFrequency.bid);
      final List<String> times =
          container.read(medicationFormControllerProvider).scheduleTimes;

      final DateTime created = DateTime(2026, 8, 25);
      final Medication medication = Medication(
        clientRecordId: 'm1',
        serverId: null,
        name: 'Aspirin',
        doseMg: 75,
        frequency: MedicationFrequency.bid,
        scheduleTimes: times,
        active: true,
        createdAt: created,
        updatedAt: created,
      );

      final Adherence adherence = computeAdherence(
        medications: <Medication>[medication],
        allLogs: const <DoseLog>[],
        windowStart: created,
        // End of the same day, so both slots have come due.
        now: DateTime(2026, 8, 25, 23, 59),
        windowDays: 1,
      );

      // With the old duplicate-'08:00' padding both slots matched the same
      // time, so a single day reported one due dose instead of two.
      expect(adherence.due, 2);
    },
  );

  test(
    'a second visit to the form starts clean instead of inheriting the first '
    'visit\'s medication (C4)',
    () async {
      final _FakeRepository repo = _FakeRepository();
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final ProviderContainer container = _container(repo, db);
      addTearDown(container.dispose);

      // Visit 1 — open the form on an existing medication and save it.
      // `container.listen` stands in for the screen being mounted: it is what
      // keeps the auto-disposed controller alive for the duration of a visit.
      final ProviderSubscription<MedicationFormState> firstVisit = container
          .listen(
            medicationFormControllerProvider,
            (MedicationFormState? _, MedicationFormState _) {},
          );
      final MedicationFormController first = container.read(
        medicationFormControllerProvider.notifier,
      );
      first.loadForEdit(_stored);
      expect(await first.save(), isTrue);
      expect(repo.edited?.clientRecordId, 'm1');

      // Navigating away pops the screen, which drops the last listener.
      firstVisit.close();
      // Riverpod tears an auto-disposed provider down on the next turn of the
      // event loop, not synchronously.
      await Future<void>.delayed(Duration.zero);

      // Visit 2 — the "Add" route. Before this fix the controller was a plain
      // (kept-alive) NotifierProvider, so this state was still medication A's
      // and `_editingClientRecordId` still pointed at it.
      final ProviderSubscription<MedicationFormState> secondVisit = container
          .listen(
            medicationFormControllerProvider,
            (MedicationFormState? _, MedicationFormState _) {},
          );
      addTearDown(secondVisit.close);

      final MedicationFormState fresh = container.read(
        medicationFormControllerProvider,
      );
      expect(fresh.name, isEmpty);
      expect(fresh.doseMg, isEmpty);
      expect(fresh.scheduleTimes, isEmpty);
      // `saved` sticking at true is what silently broke the screen's
      // close-on-save listener on every visit after the first.
      expect(fresh.saved, isFalse);

      // ...and Save now adds rather than editing medication A again.
      repo.edited = null;
      final MedicationFormController second = container.read(
        medicationFormControllerProvider.notifier,
      );
      second.setName('Bisoprolol');
      second.setDoseMg('5');
      second.setScheduleTimes(const <String>['08:00']);

      expect(await second.save(), isTrue);
      expect(repo.added?.name, 'Bisoprolol');
      expect(repo.edited, isNull);
    },
  );

  // Part B of the second Figma follow-up: "As needed" is Custom frequency
  // with an empty schedule, not a new persisted field — so `validate()` is
  // where the exception lives, not `validateScheduleTimes` itself (still
  // covered, unmodified, by validators_test.dart).
  group('validate() and the "As needed" (Custom + empty schedule) exception', () {
    test('Custom frequency with empty schedule times validates successfully', () {
      final _FakeRepository repo = _FakeRepository();
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final ProviderContainer container = _container(repo, db);
      addTearDown(container.dispose);
      final MedicationFormController controller = container.read(medicationFormControllerProvider.notifier);

      controller.setName('GTN spray');
      controller.setDoseMg('0.4');
      controller.setFrequency(MedicationFrequency.custom);
      controller.setScheduleTimes(const <String>[]);

      final bool ok = controller.validate();

      expect(ok, isTrue);
      expect(container.read(medicationFormControllerProvider).scheduleError, isNull);
    });

    test(
      'Once-daily with empty schedule times still fails validation exactly '
      'as before (regression: the exception is Custom-only)',
      () {
        final _FakeRepository repo = _FakeRepository();
        final AppDatabase db = testDatabase();
        addTearDown(db.close);
        final ProviderContainer container = _container(repo, db);
        addTearDown(container.dispose);
        final MedicationFormController controller = container.read(medicationFormControllerProvider.notifier);

        controller.setName('Atorvastatin');
        controller.setDoseMg('20');
        // onceDaily is the controller's default frequency; explicitly clear
        // the schedule anyway so this does not depend on that default.
        controller.setScheduleTimes(const <String>[]);

        final bool ok = controller.validate();

        expect(ok, isFalse);
        expect(
          container.read(medicationFormControllerProvider).scheduleError,
          'meds.errors.scheduleRequired',
        );
      },
    );

    test(
      'Custom with empty times, then adding a time back, still validates '
      '(regression: normal Custom-with-times behaviour is unaffected)',
      () {
        final _FakeRepository repo = _FakeRepository();
        final AppDatabase db = testDatabase();
        addTearDown(db.close);
        final ProviderContainer container = _container(repo, db);
        addTearDown(container.dispose);
        final MedicationFormController controller = container.read(medicationFormControllerProvider.notifier);

        controller.setName('Atorvastatin');
        controller.setDoseMg('20');
        controller.setFrequency(MedicationFrequency.custom);
        controller.setScheduleTimes(const <String>[]);
        controller.setScheduleTimes(const <String>['09:00']);

        final bool ok = controller.validate();

        expect(ok, isTrue);
        expect(container.read(medicationFormControllerProvider).scheduleTimes, <String>['09:00']);
      },
    );
  });

  test('save() resets isSaving to false (not stuck) after the repository throws', () async {
    final _ThrowingAddRepository repo = _ThrowingAddRepository();
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final ProviderContainer container = _container(repo, db);
    addTearDown(container.dispose);
    final MedicationFormController controller = container.read(medicationFormControllerProvider.notifier);

    controller.setName('Atorvastatin');
    controller.setDoseMg('20');
    controller.setScheduleTimes(const <String>['08:00']);

    await expectLater(controller.save(), throwsA(isA<StateError>()));

    expect(container.read(medicationFormControllerProvider).isSaving, isFalse);
  });

  test(
    'save() still succeeds — and reports reminderSchedulingFailed, not a '
    'thrown error — when the write succeeds but reminder scheduling throws',
    () async {
      final _FakeRepository repo = _FakeRepository();
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(repo),
          medicationNotificationsProvider.overrideWithValue(
            MedicationNotifications(_ThrowingScheduler(), db.preferencesDao),
          ),
        ],
      );
      addTearDown(container.dispose);
      final MedicationFormController controller = container.read(medicationFormControllerProvider.notifier);

      controller.setName('Atorvastatin');
      controller.setDoseMg('20');
      controller.setScheduleTimes(const <String>['08:00']);

      final bool result = await controller.save();

      expect(result, isTrue);
      expect(repo.added, isNotNull, reason: 'the medication must still have been written');
      final MedicationFormState state = container.read(medicationFormControllerProvider);
      expect(state.saved, isTrue);
      expect(state.isSaving, isFalse);
      expect(state.reminderSchedulingFailed, isTrue);
    },
  );

  test(
    'save() persists caregiverSettings/instructions using the newly-created '
    "medication's own clientRecordId — the fix that made these usable in "
    'add mode (third Figma follow-up), where no id exists until this call',
    () async {
      final _FakeRepository repo = _FakeRepository();
      final AppDatabase db = testDatabase();
      addTearDown(db.close);
      final CaregiverNotifyStore caregiverStore = CaregiverNotifyStore(db.preferencesDao);
      final MedicationInstructionsStore instructionsStore = MedicationInstructionsStore(
        db.preferencesDao,
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          medicationRepositoryProvider.overrideWithValue(repo),
          medicationNotificationsProvider.overrideWithValue(
            MedicationNotifications(_NoopScheduler(), db.preferencesDao),
          ),
          caregiverNotifyStoreProvider.overrideWithValue(caregiverStore),
          medicationInstructionsStoreProvider.overrideWithValue(instructionsStore),
        ],
      );
      addTearDown(container.dispose);
      final MedicationFormController controller = container.read(medicationFormControllerProvider.notifier);

      controller.setName('Atorvastatin');
      controller.setDoseMg('20');
      controller.setScheduleTimes(const <String>['08:00']);

      final bool result = await controller.save(
        caregiverSettings: const CaregiverNotifySettings(enabled: true, phone: '+251900000000'),
        instructions: MedicationInstructions.afterMeal,
      );

      expect(result, isTrue);
      final String newId = repo.added!.clientRecordId;

      final CaregiverNotifySettings savedCaregiver = await caregiverStore.get(newId);
      expect(savedCaregiver.enabled, isTrue);
      expect(savedCaregiver.phone, '+251900000000');

      final MedicationInstructions savedInstructions = await instructionsStore.get(newId);
      expect(savedInstructions, MedicationInstructions.afterMeal);
    },
  );
}
