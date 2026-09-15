import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/vital_descriptors.dart';

void main() {
  test('every type declares exactly the keys the API requires', () {
    expect(
      vitalDescriptors[VitalType.bloodPressure]!.requiredKeys,
      containsAll(<String>['systolic', 'diastolic']),
    );
    expect(
      vitalDescriptors[VitalType.bloodPressure]!.requiredKeys.length,
      2,
    );
    expect(vitalDescriptors[VitalType.glucose]!.requiredKeys, <String>[
      'glucose',
    ]);
    expect(vitalDescriptors[VitalType.heartRate]!.requiredKeys, <String>[
      'heartRate',
    ]);
    expect(vitalDescriptors[VitalType.weight]!.requiredKeys, <String>[
      'weight',
    ]);
    expect(
      vitalDescriptors[VitalType.cholesterol]!.requiredKeys,
      containsAll(<String>['ldl', 'hdl', 'total']),
    );
    expect(
      vitalDescriptors[VitalType.cholesterol]!.requiredKeys.length,
      3,
    );
  });

  test('wire round-trips for every type', () {
    for (final VitalType type in VitalType.values) {
      expect(VitalType.fromWire(type.wire), type);
    }
  });
}
