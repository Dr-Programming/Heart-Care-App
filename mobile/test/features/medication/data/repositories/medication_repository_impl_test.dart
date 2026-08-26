import 'package:flutter_test/flutter_test.dart';
// `app_database.dart` re-exports `tables.dart`, whose Drift-generated row
// classes for the `Medications`/`DoseLogs` tables are named `Medication` and
// `DoseLog` by default — the exact same names as this feature's domain
// entities, imported below. Hiding them here is required to avoid an
// ambiguous-import compile error; this file only needs `AppDatabase`,
// `SyncEnqueuer` and `SyncEntityType` from this import.
import 'package:libu_care/core/db/app_database.dart' hide Medication, DoseLog;
import 'package:libu_care/core/sync/sync_queue_dao.dart';
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
