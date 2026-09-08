import 'package:flutter/material.dart';
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
import 'package:libu_care/features/symptoms/domain/entities/symptom_history_entry.dart';
import 'package:libu_care/features/symptoms/domain/repositories/symptom_repository.dart';
import 'package:libu_care/features/symptoms/presentation/home/check_in_card.dart';
import 'package:libu_care/features/symptoms/presentation/providers/symptom_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

class _MockSyncEnqueuer extends Mock implements SyncEnqueuer {}

class _MockSymptomRemoteDatasource extends Mock
    implements SymptomRemoteDatasource {}

class _ThrowingSymptomRepository implements SymptomRepository {
  @override
  Future<void> log(SymptomCheckIn checkIn) async {}

  @override
  Stream<List<SymptomHistoryEntry>> watchHistory({
    DateTime? from,
    DateTime? to,
  }) => Stream<List<SymptomHistoryEntry>>.error(StateError('boom'));

  @override
  Future<void> reconcileServerAssessments() async {}
}

void main() {
  setUpWidgetTests();

  late AppDatabase db;

  setUpAll(() {
    registerFallbackValue(SyncEntityType.symptom);
  });

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  List<Override> overrides(SymptomRepository repository) => <Override>[
    symptomRepositoryProvider.overrideWithValue(repository),
    appDatabaseProvider.overrideWithValue(db),
  ];

  SymptomRepositoryImpl realRepository() {
    final _MockSyncEnqueuer sync = _MockSyncEnqueuer();
    when(
      () => sync.enqueue(
        clientRecordId: any(named: 'clientRecordId'),
        entityType: any(named: 'entityType'),
        payload: any(named: 'payload'),
        recordedAt: any(named: 'recordedAt'),
      ),
    ).thenAnswer((_) async {});
    return SymptomRepositoryImpl(
      local: SymptomLocalDatasource(db),
      sync: sync,
      remote: _MockSymptomRemoteDatasource(),
      syncQueue: SyncQueueDao(db),
    );
  }

  testWidgets('shows "—" when nothing has been logged today', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: CheckInHomeCard()),
      overrides: overrides(realRepository()),
    );

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Not done yet'), findsOneWidget);
  });

  testWidgets("shows today's severity once checked in", (
    WidgetTester tester,
  ) async {
    final SymptomRepositoryImpl repository = realRepository();
    await SymptomLocalDatasource(db).insert(
      SymptomModel.fromEntity(
        SymptomCheckIn(
          clientRecordId: 'a',
          chestPain: const ChestPain(present: true, severity: 8),
          shortnessOfBreath: ShortnessOfBreath.none,
          heartRate: 72,
          bloodPressure: const BloodPressureReading(
            systolic: 120,
            diastolic: 80,
          ),
          swelling: false,
          energyLevel: 7,
          measuredAt: DateTime.now(),
        ),
      ),
    );

    await pumpApp(
      tester,
      const Scaffold(body: CheckInHomeCard()),
      overrides: overrides(repository),
    );

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Emergency'), findsOneWidget);
  });

  testWidgets('never throws — a stream error degrades to "—"', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: CheckInHomeCard()),
      overrides: overrides(_ThrowingSymptomRepository()),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('—'), findsOneWidget);
  });
}
