import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
// `app_database.dart` re-exports `tables.dart`, whose Drift-generated row
// classes for the `Medications`/`DoseLogs` tables are named `Medication` and
// `DoseLog` by default — the exact same names as this feature's domain
// entities, imported below. Hiding them here is required to avoid an
// ambiguous-import compile error; this file only needs `AppDatabase`,
// `SyncEnqueuer` and `SyncEntityType` from this import.
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

/// A [PreferencesDao] that can pause the *next* call to [set] right before
/// it writes (i.e. strictly after the `get` that preceded it, and after the
/// mutation was computed from that read) — to deterministically stage
/// exactly the "stale read, delayed write" sequence review Finding 2
/// describes, and to observe whether a second logical operation is able to
/// run its own complete `get`-then-`set` concurrently.
///
/// A test arms a pause with [pauseNextSet] right after one full
/// `_markPendingEdit`/`_clearPendingEdit` sequence has completed (so it is
/// guaranteed to land on the *next* one, whichever of two concurrently-fired
/// sequences reaches it first), then waits a bounded real-time window —
/// never on a completer the *other* side must satisfy, which would deadlock
/// against a correctly-serialized implementation — and inspects [callLog]:
///
///  * **Unsynchronized** `_markPendingEdit`/`_clearPendingEdit`: nothing
///    stops the *other* concurrently-fired sequence from running its own
///    complete `get`-then-`set` during that window — `callLog` grows by a
///    full extra `get`/`set` pair. Releasing the paused `set` afterwards then
///    lets its stale-computed write land *last* and clobber that change.
///  * **Serialized** (the fix): every mutation is chained through a single
///    lock future, so nothing else can even start its own `get` until the
///    paused one's entire enclosing operation (including the pause)
///    resolves — `callLog` stays exactly as it was the instant the pause
///    landed, for as long as the pause is held.
class _RaceInducingPreferencesDao extends PreferencesDao {
  _RaceInducingPreferencesDao(super.db);

  final List<String> callLog = <String>[];

  /// Armed by [pauseNextSet]; consumed (and moved to [_activePause]) by the
  /// next [set] call so [releasePausedSet] can still reach the exact
  /// completer that call is awaiting, even after it has cleared this field.
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

/// A [PreferencesDao] whose [set] throws once, on its first call, then
/// behaves normally forever after — for proving a single transient
/// `preferences` failure doesn't permanently wedge
/// `_pendingEditsLock`'s chain (review Finding: "the chained-Future lock has
/// no error isolation").
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
    // A real dao over the real in-memory database ("never mock the
    // database"): the repository reads resolved server ids back out of the
    // queue, so the queue rows have to actually exist.
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

  /// Stands in for the sync engine having pushed [clientRecordId] and been
  /// handed [serverId] back: the queue row exists and carries the server id,
  /// exactly as `SyncService` leaves it.
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
      // Regression test for review finding C1: `Medication.serverId` was only
      // ever written by `setServerId`, which nothing in production called, so
      // the queue's resolved ids were never picked up and this branch was
      // dead code.
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
      expect(fakeDio.requests, isEmpty); // offline, and no server id yet

      // The sync engine drains the queue and the server answers with an id.
      // Nothing writes that id into `medications` — the replay has to find it.
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

  test('a permanently rejected edit (e.g. 409 conflict) is cleared, not retried forever', () async {
    final Medication med = await repository.add(
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.onceDaily,
      scheduleTimes: const <String>['08:00'],
    );

    // Track the edit as pending while offline, exactly like the existing
    // offline-edit test — this keeps the first replay attempt fully under
    // this test's control instead of racing edit()'s own unawaited replay.
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

    // A second replay pass must not re-send a permanently rejected edit —
    // the pending marker should have been cleared rather than left to
    // retry (and re-fail) forever.
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

    // Unlike a permanent rejection, a 500 must leave the edit pending so the
    // next replay pass retries it.
    await repository.replayPendingEdits();
    expect(fakeDio.requests, hasLength(2));
  });

