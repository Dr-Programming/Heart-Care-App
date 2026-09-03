import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/domain/validators.dart';

void main() {
  group('phone', () {
    test('accepts +251 followed by exactly 9 digits', () {
      expect(AuthValidators.phone('+251911234567'), isNull);
    });
    test('rejects an empty value', () {
      expect(AuthValidators.phone(''), 'errors.phoneRequired');
      expect(AuthValidators.phone(null), 'errors.phoneRequired');
    });
    test('rejects a local 0-prefixed number', () {
      expect(AuthValidators.phone('0911234567'), 'errors.phoneFormat');
    });
    test('rejects too few and too many digits', () {
      expect(AuthValidators.phone('+25191123456'), 'errors.phoneFormat');
      expect(AuthValidators.phone('+2519112345678'), 'errors.phoneFormat');
    });
    test('rejects a non-Ethiopian country code', () {
      expect(AuthValidators.phone('+254911234567'), 'errors.phoneFormat');
    });
    test('tolerates surrounding whitespace', () {
      expect(AuthValidators.phone('  +251911234567  '), isNull);
    });
  });

  group('pin', () {
    test('accepts exactly four digits', () {
      expect(AuthValidators.pin('1234'), isNull);
      expect(AuthValidators.pin('0000'), isNull);
    });
    test('rejects empty, short, long and non-numeric PINs', () {
      expect(AuthValidators.pin(''), 'errors.pinRequired');
      expect(AuthValidators.pin('123'), 'errors.pinFormat');
      expect(AuthValidators.pin('12345'), 'errors.pinFormat');
      expect(AuthValidators.pin('12a4'), 'errors.pinFormat');
    });
  });

  group('confirmPin', () {
    test('passes when both PINs match', () {
      expect(AuthValidators.confirmPin('1234', '1234'), isNull);
    });
    test('fails when they differ', () {
      expect(AuthValidators.confirmPin('1234', '4321'), 'errors.pinMismatch');
    });
    test('reports the format problem first when the confirm field is itself bad', () {
      expect(AuthValidators.confirmPin('1234', '12'), 'errors.pinFormat');
    });
  });

  group('name', () {
    test('accepts a normal name', () {
      expect(AuthValidators.name('Abebe Bekele'), isNull);
    });
    test('rejects blank and whitespace-only names', () {
      expect(AuthValidators.name(''), 'errors.nameRequired');
      expect(AuthValidators.name('   '), 'errors.nameRequired');
    });
    test('rejects a name over the server limit of 255', () {
      expect(AuthValidators.name('a' * 256), 'errors.nameRequired');
    });
  });
}
