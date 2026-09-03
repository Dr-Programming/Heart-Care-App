import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_local_datasource.dart';
import 'package:libu_care/features/vitals/data/models/vital_model.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/repositories/vitals_repository.dart';

import '../../../../helpers/test_database.dart';

VitalModel _model(
  VitalType type,
  Map<String, double> values, {
  String? id,
  DateTime? measuredAt,
}) {
  return VitalModel(
    clientRecordId:
        id ?? 'crid-${type.wire}-${measuredAt?.microsecondsSinceEpoch}',
    type: type.wire,
    values: values,
    flagged: false,
    measuredAt: measuredAt ?? DateTime(2026, 8, 30),
  );
}

void main() {
  late AppDatabase db;
  late VitalsLocalDataSource dataSource;

  setUp(() {
    db = testDatabase();
    dataSource = VitalsLocalDataSource(db);
  });

  tearDown(() => db.close());

  test(
    'round-trips each of the five types with its own values shape',
    () async {
      final Map<VitalType, Map<String, double>> byType =
          <VitalType, Map<String, double>>{
            VitalType.bloodPressure: <String, double>{
              'systolic': 120,
              'diastolic': 80,
            },
            VitalType.glucose: <String, double>{'glucose': 5.5},
            VitalType.heartRate: <String, double>{'heartRate': 72},
            VitalType.weight: <String, double>{'weight': 70},
            VitalType.cholesterol: <String, double>{
              'ldl': 2.5,
              'hdl': 1.2,
              'total': 4.5,
            },
          };

      for (final MapEntry<VitalType, Map<String, double>> entry
          in byType.entries) {
        await dataSource.insert(
          _model(entry.key, entry.value, id: entry.key.wire),
        );
      }

      for (final MapEntry<VitalType, Map<String, double>> entry
          in byType.entries) {
        final VitalModel? latest = await dataSource.latestByType(entry.key);
        expect(latest, isNotNull, reason: entry.key.wire);
        expect(latest!.values, entry.value, reason: entry.key.wire);
      }
    },
  );

  test('history is newest-first', () async {
    await dataSource.insert(
      _model(
        VitalType.glucose,
        <String, double>{'glucose': 5.0},
        id: '1',
        measuredAt: DateTime(2026, 8, 1),
      ),
    );
    await dataSource.insert(
      _model(
        VitalType.glucose,
        <String, double>{'glucose': 6.0},
        id: '2',
        measuredAt: DateTime(2026, 8, 15),
      ),
    );
    await dataSource.insert(
      _model(
        VitalType.glucose,
        <String, double>{'glucose': 7.0},
        id: '3',
        measuredAt: DateTime(2026, 8, 10),
      ),
    );

    final List<VitalModel> history = await dataSource.watchHistory().first;
    expect(history.map((VitalModel m) => m.clientRecordId), <String>[
      '2',
      '3',
      '1',
    ]);
  });

  test('the type filter works', () async {
    await dataSource.insert(
      _model(VitalType.glucose, <String, double>{'glucose': 5.0}, id: 'g1'),
    );
    await dataSource.insert(
      _model(VitalType.weight, <String, double>{'weight': 70}, id: 'w1'),
    );

    final List<VitalModel> glucoseOnly = await dataSource
        .watchHistory(type: VitalType.glucose)
        .first;
    expect(glucoseOnly.map((VitalModel m) => m.clientRecordId), <String>['g1']);
  });

  test('the date-window query has inclusive bounds', () async {
    await dataSource.insert(
      _model(
        VitalType.glucose,
        <String, double>{'glucose': 5.0},
        id: 'before',
        measuredAt: DateTime(2026, 7, 31),
      ),
    );
    await dataSource.insert(
      _model(
        VitalType.glucose,
        <String, double>{'glucose': 6.0},
        id: 'on-from',
        measuredAt: DateTime(2026, 8, 1),
      ),
    );
    await dataSource.insert(
      _model(
        VitalType.glucose,
        <String, double>{'glucose': 7.0},
        id: 'on-to',
        measuredAt: DateTime(2026, 8, 31),
      ),
    );
    await dataSource.insert(
      _model(
        VitalType.glucose,
        <String, double>{'glucose': 8.0},
        id: 'after',
        measuredAt: DateTime(2026, 9, 1),
      ),
    );

    final List<VitalModel> windowed = await dataSource
        .watchHistory(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31))
        .first;
    expect(windowed.map((VitalModel m) => m.clientRecordId).toSet(), <String>{
      'on-from',
      'on-to',
    });
  });

  test('latest-by-type returns nothing for a type never recorded', () async {
    expect(await dataSource.latestByType(VitalType.cholesterol), isNull);
  });

  test('an insertOrIgnore retry does not duplicate a row', () async {
    final VitalModel model = _model(VitalType.glucose, <String, double>{
      'glucose': 5.0,
    }, id: 'dup');
    await dataSource.insert(model);
    await dataSource.insert(model);

    final List<VitalModel> history = await dataSource.watchHistory().first;
    expect(history, hasLength(1));
  });

  group('readHeightCm', () {
    test('returns null when no profile row exists yet', () async {
      expect(await dataSource.readHeightCm(), isNull);
    });

    test('returns the stored height', () async {
      await db
          .into(db.patientProfiles)
          .insert(
            PatientProfilesCompanion.insert(
              userId: 'u1',
              heightCm: const Value<double?>(175),
              updatedAt: DateTime(2026, 8, 30),
            ),
          );
      expect(await dataSource.readHeightCm(), 175);
    });
  });

  group('readGoals', () {
    test('returns null when no profile row exists yet', () async {
      expect(await dataSource.readGoals(), isNull);
    });

    test(
      'parses bpSystolic, bpDiastolic and targetWeightKg from goalsJson',
      () async {
        await db
            .into(db.patientProfiles)
            .insert(
              PatientProfilesCompanion.insert(
                userId: 'u1',
                goalsJson: const Value<String?>(
                  '{"bpSystolic":120,"bpDiastolic":80,"targetWeightKg":68}',
                ),
                updatedAt: DateTime(2026, 8, 30),
              ),
            );
        final VitalGoals? goals = await dataSource.readGoals();
        expect(goals?.bpSystolic, 120);
        expect(goals?.bpDiastolic, 80);
        expect(goals?.targetWeightKg, 68);
      },
    );
  });
}
