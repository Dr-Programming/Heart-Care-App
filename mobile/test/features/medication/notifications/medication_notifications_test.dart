import 'package:flutter_test/flutter_test.dart';
// `app_database.dart` re-exports `tables.dart`, whose Drift-generated row
// class for the `Medications` table defaults to the name `Medication` —
// identical to this feature's domain entity, imported below. Hiding it
// avoids an ambiguous-import error (see `medication_repository_impl_test.dart`
// for the same pattern).
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
