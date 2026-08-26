import 'package:flutter_test/flutter_test.dart';
// `app_database.dart` re-exports `tables.dart`, whose Drift-generated row
// class for the `Medications` table defaults to the name `Medication` —
// identical to this feature's domain entity. Hiding it avoids an
// ambiguous-import error.
import 'package:libu_care/core/db/app_database.dart' hide Medication;
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/notifications/reminder_bootstrap.dart';

import '../../../helpers/test_database.dart';
import '../helpers/fake_medication_repository.dart';

void main() {
  late AppDatabase db;
  late RecordingScheduler scheduler;
  late FakeMedicationRepository repository;
  late MedicationReminderBootstrap bootstrap;

  setUp(() {
    db = testDatabase();
    scheduler = RecordingScheduler();
    repository = FakeMedicationRepository(
      medications: <Medication>[
        fakeMedication(clientRecordId: 'm1', name: 'Aspirin'),
        fakeMedication(
          clientRecordId: 'm2',
          name: 'Atorvastatin',
          scheduleTimes: const <String>['20:00'],
        ),
        fakeMedication(clientRecordId: 'm3', name: 'Stopped', active: false),
      ],
    );
    bootstrap = MedicationReminderBootstrap(
      scheduler: scheduler,
      notifications: MedicationNotifications(scheduler, db.preferencesDao),
      repository: repository,
    );
  });

  tearDown(() => db.close());

  test('start() initialises the plugin exactly once', () async {
    await bootstrap.start();
    expect(scheduler.initCalls, 1);
  });

  test('start() reschedules every active medication (Decision 4)', () async {
    await bootstrap.start();

    // Two active medications, one scheduled time each, main + follow-up.
    expect(scheduler.scheduledPayloads, hasLength(4));
    expect(
      scheduler.scheduledPayloads.map((String p) => p.split('|').first).toSet(),
      <String>{'m1', 'm2'},
    );
  });

  test('start() does not schedule for a deactivated medication', () async {
    await bootstrap.start();
    expect(
      scheduler.scheduledPayloads.any((String p) => p.startsWith('m3|')),
      isFalse,
    );
  });

  test('start() schedules nothing when reminders are switched off', () async {
    await db.preferencesDao.set(PreferenceKeys.notificationsEnabled, 'false');

    await bootstrap.start();

    // The plugin still has to be initialised — the switch can be turned back
    // on without restarting the app — but nothing is armed.
    expect(scheduler.initCalls, 1);
    expect(scheduler.scheduledPayloads, isEmpty);
  });

  test('rescheduleAll() re-arms without re-initialising the plugin', () async {
    await bootstrap.rescheduleAll();

    expect(scheduler.initCalls, 0);
    expect(scheduler.scheduledPayloads, hasLength(4));
  });

  test('cancelAll() clears every pending reminder (I1)', () async {
    await bootstrap.rescheduleAll();
    expect(scheduler.pendingPayloads, isNotEmpty);

    await bootstrap.cancelAll();

    expect(scheduler.pendingPayloads, isEmpty);
  });

  test('cancelAll() sweeps a deactivated medication\'s stale reminders', () async {
    // Armed while it was still active, then deactivated — `activeMedications`
    // would no longer report it, which is why `cancelAll` goes over
    // `allMedications(includeInactive: true)`.
    await scheduler.zonedSchedule(
      id: 99,
      title: 't',
      body: 'b',
      when: DateTime(2026, 8, 26, 8),
      payload: 'm3|08:00|main',
    );

    await bootstrap.cancelAll();

    expect(scheduler.pendingPayloads, isEmpty);
  });
}
