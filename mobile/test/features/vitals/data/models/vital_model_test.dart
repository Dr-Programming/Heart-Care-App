import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/features/vitals/data/models/vital_model.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';

void main() {
  final VitalReading bpReading = VitalReading(
    clientRecordId: 'crid-1',
    type: VitalType.bloodPressure,
    values: <String, double>{'systolic': 190, 'diastolic': 100},
    flagged: true,
    measuredAt: DateTime.utc(2026, 8, 30, 8, 15),
    note: 'felt dizzy',
  );

  test('fromEntity then toJson emits exactly the POST body shape', () {
    final Map<String, dynamic> json = VitalModel.fromEntity(bpReading).toJson();
    expect(
      json.keys,
      containsAll(<String>[
        'clientRecordId',
        'type',
        'values',
        'measuredAt',
        'note',
      ]),
    );
    expect(json.containsKey('id'), isFalse);
    expect(json.containsKey('flagged'), isFalse);
    expect(json.containsKey('bmi'), isFalse);
    expect(json['type'], 'BLOOD_PRESSURE');
    expect(json['values'], <String, double>{'systolic': 190, 'diastolic': 100});
    expect(json['measuredAt'], '2026-08-30T08:15:00.000Z');
  });

  test('fromJson parses a full response, including server-only fields', () {
    final VitalModel model = VitalModel.fromJson(<String, dynamic>{
      'id': 'server-uuid',
      'clientRecordId': 'crid-1',
      'type': 'WEIGHT',
      'values': <String, dynamic>{'weight': 72, 'bmi': 23.5},
      'flagged': false,
      'bmi': 23.5,
      'measuredAt': '2026-08-30T08:15:00Z',
      'note': null,
    });
    expect(model.serverId, 'server-uuid');
    expect(model.bmi, 23.5);
    expect(model.values['weight'], 72.0);
    expect(model.values['weight'], isA<double>());
  });

  test('toEntity round-trips values, flagged and bmi', () {
    final VitalModel model = VitalModel.fromEntity(bpReading);
    final VitalReading roundTripped = model.toEntity();
    expect(roundTripped.clientRecordId, bpReading.clientRecordId);
    expect(roundTripped.type, VitalType.bloodPressure);
    expect(roundTripped.values, bpReading.values);
    expect(roundTripped.flagged, isTrue);
    expect(roundTripped.measuredAt, bpReading.measuredAt);
  });

  test('toCompanion produces an insertable row with valuesJson encoded', () {
    final VitalsLogsCompanion companion = VitalModel.fromEntity(bpReading)
        .toCompanion();
    expect(companion.clientRecordId.value, 'crid-1');
    expect(companion.type.value, 'BLOOD_PRESSURE');
    expect(companion.valuesJson.value, contains('"systolic":190'));
    expect(companion.flagged.value, isTrue);
  });
}
