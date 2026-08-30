import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/bmi.dart';

void main() {
  group('calculateBmi', () {
    test('70 kg at 175 cm is 22.9', () {
      expect(calculateBmi(weightKg: 70, heightCm: 175), 22.9);
    });

    test('null height yields null, not zero or an exception', () {
      expect(calculateBmi(weightKg: 70, heightCm: null), isNull);
    });

    test('zero height does not divide by zero', () {
      expect(calculateBmi(weightKg: 70, heightCm: 0), isNull);
    });

    test('negative height does not divide by zero', () {
      expect(calculateBmi(weightKg: 70, heightCm: -10), isNull);
    });

    test('rounds to one decimal place', () {
      // 68 / (1.70^2) = 23.529... -> 23.5
      expect(calculateBmi(weightKg: 68, heightCm: 170), 23.5);
    });
  });
}
