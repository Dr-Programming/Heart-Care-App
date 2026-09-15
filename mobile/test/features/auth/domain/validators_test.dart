import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/domain/validators.dart';

void main() {
  group('validatePhone', () {
    test('accepts a well-formed Ethiopian number', () {
      expect(validatePhone('+251911234567'), isNull);
    });

    test('rejects a number missing the country code', () {
      expect(validatePhone('0911234567'), 'auth.errors.phoneFormat');
    });

    test('rejects a wrong country code', () {
      expect(validatePhone('+1911234567890'), 'auth.errors.phoneFormat');
    });

    test('rejects letters', () {
      expect(validatePhone('+251abc234567'), 'auth.errors.phoneFormat');
    });

    test('rejects too few digits after the country code', () {
      expect(validatePhone('+25191123456'), 'auth.errors.phoneFormat');
    });

    test('rejects too many digits after the country code', () {
      expect(validatePhone('+2519112345678'), 'auth.errors.phoneFormat');
    });

    test('rejects an empty value with the required key', () {
      expect(validatePhone(''), 'auth.errors.phoneRequired');
    });
  });

  group('validatePin', () {
    test('accepts exactly four digits', () {
      expect(validatePin('1234'), isNull);
    });

    test('rejects three digits', () {
      expect(validatePin('123'), 'auth.errors.pinFormat');
    });

    test('rejects five digits', () {
      expect(validatePin('12345'), 'auth.errors.pinFormat');
    });

    test('rejects non-digit characters', () {
      expect(validatePin('12ab'), 'auth.errors.pinFormat');
    });

    test('rejects an empty value with the required key', () {
      expect(validatePin(''), 'auth.errors.pinRequired');
    });
  });

  group('validateName', () {
    test('accepts a normal name', () {
      expect(validateName('Abebe Girma'), isNull);
    });

    test('rejects an empty name with the required key', () {
      expect(validateName(''), 'auth.errors.nameRequired');
    });

    test('rejects a name over 255 characters', () {
      expect(validateName('A' * 256), 'auth.errors.nameRequired');
    });

    test('accepts a name at exactly 255 characters', () {
      expect(validateName('A' * 255), isNull);
    });
  });
}
