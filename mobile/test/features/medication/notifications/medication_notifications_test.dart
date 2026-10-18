import 'package:flutter_test/flutter_test.dart';

import 'package:libu_care/core/db/app_database.dart' hide Medication;
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
        .map(
          (_Scheduled s) =>
              PendingScheduledNotification(id: s.id, payload: s.payload),
        )
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
    expect(scheduler.scheduled, hasLength(4));
  });

  test('the follow-up fires one hour after the main notification', () async {
    await notifications.scheduleFor(
      _medication(times: const <String>['08:00']),
    );
    final _Scheduled main = scheduler.scheduled.firstWhere(
      (_Scheduled s) => s.payload.endsWith('|main'),
    );
    final _Scheduled followUp = scheduler.scheduled.firstWhere(
      (_Scheduled s) => s.payload.endsWith('|follow'),
    );
    expect(followUp.when.difference(main.when), const Duration(hours: 1));
  });

  test('rescheduling replaces rather than duplicating', () async {
    await notifications.scheduleFor(_medication());
    final Set<int> firstIds = scheduler.scheduled
        .map((_Scheduled s) => s.id)
        .toSet();

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

  group('follow-up after a dose is logged', () {
    final DateTime morning = DateTime(2026, 8, 25, 7);

    test('is due an hour after the dose while nothing is logged', () async {
      expect(
        await notifications.nextFollowUpFor('m1', '08:00', now: morning),
        DateTime(2026, 8, 25, 9),
      );
    });

    test('skips today once the dose is logged, then carries on', () async {
      await notifications.doseLogged(
        _medication(),
        time: '08:00',
        scheduledDate: '2026-08-25',
        now: morning,
      );

      expect(
        await notifications.nextFollowUpFor('m1', '08:00', now: morning),
        DateTime(2026, 8, 26, 9),
      );
      expect(
        await notifications.nextFollowUpFor('m1', '20:00', now: morning),
        DateTime(2026, 8, 25, 21),
        reason: 'the evening dose was not logged',
      );
    });

    test('logging an older day does not move the follow-up for today', () async {
      await notifications.doseLogged(
        _medication(),
        time: '08:00',
        scheduledDate: '2026-08-24',
        now: morning,
      );

      expect(
        await notifications.nextFollowUpFor('m1', '08:00', now: morning),
        DateTime(2026, 8, 25, 9),
      );
    });
  });
}
