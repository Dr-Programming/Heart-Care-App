import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/features/symptoms/data/datasources/symptom_local_datasource.dart';
import 'package:libu_care/features/symptoms/data/datasources/symptom_remote_datasource.dart';
import 'package:libu_care/features/symptoms/data/models/symptom_model.dart';
import 'package:libu_care/features/symptoms/data/repositories/symptom_repository_impl.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_answer.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_history_entry.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_database.dart';

class _MockSyncEnqueuer extends Mock implements SyncEnqueuer {}

class _MockSymptomRemoteDatasource extends Mock
    implements SymptomRemoteDatasource {}

class _MockSyncQueueDao extends Mock implements SyncQueueDao {}

SymptomCheckIn _checkIn({
  String clientRecordId = 'a',
  ChestPain chestPain = ChestPain.none,
  DateTime? measuredAt,
}) {
  return SymptomCheckIn(
    clientRecordId: clientRecordId,
    chestPain: chestPain,
    shortnessOfBreath: ShortnessOfBreath.none,
    heartRate: 72,
    bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
    swelling: false,
    energyLevel: 7,
    measuredAt: measuredAt ?? DateTime.utc(2026, 8, 30),
  );
}

void main() {
  late AppDatabase db;
  late _MockSyncEnqueuer sync;
  late _MockSymptomRemoteDatasource remote;
  late _MockSyncQueueDao syncQueue;
  late SymptomRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(SyncEntityType.symptom);
    registerFallbackValue(DateTime(2000, 1, 1));
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(<String>[]);
    registerFallbackValue(
      SymptomModel.fromEntity(_checkIn(clientRecordId: 'fallback')),
    );
  });

  setUp(() {
    db = testDatabase();
    sync = _MockSyncEnqueuer();
    remote = _MockSymptomRemoteDatasource();
    syncQueue = _MockSyncQueueDao();
    when(
      () => sync.enqueue(
        clientRecordId: any(named: 'clientRecordId'),
        entityType: any(named: 'entityType'),
        payload: any(named: 'payload'),
        recordedAt: any(named: 'recordedAt'),
      ),
    ).thenAnswer((_) async {});
    repository = SymptomRepositoryImpl(
      local: SymptomLocalDatasource(db),
      sync: sync,
      remote: remote,
      syncQueue: syncQueue,
    );
  });

  tearDown(() => db.close());

  group('log', () {
    test('writes to Drift with the locally computed assessment and enqueues '
        'the exact POST body — no request happens from here', () async {
      final SymptomCheckIn checkIn = _checkIn(
        chestPain: const ChestPain(present: true, severity: 8),
      );

      await repository.log(checkIn);

      final List<SymptomHistoryEntry> stored = await repository
          .watchHistory()
          .first;
      expect(stored, hasLength(1));
      expect(stored.single.overallSeverity, Severity.emergency);
      expect(stored.single.serverId, isNull);

      final List<dynamic> captured = verify(
        () => sync.enqueue(
          clientRecordId: 'a',
          entityType: SyncEntityType.symptom,
          payload: captureAny(named: 'payload'),
          recordedAt: checkIn.measuredAt,
        ),
      ).captured;
      final Map<String, dynamic> payload =
          captured.single as Map<String, dynamic>;
      expect(payload['clientRecordId'], 'a');
      expect((payload['data'] as Map)['chestPain'], <String, dynamic>{
        'present': true,
        'severity': 8,
      });

      verifyNever(() => remote.log(any()));
      verifyNever(
        () => remote.fetchHistory(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      );
    });

    test('the locally computed severity matches what the server would compute '
        'for the same payload — the offline/online agreement', () async {
      // Both sides run assessSymptoms against the same data shape, so a
      // check-in's severity does not change when it later syncs.
      final SymptomCheckIn checkIn = _checkIn(
        chestPain: const ChestPain(present: true, severity: 5),
      );

      await repository.log(checkIn);

      final SymptomHistoryEntry stored =
          (await repository.watchHistory().first).single;
      expect(stored.overallSeverity, Severity.urgent);
      expect(stored.assessment.symptoms['chestPain'], Severity.urgent);
    });
  });

  group('reconcileServerAssessments', () {
    test(
      'does nothing, and makes no request, when there is nothing unconfirmed',
      () async {
        await repository.reconcileServerAssessments();

        verifyNever(() => syncQueue.serverIds(any()));
        verifyNever(
          () => remote.fetchHistory(
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        );
      },
    );

    test('leaves a row alone when it has not synced yet', () async {
      await repository.log(_checkIn(clientRecordId: 'a'));
      when(() => syncQueue.serverIds(any()))
          .thenAnswer((_) async => <String, String>{});

      await repository.reconcileServerAssessments();

      verifyNever(
        () => remote.fetchHistory(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      );
      final SymptomHistoryEntry stored =
          (await repository.watchHistory().first).single;
      expect(stored.serverId, isNull);
    });

    test(
      "replaces the local assessment with the server's once synced",
      () async {
        final DateTime measuredAt = DateTime.utc(2026, 8, 30);
        await repository.log(
          _checkIn(
            clientRecordId: 'a',
            // MONITOR locally (severity 2); the "server" disagrees below, to
            // prove its answer actually wins.
            chestPain: const ChestPain(present: true, severity: 2),
            measuredAt: measuredAt,
          ),
        );
        when(() => syncQueue.serverIds(any()))
            .thenAnswer((_) async => <String, String>{'a': 'server-id-1'});
        final SymptomModel serverModel = SymptomModel(
          clientRecordId: 'a',
          serverId: 'server-id-1',
          data: <String, dynamic>{
            'chestPain': <String, dynamic>{'present': true, 'severity': 2},
            'shortnessOfBreath': 'NONE',
            'heartRate': 72,
            'bloodPressure': <String, dynamic>{
              'systolic': 120,
              'diastolic': 80,
            },
            'swelling': false,
            'energyLevel': 7,
          },
          assessment: <String, dynamic>{
            'overall': 'URGENT',
            'symptoms': <String, dynamic>{'chestPain': 'URGENT'},
          },
          overallSeverity: 'URGENT',
          measuredAt: measuredAt,
        );
        when(
          // Not an exact DateTime match: Drift's storage round-trip doesn't
          // guarantee bit-for-bit equality with the value that went in, and
          // asserting the reconcile window down to the microsecond would
          // over-specify a timing detail this test isn't about.
          () => remote.fetchHistory(
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        ).thenAnswer((_) async => <SymptomModel>[serverModel]);

        await repository.reconcileServerAssessments();

        final SymptomHistoryEntry stored =
            (await repository.watchHistory().first).single;
        expect(stored.serverId, 'server-id-1');
        expect(stored.overallSeverity, Severity.urgent);
        // The patient's own entered data is untouched.
        expect(stored.checkIn.chestPain.severity, 2);
      },
    );

    test(
      'a fetchHistory failure is swallowed — the row stays unconfirmed',
      () async {
        await repository.log(_checkIn(clientRecordId: 'a'));
        when(() => syncQueue.serverIds(any()))
            .thenAnswer((_) async => <String, String>{'a': 'server-id-1'});
        when(
          () => remote.fetchHistory(
            from: any(named: 'from'),
            to: any(named: 'to'),
          ),
        ).thenThrow(Exception('offline'));

        await expectLater(repository.reconcileServerAssessments(), completes);

        final SymptomHistoryEntry stored =
            (await repository.watchHistory().first).single;
        expect(stored.serverId, isNull);
      },
    );

    test('a row with no match in the server response stays unconfirmed rather '
        'than crashing', () async {
      await repository.log(_checkIn(clientRecordId: 'a'));
      when(() => syncQueue.serverIds(any()))
          .thenAnswer((_) async => <String, String>{'a': 'server-id-1'});
      when(
        () => remote.fetchHistory(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => <SymptomModel>[]);

      await expectLater(repository.reconcileServerAssessments(), completes);

      final SymptomHistoryEntry stored =
          (await repository.watchHistory().first).single;
      expect(stored.serverId, isNull);
    });
  });
}
