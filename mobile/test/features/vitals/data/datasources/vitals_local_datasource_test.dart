import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/vitals/data/datasources/vitals_local_datasource.dart';
import 'package:libu_care/features/vitals/data/models/vital_model.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late VitalsLocalDataSource datasource;

  setUp(() {
    db = testDatabase();
    datasource = VitalsLocalDataSource(db);
  });

  tearDown(() => db.close());

  VitalModel model(
    String id,
    VitalType type,
    Map<String, double> values,
    DateTime measuredAt,
  ) {
    return VitalModel(
      clientRecordId: id,
      type: type.wire,
      values: values,
      measuredAt: measuredAt,
    );
  }

  test(
    'round-trips each of the five types with its own values shape',
    () async {
      await datasource.insert(
        model('c1', VitalType.bloodPressure, <String, double>{
          'systolic': 120,
          'diastolic': 80,
        }, DateTime.utc(2026, 9, 1)),
      );
      await datasource.insert(
        model('c2', VitalType.cholesterol, <String, double>{
          'ldl': 3,
          'hdl': 1.2,
          'total': 5.1,
        }, DateTime.utc(2026, 9, 2)),
      );

      final List<dynamic> history = await datasource.history();
      expect(history.length, 2);
    },
  );

  test('history is newest-first', () async {
    await datasource.insert(
      model('c1', VitalType.glucose, <String, double>{
        'glucose': 5,
      }, DateTime.utc(2026, 9, 1)),
    );
    await datasource.insert(
      model('c2', VitalType.glucose, <String, double>{
        'glucose': 6,
      }, DateTime.utc(2026, 9, 3)),
    );

    final List<dynamic> history = await datasource.history();
    expect(history.first.measuredAt.toUtc(), DateTime.utc(2026, 9, 3));
    expect(history.last.measuredAt.toUtc(), DateTime.utc(2026, 9, 1));
  });

  test('the type filter works', () async {
    await datasource.insert(
      model('c1', VitalType.glucose, <String, double>{
        'glucose': 5,
      }, DateTime.utc(2026, 9, 1)),
    );
    await datasource.insert(
      model('c2', VitalType.heartRate, <String, double>{
        'heartRate': 70,
      }, DateTime.utc(2026, 9, 1)),
    );

    final List<dynamic> glucoseOnly = await datasource.history(
      type: VitalType.glucose,
    );
    expect(glucoseOnly.length, 1);
    expect(glucoseOnly.single.type, VitalType.glucose);
  });

  test('the date-window query has the right inclusive bounds', () async {
    await datasource.insert(
      model('c1', VitalType.glucose, <String, double>{
        'glucose': 5,
      }, DateTime.utc(2026, 9, 1)),
    );
    await datasource.insert(
      model('c2', VitalType.glucose, <String, double>{
        'glucose': 6,
      }, DateTime.utc(2026, 9, 8)),
    );

    final List<dynamic> inWindow = await datasource.history(
      from: DateTime.utc(2026, 9, 1),
      to: DateTime.utc(2026, 9, 1),
    );
    expect(inWindow.length, 1);
  });

  test('latest-by-type returns nothing for a type never recorded', () async {
    final Map<VitalType, dynamic> latest = await datasource.latestByType();
    expect(latest[VitalType.weight], isNull);
  });

  test('latest-by-type returns the most recent row per type', () async {
    await datasource.insert(
      model('c1', VitalType.weight, <String, double>{
        'weight': 70,
      }, DateTime.utc(2026, 9, 1)),
    );
    await datasource.insert(
      model('c2', VitalType.weight, <String, double>{
        'weight': 71,
      }, DateTime.utc(2026, 9, 3)),
    );

    final Map<VitalType, dynamic> latest = await datasource.latestByType();
    expect(latest[VitalType.weight]!.values['weight'], 71.0);
  });

  test('latestHeightCm returns null with no profile row', () async {
    expect(await datasource.latestHeightCm(), isNull);
  });

  test('latestGoals returns null with no profile row', () async {
    expect(await datasource.latestGoals(), isNull);
  });
}
