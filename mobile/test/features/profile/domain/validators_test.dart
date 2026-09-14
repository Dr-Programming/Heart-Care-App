import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/domain/validators.dart';

void main() {
  group('validateBirthYear', () {
    test('accepts a year inside 1900-2100', () => expect(validateBirthYear(1968), isNull));
    test('accepts the boundary years', () {
      expect(validateBirthYear(1900), isNull);
      expect(validateBirthYear(2100), isNull);
    });
    test('rejects a year before 1900', () => expect(validateBirthYear(1899), 'profile.errors.birthYearRange'));
    test('rejects a year after 2100', () => expect(validateBirthYear(2101), 'profile.errors.birthYearRange'));
    test('null is allowed - the field is optional in the wizard', () => expect(validateBirthYear(null), isNull));
  });

  group('validateHeightCm', () {
    test('accepts a height inside 50-250', () => expect(validateHeightCm(172), isNull));
    test('accepts the boundaries', () {
      expect(validateHeightCm(50), isNull);
      expect(validateHeightCm(250), isNull);
    });
    test('rejects below 50', () => expect(validateHeightCm(49.9), 'profile.errors.heightRange'));
    test('rejects above 250', () => expect(validateHeightCm(250.1), 'profile.errors.heightRange'));
    test('null is allowed', () => expect(validateHeightCm(null), isNull));
  });

  group('validateGoalValue', () {
    test('accepts a non-negative value', () => expect(validateGoalValue(6000, fieldKey: 'stepsPerDay'), isNull));
    test('accepts zero', () => expect(validateGoalValue(0, fieldKey: 'stepsPerDay'), isNull));
    test('rejects a negative value', () => expect(validateGoalValue(-1, fieldKey: 'stepsPerDay'), 'profile.errors.goalNegative'));
    test('null is allowed', () => expect(validateGoalValue(null, fieldKey: 'stepsPerDay'), isNull));
  });
}
