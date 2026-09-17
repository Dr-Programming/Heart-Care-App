import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/vital_descriptors.dart';

void main() {
  group('VitalType', () {
    test('round-trips through the wire form', () {
      for (final VitalType type in VitalType.values) {
        expect(VitalType.fromWire(type.wire), type);
      }
    });

    test('wire values match the backend enum exactly', () {
      expect(VitalType.bloodPressure.wire, 'BLOOD_PRESSURE');
      expect(VitalType.glucose.wire, 'GLUCOSE');
      expect(VitalType.heartRate.wire, 'HEART_RATE');
      expect(VitalType.weight.wire, 'WEIGHT');
      expect(VitalType.cholesterol.wire, 'CHOLESTEROL');
    });
  });

  group('vitalDescriptors', () {
    test('every type has a descriptor', () {
      for (final VitalType type in VitalType.values) {
        expect(vitalDescriptors.containsKey(type), isTrue, reason: type.name);
      }
    });

    test('blood pressure requires exactly systolic and diastolic, 40-300', () {
      final VitalDescriptor d = vitalDescriptors[VitalType.bloodPressure]!;
      expect(d.requiredKeys, <String>['systolic', 'diastolic']);
      expect(d.ranges['systolic'], (min: 40, max: 300));
      expect(d.ranges['diastolic'], (min: 40, max: 300));
      expect(d.unit, 'mmHg');
    });

    test('glucose requires exactly glucose, 0-50 mmol/L', () {
      final VitalDescriptor d = vitalDescriptors[VitalType.glucose]!;
      expect(d.requiredKeys, <String>['glucose']);
      expect(d.ranges['glucose'], (min: 0, max: 50));
      expect(d.unit, 'mmol/L');
    });

    test('heart rate requires exactly heartRate, 20-300 bpm', () {
      final VitalDescriptor d = vitalDescriptors[VitalType.heartRate]!;
      expect(d.requiredKeys, <String>['heartRate']);
      expect(d.ranges['heartRate'], (min: 20, max: 300));
      expect(d.unit, 'bpm');
    });

    test('weight requires exactly weight, 0-500 kg', () {
      final VitalDescriptor d = vitalDescriptors[VitalType.weight]!;
      expect(d.requiredKeys, <String>['weight']);
      expect(d.ranges['weight'], (min: 0, max: 500));
      expect(d.unit, 'kg');
    });

    test('cholesterol requires exactly ldl, hdl, total, each 0-30 mmol/L', () {
      final VitalDescriptor d = vitalDescriptors[VitalType.cholesterol]!;
      expect(d.requiredKeys, <String>['ldl', 'hdl', 'total']);
      expect(d.ranges['ldl'], (min: 0, max: 30));
      expect(d.ranges['hdl'], (min: 0, max: 30));
      expect(d.ranges['total'], (min: 0, max: 30));
      expect(d.unit, 'mmol/L');
    });
  });
}
