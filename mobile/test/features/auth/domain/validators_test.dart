import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/domain/validators.dart';

void main() {
  group('AuthValidators.phone', () {
    test('rejects an empty value', () {
      expect(AuthValidators.phone(''), 'auth.errors.phoneRequired');
    });

    test('rejects a value that is only whitespace', () {
      expect(AuthValidators.phone('   '), 'auth.errors.phoneRequired');
    });

    test('rejects a local number missing the +251 prefix', () {
      expect(AuthValidators.phone('0911234567'), 'auth.errors.phoneFormat');
    });

    test('rejects a phone with too few digits after +251', () {
      expect(AuthValidators.phone('+25191123456'), 'auth.errors.phoneFormat');
    });

    test('rejects a phone with too many digits after +251', () {
      expect(AuthValidators.phone('+2519112345678'), 'auth.errors.phoneFormat');
    });

    test('rejects the wrong country code', () {
      expect(AuthValidators.phone('+1911234567'), 'auth.errors.phoneFormat');
    });

    test('accepts a well-formed +251 phone number', () {
      expect(AuthValidators.phone('+251911234567'), isNull);
    });

    test('accepts a well-formed phone with surrounding whitespace', () {
      expect(AuthValidators.phone('  +251911234567  '), isNull);
    });
  });

  group('AuthValidators.pin', () {
    test('rejects an empty value', () {
      expect(AuthValidators.pin(''), 'auth.errors.pinRequired');
    });

    test('rejects fewer than 4 digits', () {
      expect(AuthValidators.pin('123'), 'auth.errors.pinFormat');
    });

    test('rejects more than 4 digits', () {
      expect(AuthValidators.pin('12345'), 'auth.errors.pinFormat');
    });

    test('rejects non-digit characters', () {
      expect(AuthValidators.pin('12a4'), 'auth.errors.pinFormat');
    });

    test('accepts exactly 4 digits', () {
      expect(AuthValidators.pin('1234'), isNull);
    });
  });

  group('AuthValidators.confirmPin', () {
    test('surfaces a format error on the confirm field first', () {
      expect(AuthValidators.confirmPin('1234', '12'), 'auth.errors.pinFormat');
    });

    test('surfaces a required error when the confirm field is empty', () {
      expect(AuthValidators.confirmPin('1234', ''), 'auth.errors.pinRequired');
    });

    test('rejects a well-formed confirm value that does not match', () {
      expect(
        AuthValidators.confirmPin('1234', '5678'),
        'auth.errors.pinMismatch',
      );
    });

    test('accepts a confirm value that matches the pin', () {
      expect(AuthValidators.confirmPin('1234', '1234'), isNull);
    });
  });

  group('AuthValidators.name', () {
    test('rejects an empty value', () {
      expect(AuthValidators.name(''), 'auth.errors.nameRequired');
    });

    test('rejects a value that is only whitespace', () {
      expect(AuthValidators.name('   '), 'auth.errors.nameRequired');
    });

    test('rejects a name longer than 255 characters', () {
      expect(AuthValidators.name('a' * 256), 'auth.errors.nameRequired');
    });

    test('accepts a name at exactly 255 characters', () {
      expect(AuthValidators.name('a' * 255), isNull);
    });

    test('accepts an ordinary name', () {
      expect(AuthValidators.name('Abebe Girma'), isNull);
    });
  });
}
