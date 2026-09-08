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
import 'package:libu_care/features/symptoms/presentation/screens/check_in_hub_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

class _MockSyncEnqueuer extends Mock implements SyncEnqueuer {}

class _MockSymptomRemoteDatasource extends Mock
    implements SymptomRemoteDatasource {}

class _MockSyncQueueDao extends Mock implements SyncQueueDao {}

void main() {
  setUpWidgetTests();

  late AppDatabase db;
  late SymptomRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(SyncEntityType.symptom);
    registerFallbackValue(DateTime(2000, 1, 1));
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    db = testDatabase();
    final _MockSyncEnqueuer sync = _MockSyncEnqueuer();
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
      remote: _MockSymptomRemoteDatasource(),
      syncQueue: _MockSyncQueueDao(),
    );
  });

  tearDown(() => db.close());

  List<Override> overrides() => <Override>[
    symptomRepositoryProvider.overrideWithValue(repository),
    appDatabaseProvider.overrideWithValue(db),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  ];

  testWidgets('prompts for a check-in when nothing has been logged today', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const CheckInHubScreen(), overrides: overrides());

    expect(find.text("Today's check-in"), findsOneWidget);
    expect(find.text('Start check-in'), findsOneWidget);
  });

  testWidgets("shows today's result once a check-in exists", (
    WidgetTester tester,
  ) async {
    final SymptomCheckIn checkIn = SymptomCheckIn(
      clientRecordId: 'a',
      chestPain: const ChestPain(present: true, severity: 8),
      shortnessOfBreath: ShortnessOfBreath.none,
      heartRate: 72,
      bloodPressure: const BloodPressureReading(systolic: 120, diastolic: 80),
      swelling: false,
      energyLevel: 7,
      measuredAt: DateTime.now(),
    );
    await SymptomLocalDatasource(db).insert(SymptomModel.fromEntity(checkIn));

    await pumpApp(tester, const CheckInHubScreen(), overrides: overrides());

    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('Call your emergency contact now.'), findsOneWidget);
    expect(find.text('Start check-in'), findsNothing);
  });

  testWidgets('shows entry points to activity logging and both histories', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const CheckInHubScreen(), overrides: overrides());

    expect(find.text('Symptom history'), findsOneWidget);
    expect(find.text('Log activity'), findsOneWidget);
    expect(find.text('Activity history'), findsOneWidget);
  });
}
