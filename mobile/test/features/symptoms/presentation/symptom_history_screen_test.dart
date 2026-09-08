import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/features/symptoms/data/datasources/symptom_local_datasource.dart';
import 'package:libu_care/features/symptoms/data/datasources/symptom_remote_datasource.dart';
import 'package:libu_care/features/symptoms/data/models/symptom_model.dart';
import 'package:libu_care/features/symptoms/data/repositories/symptom_repository_impl.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_answer.dart';
import 'package:libu_care/features/symptoms/domain/entities/symptom_check_in.dart';
import 'package:libu_care/features/symptoms/presentation/providers/symptom_providers.dart';
import 'package:libu_care/features/symptoms/presentation/screens/symptom_history_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
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
    note: 'felt off after lunch',
  );
}

void main() {
  setUpWidgetTests();

  late AppDatabase db;
  late _MockSyncQueueDao syncQueue;

  setUpAll(() {
    registerFallbackValue(SyncEntityType.symptom);
  });

  setUp(() {
    db = testDatabase();
    syncQueue = _MockSyncQueueDao();
  });

  tearDown(() => db.close());

  List<Override> overrides() => <Override>[
    symptomRepositoryProvider.overrideWithValue(
      SymptomRepositoryImpl(
        local: SymptomLocalDatasource(db),
        sync: _MockSyncEnqueuer(),
        remote: _MockSymptomRemoteDatasource(),
        syncQueue: syncQueue,
      ),
    ),
    appDatabaseProvider.overrideWithValue(db),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
    // symptomSyncStatusProvider reads the shared syncQueueDaoProvider, not
    // the repository's own _syncQueue field — both must point at the mock.
    syncQueueDaoProvider.overrideWithValue(syncQueue),
  ];

  testWidgets('shows an empty state with no check-ins logged yet', (
    WidgetTester tester,
  ) async {
    when(() => syncQueue.statusFor(any())).thenAnswer((_) async => null);

    await pumpApp(tester, const SymptomHistoryScreen(), overrides: overrides());

    expect(find.text('No check-ins yet'), findsOneWidget);
  });

  testWidgets('shows a severity chip and sync state per row', (
    WidgetTester tester,
  ) async {
    await SymptomLocalDatasource(db).insert(
      SymptomModel.fromEntity(
        _checkIn(
          clientRecordId: 'a',
          chestPain: const ChestPain(present: true, severity: 8),
        ),
      ),
    );
    when(() => syncQueue.statusFor('a'))
        .thenAnswer((_) async => LocalSyncStatus.synced);

    await pumpApp(tester, const SymptomHistoryScreen(), overrides: overrides());

    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
  });

  testWidgets('a pending row shows "waiting to send"', (
    WidgetTester tester,
  ) async {
    await SymptomLocalDatasource(db)
        .insert(SymptomModel.fromEntity(_checkIn(clientRecordId: 'a')));
    when(() => syncQueue.statusFor('a'))
        .thenAnswer((_) async => LocalSyncStatus.pending);

    await pumpApp(tester, const SymptomHistoryScreen(), overrides: overrides());

    expect(find.text('Waiting to send'), findsOneWidget);
  });

  testWidgets('tapping a row opens its detail', (WidgetTester tester) async {
    await SymptomLocalDatasource(db).insert(
      SymptomModel.fromEntity(
        _checkIn(
          clientRecordId: 'a',
          chestPain: const ChestPain(present: true, severity: 3),
        ),
      ),
    );
    when(() => syncQueue.statusFor('a'))
        .thenAnswer((_) async => LocalSyncStatus.synced);

    await pumpApp(tester, const SymptomHistoryScreen(), overrides: overrides());

    await tester.tap(find.text('Sent'));
    await tester.pumpAndSettle();

    expect(find.text('Check-in detail'), findsOneWidget);
    expect(find.text('felt off after lunch'), findsOneWidget);
  });
}
