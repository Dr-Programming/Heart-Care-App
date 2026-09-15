import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';

void main() {
  test('two AuthUsers with the same fields are equal', () {
    const a = AuthUser(
      id: 'u1',
      name: 'Abebe Girma',
      phone: '+251911234567',
      preferredLanguage: 'en',
      role: 'PATIENT',
    );
    const b = AuthUser(
      id: 'u1',
      name: 'Abebe Girma',
      phone: '+251911234567',
      preferredLanguage: 'en',
      role: 'PATIENT',
    );
    expect(a, equals(b));
  });

  test('a different id makes two AuthUsers unequal', () {
    const a = AuthUser(
      id: 'u1',
      name: 'Abebe Girma',
      phone: '+251911234567',
      preferredLanguage: 'en',
      role: 'PATIENT',
    );
    const b = AuthUser(
      id: 'u2',
      name: 'Abebe Girma',
      phone: '+251911234567',
      preferredLanguage: 'en',
      role: 'PATIENT',
    );
    expect(a, isNot(equals(b)));
  });
}
