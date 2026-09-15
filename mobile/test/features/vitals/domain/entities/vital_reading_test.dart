import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

void main() {
  test('copyWith overrides only the given fields', () {
    final VitalReading reading = VitalReading(
      clientRecordId: 'c1',
      serverId: null,
      type: VitalType.weight,
      values: <String, double>{'weight': 70},
      flagged: false,
      bmi: null,
      measuredAt: DateTime.utc(2026, 9, 5),
      note: null,
    );

    final VitalReading synced = reading.copyWith(
      serverId: 's1',
      bmi: 22.9,
    );

    expect(synced.serverId, 's1');
    expect(synced.bmi, 22.9);
    expect(synced.clientRecordId, 'c1');
    expect(synced.flagged, false);
  });

  test('VitalGoals.fromJson reads only the fields vitals cares about', () {
    final VitalGoals goals = VitalGoals.fromJson(<String, dynamic>{
      'bpSystolic': 130,
      'bpDiastolic': 80,
      'totalCholesterol': 5.0,
      'targetWeightKg': 75,
      'stepsPerDay': 8000,
      'dietNote': 'low sodium',
    });

    expect(goals.bpSystolic, 130.0);
    expect(goals.bpDiastolic, 80.0);
    expect(goals.totalCholesterol, 5.0);
    expect(goals.targetWeightKg, 75.0);
  });

  test('VitalGoals.fromJson tolerates missing fields', () {
    final VitalGoals goals = VitalGoals.fromJson(<String, dynamic>{});
    expect(goals.bpSystolic, isNull);
  });
}
