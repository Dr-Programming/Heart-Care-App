import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:libu_care/core/db/app_database.dart' hide Medication, DoseLog;
import 'package:libu_care/core/db/daos/preferences_dao.dart';
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

class _RaceInducingPreferencesDao extends PreferencesDao {
  _RaceInducingPreferencesDao(super.db);

  final List<String> callLog = <String>[];

  Completer<void>? _pauseNextSet;
  Completer<void>? _activePause;

  void pauseNextSet() => _pauseNextSet = Completer<void>();

  void releasePausedSet() {
    _activePause?.complete();
    _activePause = null;
  }

  @override
  Future<String?> get(String key) async {
    callLog.add('get');
    return super.get(key);
  }

  @override
  Future<void> set(String key, String value) async {
    callLog.add('set');
    final Completer<void>? pause = _pauseNextSet;
    if (pause != null) {
      _pauseNextSet = null;
      _activePause = pause;
      await pause.future;
    }
    return super.set(key, value);
  }
}

class _FlakyPreferencesDao extends PreferencesDao {
  _FlakyPreferencesDao(super.db);

  bool _hasThrownOnce = false;

  @override
  Future<void> set(String key, String value) async {
    if (!_hasThrownOnce) {
      _hasThrownOnce = true;
      throw StateError('transient preferences failure');
    }
    return super.set(key, value);
  }
}

