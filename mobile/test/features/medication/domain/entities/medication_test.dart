import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/entities/medication.dart';

void main() {
  group('MedicationFrequency', () {
    test('wire values match the backend exactly', () {
      expect(MedicationFrequency.onceDaily.wire, 'ONCE_DAILY');
      expect(MedicationFrequency.bid.wire, 'BID');
      expect(MedicationFrequency.tid.wire, 'TID');
      expect(MedicationFrequency.custom.wire, 'CUSTOM');
    });

    test('fromWire round-trips every value', () {
      for (final MedicationFrequency f in MedicationFrequency.values) {
        expect(MedicationFrequency.fromWire(f.wire), f);
      }
    });
  });

  group('Medication', () {
    test('holds every field passed to its constructor', () {
      final DateTime now = DateTime(2026, 8, 25, 9);
      final Medication medication = Medication(
        clientRecordId: 'c1',
        serverId: 's1',
        name: 'Atorvastatin',
        doseMg: 20,
        frequency: MedicationFrequency.onceDaily,
        scheduleTimes: const <String>['08:00'],
        active: true,
        createdAt: now,
        updatedAt: now,
      );

      expect(medication.clientRecordId, 'c1');
      expect(medication.serverId, 's1');
      expect(medication.name, 'Atorvastatin');
      expect(medication.doseMg, 20);
      expect(medication.frequency, MedicationFrequency.onceDaily);
      expect(medication.scheduleTimes, <String>['08:00']);
      expect(medication.active, isTrue);
    });
  });
}
