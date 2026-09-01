import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/domain/validators.dart';

void main() {
  group('ProfileValidators.birthYear', () {
    test('accepts null', () {
      expect(ProfileValidators.birthYear(null).isValid, true);
    });

    test('accepts a valid year', () {
      expect(ProfileValidators.birthYear(1990).isValid, true);
    });

    test('rejects a year before 1900', () {
      expect(ProfileValidators.birthYear(1899).isValid, false);
    });

    test('rejects a year after 2100', () {
      expect(ProfileValidators.birthYear(2101).isValid, false);
    });
  });

  group('ProfileValidators.heightCm', () {
    test('accepts null', () {
      expect(ProfileValidators.heightCm(null).isValid, true);
    });

    test('accepts a valid height', () {
      expect(ProfileValidators.heightCm(170).isValid, true);
    });

    test('rejects below 50', () {
      expect(ProfileValidators.heightCm(49).isValid, false);
    });

    test('rejects above 250', () {
      expect(ProfileValidators.heightCm(251).isValid, false);
    });
  });

  group('ProfileValidators.chdStage', () {
    test('accepts null', () {
      expect(ProfileValidators.chdStage(null).isValid, true);
    });

    test('accepts a short diagnosis string', () {
      expect(ProfileValidators.chdStage('Coronary artery disease').isValid, true);
    });

    test('rejects a string over 50 characters', () {
      final longStage = 'x' * 51;
      expect(ProfileValidators.chdStage(longStage).isValid, false);
    });
  });

  group('ProfileValidators.nonNegative', () {
    test('accepts null', () {
      expect(ProfileValidators.nonNegative(null, 'Steps').isValid, true);
    });

    test('accepts zero', () {
      expect(ProfileValidators.nonNegative(0, 'Steps').isValid, true);
    });

    test('accepts a positive number', () {
      expect(ProfileValidators.nonNegative(5000, 'Steps').isValid, true);
    });

    test('rejects a negative number', () {
      expect(ProfileValidators.nonNegative(-1, 'Steps').isValid, false);
    });
  });
}