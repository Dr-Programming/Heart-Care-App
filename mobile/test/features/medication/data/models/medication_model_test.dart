import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/data/models/medication_model.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';

void main() {
  final Map<String, dynamic> wireJson = <String, dynamic>{
    'id': 'server-1',
    'name': 'Atorvastatin',
    'doseMg': 20.0,
    'frequency': 'ONCE_DAILY',
    'scheduleTimes': <String>['08:00'],
    'active': true,
    'clientRecordId': 'client-1',
    'createdAt': '2026-07-19T10:00:00Z',
    'updatedAt': '2026-07-19T10:00:00Z',
  };

  test('fromJson parses the documented response shape', () {
    final MedicationModel model = MedicationModel.fromJson(wireJson);
    expect(model.id, 'server-1');
    expect(model.name, 'Atorvastatin');
    expect(model.doseMg, 20.0);
    expect(model.frequency, 'ONCE_DAILY');
    expect(model.scheduleTimes, <String>['08:00']);
    expect(model.clientRecordId, 'client-1');
  });

  test('toEntity maps to the domain Medication', () {
    final MedicationModel model = MedicationModel.fromJson(wireJson);
    final Medication entity = model.toEntity();
    expect(entity.clientRecordId, 'client-1');
    expect(entity.serverId, 'server-1');
    expect(entity.frequency, MedicationFrequency.onceDaily);
    expect(entity.scheduleTimes, <String>['08:00']);
  });

  test('fromEntity round-trips back to matching wire fields', () {
    final Medication entity = Medication(
      clientRecordId: 'client-2',
      serverId: null,
      name: 'Aspirin',
      doseMg: 75,
      frequency: MedicationFrequency.bid,
      scheduleTimes: const <String>['08:00', '20:00'],
      active: true,
      createdAt: DateTime.utc(2026, 8, 25),
      updatedAt: DateTime.utc(2026, 8, 25),
    );
    final MedicationModel model = MedicationModel.fromEntity(entity);
    expect(model.id, isNull);
    expect(model.name, 'Aspirin');
    expect(model.frequency, 'BID');
    expect(model.clientRecordId, 'client-2');
  });

  test('toCompanion carries the JSON-encoded schedule and the client id as key', () {
    final MedicationModel model = MedicationModel.fromJson(wireJson);
    final companion = model.toCompanion();
    expect(companion.clientRecordId.value, 'client-1');
    expect(companion.scheduleTimesJson.value, '["08:00"]');
  });
}
