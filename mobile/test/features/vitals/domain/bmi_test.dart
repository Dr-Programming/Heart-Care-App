import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/bmi.dart';

void main() {
  test('70 kg at 175 cm is 22.9', () {
    final double? bmi = calculateBmi(weightKg: 70, heightCm: 175);
    expect(bmi, isNotNull);
    expect(bmi!.toStringAsFixed(1), '22.9');
  });

  test('null height yields null', () {
    expect(calculateBmi(weightKg: 70, heightCm: null), isNull);
  });

  test('zero height does not throw and yields null', () {
    expect(calculateBmi(weightKg: 70, heightCm: 0), isNull);
  });

  test('negative height does not throw and yields null', () {
    expect(calculateBmi(weightKg: 70, heightCm: -10), isNull);
  });
}
