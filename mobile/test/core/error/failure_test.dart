import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';

void main() {
  group('parseLockoutMinutes', () {
    test('reads the plural form', () {
      expect(
        parseLockoutMinutes(
          'Too many failed attempts. Try again in 15 minutes.',
        ),
        15,
      );
    });

    test('reads the singular form on the final minute', () {
      expect(
        parseLockoutMinutes('Too many failed attempts. Try again in 1 minute.'),
        1,
      );
    });

    test('returns null when the message carries no duration', () {
      expect(parseLockoutMinutes('Account locked.'), isNull);
    });
  });

  group('Failure', () {
    test('AccountLockedFailure carries the remaining minutes', () {
      const f = AccountLockedFailure(
        'Try again in 4 minutes.',
        minutesRemaining: 4,
      );
      expect(f.minutesRemaining, 4);
      expect(f, isA<Failure>());
    });
  });
}