void main() {
  late AppDatabase db;
  late MedicationLocalDataSource local;
  late FakeDio fakeDio;
  late MedicationRemoteDataSource remote;
  late _FakeSyncEnqueuer enqueuer;
  late SyncQueueDao syncQueueDao;
  late bool online;
  late MedicationRepositoryImpl repository;

  setUp(() {
    db = testDatabase();
    local = MedicationLocalDataSource(db);
    fakeDio = FakeDio();
    remote = MedicationRemoteDataSource(fakeDio.dio);
    enqueuer = _FakeSyncEnqueuer();

    syncQueueDao = SyncQueueDao(db);
    online = false;
    repository = MedicationRepositoryImpl(
      local: local,
      remote: remote,
      syncEnqueuer: enqueuer,
      syncQueueDao: syncQueueDao,
      preferences: db.preferencesDao,
      isOnline: () async => online,
    );
  });

  tearDown(() => db.close());

  Future<void> resolveInQueue(String clientRecordId, String serverId) async {
    await syncQueueDao.enqueue(
      clientRecordId: clientRecordId,
      entityType: SyncEntityType.medication,
      payload: const <String, dynamic>{},
      recordedAt: DateTime.now().toUtc(),
    );
    final SyncQueueEntry entry = (await syncQueueDao.pending()).firstWhere(
      (SyncQueueEntry e) => e.clientRecordId == clientRecordId,
    );
    await syncQueueDao.markResult(
      entry.id,
      status: LocalSyncStatus.synced,
      serverId: serverId,
    );
  }

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

  test(
    'logging the same dose slot twice keeps one row, with the second status '
    'winning (I8)',
    () async {
      final Medication med = await repository.add(
        name: 'Aspirin',
        doseMg: 75,
        frequency: MedicationFrequency.onceDaily,
        scheduleTimes: const <String>['08:00'],
      );

      final DoseLog first = await repository.logDose(
        medicationClientRecordId: med.clientRecordId,
        status: DoseStatus.taken,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
      );
      final DoseLog second = await repository.logDose(
        medicationClientRecordId: med.clientRecordId,
        status: DoseStatus.missed,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
        note: 'ran out',
      );

      final List<DoseLog> stored = await local.doseLogsForDate('2026-08-25');
      expect(stored, hasLength(1));
      expect(stored.single.status, DoseStatus.missed);
      expect(stored.single.note, 'ran out');

      expect(second.clientRecordId, first.clientRecordId);
    },
  );

  test('a different slot of the same medication is still its own row (I8)', () async {
    final Medication med = await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.bid,
      scheduleTimes: const <String>['08:00', '20:00'],
    );

    await repository.logDose(
      medicationClientRecordId: med.clientRecordId,
      status: DoseStatus.taken,
      scheduledDate: '2026-08-25',
      scheduledTime: '08:00',
    );
    await repository.logDose(
      medicationClientRecordId: med.clientRecordId,
      status: DoseStatus.taken,
      scheduledDate: '2026-08-25',
      scheduledTime: '20:00',
    );

    await repository.logDose(
      medicationClientRecordId: med.clientRecordId,
      status: DoseStatus.taken,
      scheduledDate: '2026-08-26',
      scheduledTime: '08:00',
    );

    expect(await local.doseLogsForDate('2026-08-25'), hasLength(2));
    expect(await local.doseLogsForDate('2026-08-26'), hasLength(1));
  });

  test('an untimed dose does not collide with a timed one (I8)', () async {
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
    await repository.logDose(
      medicationClientRecordId: med.clientRecordId,
      status: DoseStatus.taken,
      scheduledDate: '2026-08-25',
    );

    expect(await local.doseLogsForDate('2026-08-25'), hasLength(2));
  });

  test('doseHistory orders same-day rows by their slot, latest first (I5)', () async {
    final Medication med = await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.tid,
      scheduleTimes: const <String>['08:00', '14:00', '20:00'],
    );

    for (final String time in <String>['14:00', '08:00', '20:00']) {
      await repository.logDose(
        medicationClientRecordId: med.clientRecordId,
        status: DoseStatus.taken,
        scheduledDate: '2026-08-25',
        scheduledTime: time,
      );
    }

    final List<DoseLog> history = await repository.doseHistory();

    expect(
      history.map((DoseLog l) => l.scheduledTime).toList(),
      <String>['20:00', '14:00', '08:00'],
    );
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

  test(
    'logDose harvests a server id the sync engine resolved and sends '
    'medicationId — without anyone calling setServerId by hand',
    () async {

      final Medication med = await repository.add(
        name: 'Aspirin',
        doseMg: 75,
        frequency: MedicationFrequency.onceDaily,
        scheduleTimes: const <String>['08:00'],
      );
      await resolveInQueue(med.clientRecordId, 'srv-9');

      await repository.logDose(
        medicationClientRecordId: med.clientRecordId,
        status: DoseStatus.taken,
        scheduledDate: '2026-08-25',
        scheduledTime: '08:00',
      );

      expect((await local.findMedication(med.clientRecordId))!.serverId, 'srv-9');
      final _RecordedEnqueue doseCall = enqueuer.calls.firstWhere(
        (_RecordedEnqueue c) => c.entityType == SyncEntityType.doseLog,
      );
      expect(doseCall.payload['medicationId'], 'srv-9');
      expect(doseCall.payload.containsKey('medicationClientRecordId'), isFalse);
    },
  );

  test(
    'replayPendingEdits harvests the resolved server id and PUTs the edit',
    () async {
      final Medication med = await repository.add(
        name: 'Aspirin',
        doseMg: 75,
        frequency: MedicationFrequency.onceDaily,
        scheduleTimes: const <String>['08:00'],
      );

      await repository.edit(med.copyWith(name: 'Aspirin 100mg'));
      expect(fakeDio.requests, isEmpty);

      await resolveInQueue(med.clientRecordId, 'srv-1');
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
        }),
      );

      await repository.replayPendingEdits();

      expect(fakeDio.requests.single.method, 'PUT');
      expect(fakeDio.requests.single.json['name'], 'Aspirin 100mg');
    },
  );

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
    expect(fakeDio.requests, isEmpty);

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

  test('a permanently rejected edit (e.g. 409 conflict) is cleared, not retried forever', () async {
    final Medication med = await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );

    await repository.edit(med.copyWith(name: 'Aspirin 100mg'));
    expect(fakeDio.requests, isEmpty);

    await local.setServerId(med.clientRecordId, 'srv-1');
    online = true;
    fakeDio.stub(
      '/api/v1/medications/srv-1',
      FakeResponse.error(409, 'Medication was modified elsewhere'),
    );

    await repository.replayPendingEdits();
    expect(fakeDio.requests, hasLength(1));
    expect(fakeDio.requests.single.method, 'PUT');

    await repository.replayPendingEdits();
    expect(fakeDio.requests, hasLength(1));
  });

  test('a transient server failure (500) stays pending and is retried', () async {
    final Medication med = await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );

    await repository.edit(med.copyWith(name: 'Aspirin 100mg'));
    await local.setServerId(med.clientRecordId, 'srv-1');
    online = true;
    fakeDio.stub(
      '/api/v1/medications/srv-1',
      FakeResponse.error(500, 'Internal server error'),
    );

    await repository.replayPendingEdits();
    expect(fakeDio.requests, hasLength(1));

    await repository.replayPendingEdits();
    expect(fakeDio.requests, hasLength(2));
  });

  test(
    'a transient preferences failure does not permanently wedge the '
    'pending-edits lock for later, unrelated edits',
    () async {

      final _FlakyPreferencesDao flakyPreferences = _FlakyPreferencesDao(db);
      final MedicationRepositoryImpl flakyRepository = MedicationRepositoryImpl(
        local: local,
        remote: remote,
        syncEnqueuer: enqueuer,
        syncQueueDao: syncQueueDao,
        preferences: flakyPreferences,
        isOnline: () async => online,
      );

      final Medication medA = await flakyRepository.add(
        name: 'Medication A',
        doseMg: 10,
        frequency: MedicationFrequency.onceDaily,
        scheduleTimes: const <String>['08:00'],
      );

      await expectLater(
        () => flakyRepository.edit(medA.copyWith(name: 'Medication A updated')),
        throwsStateError,
      );

      final Medication medB = await flakyRepository.add(
        name: 'Medication B',
        doseMg: 20,
        frequency: MedicationFrequency.onceDaily,
        scheduleTimes: const <String>['09:00'],
      );

      await flakyRepository.edit(medB.copyWith(name: 'Medication B updated'));

      final String? raw = await db.preferencesDao.get(
        'm3_pending_medication_edits',
      );
      final Set<String> remaining = raw == null
          ? <String>{}
          : (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
      expect(remaining, <String>{medB.clientRecordId});
    },
  );

  test(
    'a second edit for a different medication does not lose its pending marker '
    'to a concurrent stale-read write',
    () async {

      final _RaceInducingPreferencesDao raceDao = _RaceInducingPreferencesDao(
        db,
      );
      final MedicationRepositoryImpl raceRepository = MedicationRepositoryImpl(
        local: local,
        remote: remote,
        syncEnqueuer: enqueuer,
        syncQueueDao: syncQueueDao,
        preferences: raceDao,
        isOnline: () async => online,
      );

      final Medication medA = await raceRepository.add(
        name: 'Medication A',
        doseMg: 10,
        frequency: MedicationFrequency.onceDaily,
        scheduleTimes: const <String>['08:00'],
      );
      await local.setServerId(medA.clientRecordId, 'srv-a');
      fakeDio.stub(
        '/api/v1/medications/srv-a',
        FakeResponse.ok(<String, dynamic>{
          'id': 'srv-a',
          'name': 'Medication A updated',
          'doseMg': 10.0,
          'frequency': 'ONCE_DAILY',
          'scheduleTimes': <String>['08:00'],
          'active': true,
          'clientRecordId': medA.clientRecordId,
        }),
      );
      final Medication medAWithServerId = (await local.findMedication(
        medA.clientRecordId,
      ))!;
      final Medication medB = await raceRepository.add(
        name: 'Medication B',
        doseMg: 20,
        frequency: MedicationFrequency.onceDaily,
        scheduleTimes: const <String>['09:00'],
      );
      online = true;

      await raceRepository.edit(
        medAWithServerId.copyWith(name: 'Medication A updated'),
      );
      expect(raceDao.callLog, <String>['get', 'set']);

      raceDao.pauseNextSet();
      final Future<Medication> editBFuture = raceRepository.edit(
        medB.copyWith(name: 'Medication B updated'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      raceDao.releasePausedSet();
      await editBFuture;

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeDio.requests, hasLength(1));
      expect(fakeDio.requests.single.method, 'PUT');

      final String? raw = await db.preferencesDao.get(
        'm3_pending_medication_edits',
      );
      final Set<String> remaining = raw == null
          ? <String>{}
          : (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
      expect(remaining, <String>{medB.clientRecordId});
    },
  );

  test('todaysDoses derives from active medications and today\'s logs', () async {
    await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );

    final List<dynamic> doses = await repository.todaysDoses(
      now: DateTime.now(),
    );

    expect(doses, isNotEmpty);
  });
}