  test(
    'a transient preferences failure does not permanently wedge the '
    'pending-edits lock for later, unrelated edits',
    () async {
      // Regression test for the error-isolation gap in `_pendingEditsLock`:
      // `_markPendingEdit`/`_clearPendingEdit` chain onto that shared future
      // via `.then()`. Without isolating each call's own error from the
      // chain, a single failed `preferences.set` would leave the shared
      // future permanently errored, and `Future.then` skips its callback
      // entirely once its source has errored — so every later mark/clear,
      // for any medication, would silently stop running its body for the
      // rest of this repository instance's lifetime.
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

      // A's mark hits the flaky `set`'s one-time throw. The immediate
      // caller — this `edit()` call — must still see that failure.
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

      // A second, unrelated edit must still succeed — proving the shared
      // lock recovered rather than staying permanently poisoned by A's
      // earlier failure.
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
      // Direct, deterministic reproduction of the race described in review
      // Finding 2: `_markPendingEdit`/`_clearPendingEdit` each do an
      // unsynchronized get-decode-mutate-set round trip, so if two of these
      // sequences overlap, the one that writes *last* wins outright — even
      // if it was computed from a read that predates the other's write,
      // silently discarding that other mutation. See
      // `_RaceInducingPreferencesDao`'s doc comment for how pausing right
      // before a write, plus a bounded wait, distinguishes the two cases
      // without ever deadlocking (a plain concurrent `Future.wait` against
      // real Drift/fake-HTTP timing turned out not to reproduce the race
      // reliably on its own, even against a deliberately reverted,
      // unsynchronized implementation).
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

      // Medication A already has a server id and is online, so editing it
      // triggers an immediate, successful replay that clears its own
      // pending marker. Medication B has no server id, so editing it only
      // marks it pending — it never itself makes a network call, isolating
      // the effect under test to the mark/clear interaction rather than a
      // second network race.
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

      // A's own mark (`get`+`set`) completes uninterrupted here — it
      // establishes the {A} baseline both the clear and B's mark will read
      // from. `edit()` awaits its own mark before returning, so this line
      // blocks until exactly that; A's replay (and its eventual clear) is
      // then running unawaited in the background, not yet at its own `get`.
      await raceRepository.edit(
        medAWithServerId.copyWith(name: 'Medication A updated'),
      );
      expect(raceDao.callLog, <String>['get', 'set']); // A's mark, only

      // Arm the pause for whichever `set` call happens next — either A's
      // still-in-flight clear, or B's mark below, whichever gets there
      // first (it will already have done its own `get` and computed its
      // write by the time it's paused here) — then fire B's edit
      // concurrently with A's replay.
      raceDao.pauseNextSet();
      final Future<Medication> editBFuture = raceRepository.edit(
        medB.copyWith(name: 'Medication B updated'),
      );

      // Bounded window, not a wait on the other side's completion (which,
      // under a correct/serialized implementation, never happens while this
      // pause is held — see the DAO's doc comment). Comfortably longer than
      // the few in-memory/fake-HTTP hops either side needs.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Release the paused write — this is where, on the unsynchronized
      // implementation, the paused call's stale-computed write lands *last*
      // and clobbers whatever the other, already-finished sequence wrote
      // during the window above.
      raceDao.releasePausedSet();
      await editBFuture;
      // Let whichever chain owned the just-released `set` (clear's
      // `_tryReplaySingle`, if that's the one that was paused) finish
      // unwinding.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(fakeDio.requests, hasLength(1)); // only A ever had a server id
      expect(fakeDio.requests.single.method, 'PUT');

      // A replayed successfully and should be cleared; B has no server id
      // yet, so it must still be pending — never silently dropped by the
      // race between its own mark and A's clear.
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
      now: DateTime.now(), // any recent time; just verifies wiring, not the math (covered by Task 4)
    );

    expect(doses, isNotEmpty);
  });
}
