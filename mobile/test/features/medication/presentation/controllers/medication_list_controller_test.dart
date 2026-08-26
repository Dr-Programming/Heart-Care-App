import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart' hide Medication, DoseLog;
import 'package:libu_care/features/medication/domain/entities/adherence.dart';
import 'package:libu_care/features/medication/domain/entities/dose_log.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';
import 'package:libu_care/features/medication/domain/entities/scheduled_dose.dart';
import 'package:libu_care/features/medication/domain/repositories/medication_repository.dart';
import 'package:libu_care/features/medication/medication_providers.dart';
import 'package:libu_care/features/medication/notifications/medication_notifications.dart';
import 'package:libu_care/features/medication/notifications/notification_scheduler.dart';
import 'package:libu_care/features/medication/presentation/controllers/medication_list_controller.dart';

import '../../../../helpers/test_database.dart';

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
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        medicationRepositoryProvider.overrideWithValue(repo),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        medicationNotificationsProvider.overrideWithValue(
          MedicationNotifications(scheduler, db.preferencesDao),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(medicationListControllerProvider.future);

    await container.read(medicationListControllerProvider.notifier).deactivate('m1');

    expect(repo.deactivateCalls, 1);
  });
}
