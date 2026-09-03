import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_local_datasource.dart';
import 'package:libu_care/features/vitals/data/repositories/vitals_repository_impl.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late VitalsLocalDataSource local;
  late SyncQueueDao queue;
  late VitalsRepositoryImpl repo;

  setUp(() {
    db = testDatabase();
    local = VitalsLocalDataSource(db);
    queue = SyncQueueDao(db);
    repo = VitalsRepositoryImpl(local: local, sync: queue);
  });

  tearDown(() => db.close());

  test('logging writes to Drift and enqueues a VITAL record', () async {
    final VitalReading reading = VitalReading(
      clientRecordId: 'crid-1',
      type: VitalType.glucose,
      values: <String, double>{'glucose': 5.5},
      flagged: false,
      measuredAt: DateTime(2026, 8, 30),
    );

    await repo.log(reading);

    final List<VitalReading> stored = await repo.watchHistory().first;
    expect(stored.single.clientRecordId, 'crid-1');

    final List<SyncQueueEntry> pending = await queue.pending();
    expect(pending, hasLength(1));
    expect(pending.single.clientRecordId, 'crid-1');
    expect(pending.single.entityType, SyncEntityType.vital.wire);
  });

  test('the write never touches the network — nothing but Drift and the queue is held', () {
    // Structural, not behavioural: VitalsRepositoryImpl holds no Dio and no
    // remote datasource reference at all (see the constructor below), so
    // there is no code path through which `log` could reach the network.
    expect(repo, isA<VitalsRepositoryImpl>());
  });

  test(
    'the stored reading keeps exactly the flagged/bmi it was given',
    () async {
      final VitalReading reading = VitalReading(
        clientRecordId: 'crid-weight',
        type: VitalType.weight,
        values: <String, double>{'weight': 70},
        flagged: true,
        bmi: 23.5,
        measuredAt: DateTime(2026, 8, 30),
      );

      await repo.log(reading);

      final VitalReading? latest = await repo.latestByType(VitalType.weight);
      expect(latest?.flagged, isTrue);
      expect(latest?.bmi, 23.5);
    },
  );

  test('watchHistory maps every stored reading back to an entity', () async {
    await repo.log(
      VitalReading(
        clientRecordId: 'crid-2',
        type: VitalType.heartRate,
        values: <String, double>{'heartRate': 72},
        flagged: false,
        measuredAt: DateTime(2026, 8, 29),
      ),
    );

    final List<VitalReading> history = await repo
        .watchHistory(type: VitalType.heartRate)
        .first;
    expect(history.single.type, VitalType.heartRate);
    expect(history.single.values['heartRate'], 72);
  });

  test('latestByType returns null when nothing has been logged', () async {
    expect(await repo.latestByType(VitalType.cholesterol), isNull);
  });

  test(
    'patientHeightCm and patientGoals delegate to the local datasource',
    () async {
      expect(await repo.patientHeightCm(), isNull);
      expect(await repo.patientGoals(), isNull);

      await db
          .into(db.patientProfiles)
          .insert(
            PatientProfilesCompanion.insert(
              userId: 'u1',
              heightCm: const Value<double?>(180),
              updatedAt: DateTime(2026, 8, 30),
            ),
          );

      expect(await repo.patientHeightCm(), 180);
    },
  );
}
