import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/domain/usecases/get_me.dart';
import 'package:libu_care/features/auth/domain/usecases/login.dart';
import 'package:libu_care/features/auth/domain/usecases/logout.dart';
import 'package:libu_care/features/auth/domain/usecases/register.dart';

const _user = AuthUser(
  id: 'u1',
  name: 'Abebe Girma',
  phone: '+251911234567',
  preferredLanguage: 'en',
  role: 'PATIENT',
);

class _FakeAuthRepository implements AuthRepository {
  bool loggedOut = false;
  ({String phone, String pin})? loginArgs;
  ({String phone, String pin, String name, String preferredLanguage})? registerArgs;

  @override
  Future<AuthUser> login({required String phone, required String pin}) async {
    loginArgs = (phone: phone, pin: pin);
    return _user;
  }

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  }) async {
    registerArgs = (phone: phone, pin: pin, name: name, preferredLanguage: preferredLanguage);
    return _user;
  }

  @override
  Future<AuthUser> getMe() async => _user;

  @override
  Future<bool> refreshSession() async => true;

  @override
  Future<void> logout() async => loggedOut = true;

  @override
  Future<AuthUser?> cachedUser() async => _user;

  @override
  Future<bool> isSignedIn() async => true;

  @override
  Future<bool> needsOnboarding() async => false;
}

void main() {
  test('Login forwards phone and pin to the repository', () async {
    final repo = _FakeAuthRepository();
    final result = await Login(repo)(phone: '+251911234567', pin: '1234');
    expect(result, _user);
    expect(repo.loginArgs, (phone: '+251911234567', pin: '1234'));
  });

  test('Register forwards every field to the repository', () async {
    final repo = _FakeAuthRepository();
    final result = await Register(repo)(
      phone: '+251911234567',
      pin: '1234',
      name: 'Abebe Girma',
      preferredLanguage: 'en',
    );
    expect(result, _user);
    expect(
      repo.registerArgs,
      (phone: '+251911234567', pin: '1234', name: 'Abebe Girma', preferredLanguage: 'en'),
    );
  });

  test('GetMe forwards to the repository', () async {
    final repo = _FakeAuthRepository();
    expect(await GetMe(repo)(), _user);
  });

  test('Logout forwards to the repository', () async {
    final repo = _FakeAuthRepository();
    await Logout(repo)();
    expect(repo.loggedOut, isTrue);
  });
}
