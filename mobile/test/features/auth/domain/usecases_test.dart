import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/domain/usecases/get_me.dart';
import 'package:libu_care/features/auth/domain/usecases/login.dart';
import 'package:libu_care/features/auth/domain/usecases/logout.dart';
import 'package:libu_care/features/auth/domain/usecases/register.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const AuthUser _user = AuthUser(
  id: '3f2a9c1e', name: 'Abebe Bekele', phone: '+251911234567',
  preferredLanguage: 'am', role: 'PATIENT',
);

void main() {
  setUpAll(() {
    registerFallbackValue(AppLanguage.en);
  });

  late MockAuthRepository repo;
  setUp(() => repo = MockAuthRepository());

  test('Login delegates to the repository and returns the user', () async {
    when(() => repo.login(phone: '+251911234567', pin: '1234'))
        .thenAnswer((_) async => _user);
    final result = await Login(repo)(phone: '+251911234567', pin: '1234');
    expect(result, _user);
    verify(() => repo.login(phone: '+251911234567', pin: '1234')).called(1);
  });

  test('Login propagates a lockout failure untouched', () async {
    when(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
        .thenThrow(const AccountLockedFailure('Try again in 15 minutes.',
            minutesRemaining: 15));
    expect(
      () => Login(repo)(phone: '+251911234567', pin: '9999'),
      throwsA(isA<AccountLockedFailure>()),
    );
  });

  test('Register passes the language through', () async {
    when(() => repo.register(
          phone: any(named: 'phone'), pin: any(named: 'pin'),
          name: any(named: 'name'), language: any(named: 'language'),
        )).thenAnswer((_) async => _user);
    await Register(repo)(
      phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
      language: AppLanguage.am,
    );
    verify(() => repo.register(
          phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
          language: AppLanguage.am,
        )).called(1);
  });

  test('GetMe returns the current user', () async {
    when(() => repo.getMe()).thenAnswer((_) async => _user);
    expect(await GetMe(repo)(), _user);
  });

  test('Logout clears the session', () async {
    when(() => repo.logout()).thenAnswer((_) async {});
    await Logout(repo)();
    verify(() => repo.logout()).called(1);
  });
}
