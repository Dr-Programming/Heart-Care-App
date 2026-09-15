import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/data/models/vital_model.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

void main() {
  test('fromEntity/toEntity round-trips', () {
    final VitalReading reading = VitalReading(
      clientRecordId: 'c1',
      serverId: null,
      type: VitalType.bloodPressure,
      values: <String, double>{'systolic': 128, 'diastolic': 82},
      flagged: false,
      bmi: null,
      measuredAt: DateTime.utc(2026, 8, 22, 6, 30),
      note: 'before breakfast',
    );

    final VitalModel model = VitalModel.fromEntity(reading);
    final VitalReading restored = model.toEntity();

    expect(restored.clientRecordId, reading.clientRecordId);
    expect(restored.type, reading.type);
    expect(restored.values, reading.values);
    expect(restored.note, reading.note);
  });

  test('toJson sends UTC ISO-8601 measuredAt', () {
    final VitalModel model = VitalModel(
      clientRecordId: 'c1',
      type: 'BLOOD_PRESSURE',
      values: <String, double>{'systolic': 128, 'diastolic': 82},
      measuredAt: DateTime.utc(2026, 8, 22, 6, 30),
    );

    expect(model.toJson()['measuredAt'], '2026-08-22T06:30:00.000Z');
  });

  test('fromJson parses a server response envelope payload', () {
    final VitalModel model = VitalModel.fromJson(<String, dynamic>{
      'id': 'server-1',
      'type': 'WEIGHT',
      'values': <String, dynamic>{'weight': 70},
      'flagged': false,
      'bmi': 22.9,
      'measuredAt': '2026-08-22T06:30:00Z',
    });

    expect(model.serverId, 'server-1');
    expect(model.type, 'WEIGHT');
    expect(model.values['weight'], 70.0);
    expect(model.bmi, 22.9);
  });
}
