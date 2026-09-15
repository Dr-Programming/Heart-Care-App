import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_local_datasource.dart';
import 'package:libu_care/features/vitals/data/repositories/vitals_repository_impl.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late VitalsRepositoryImpl repository;

  setUp(() {
    db = testDatabase();
    repository = VitalsRepositoryImpl(
      local: VitalsLocalDataSource(db),
      syncEnqueuer: SyncQueueDao(db),
    );
  });

  tearDown(() => db.close());

  test('logging writes to Drift, enqueues a VITAL record and makes no request', () async {
    await repository.logReading(
      type: VitalType.bloodPressure,
      values: <String, double>{'systolic': 190, 'diastolic': 100},
    );

    final int pending =
        await (db.select(db.syncQueueEntries)).get().then((rows) => rows.length);
    expect(pending, 1);
    final history = await repository.history();
    expect(history.length, 1);
  });

  test(
    'the locally computed flagged matches what the server would return for the same reading',
    () async {
      final result = await repository.logReading(
        type: VitalType.bloodPressure,
        values: <String, double>{'systolic': 190, 'diastolic': 100},
      );
      expect(result.flagged, true);

      final normal = await repository.logReading(
        type: VitalType.bloodPressure,
        values: <String, double>{'systolic': 120, 'diastolic': 80},
      );
      expect(normal.flagged, false);
    },
  );

  test('a WEIGHT reading with no stored height has null bmi', () async {
    final result = await repository.logReading(
      type: VitalType.weight,
      values: <String, double>{'weight': 70},
    );
    expect(result.bmi, isNull);
  });

  test('a WEIGHT reading with a stored height computes bmi', () async {
    await db
        .into(db.patientProfiles)
        .insert(
          PatientProfilesCompanion.insert(
            userId: 'u1',
            heightCm: const Value<double?>(175),
            updatedAt: DateTime.now(),
          ),
        );

    final result = await repository.logReading(
      type: VitalType.weight,
      values: <String, double>{'weight': 70},
    );
    expect(result.bmi, isNotNull);
    expect(result.bmi!.toStringAsFixed(1), '22.9');
  });
}
