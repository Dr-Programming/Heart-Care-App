import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/security/token_store.dart';
import 'package:libu_care/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:libu_care/features/auth/data/repositories/auth_repository_impl.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/test_database.dart';

const _validJson = <String, dynamic>{
  'token': 'header.payload.signature',
  'user': <String, dynamic>{
    'id': 'u1',
    'name': 'Abebe Girma',
    'phone': '+251911234567',
    'preferredLanguage': 'en',
    'role': 'PATIENT',
  },
};

void main() {
  group('login', () {
    test('a successful login writes both the token and the cached user', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio()..stub('/api/v1/auth/login', FakeResponse.ok(_validJson));
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: _FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        isOnline: () async => true,
      );

      final user = await repo.login(phone: '+251911234567', pin: '1234');

      expect(user.name, 'Abebe Girma');
      expect(await repo.cachedUser(), user);
    });

    test('login while offline makes no request at all', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio();
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: _FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        isOnline: () async => false,
      );

      await expectLater(
        () => repo.login(phone: '+251911234567', pin: '1234'),
        throwsA(isA<NetworkFailure>()),
      );
      expect(fake.requests, isEmpty);
    });

    test('a 401 on login throws InvalidCredentialsFailure', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio()
        ..stub('/api/v1/auth/login', FakeResponse.error(401, 'Invalid phone or PIN'));
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: _FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        isOnline: () async => true,
      );

      await expectLater(
        () => repo.login(phone: '+251911234567', pin: '0000'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
    });

    test('a 423 on login throws AccountLockedFailure with minutesRemaining', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio()
        ..stub(
          '/api/v1/auth/login',
          FakeResponse.error(423, 'Too many failed attempts. Try again in 15 minutes.'),
        );
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: _FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        isOnline: () async => true,
      );

      try {
        await repo.login(phone: '+251911234567', pin: '0000');
        fail('expected AccountLockedFailure');
      } on AccountLockedFailure catch (e) {
        expect(e.minutesRemaining, 15);
      }
    });

    test('the final-minute singular wording still parses to 1', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio()
        ..stub(
          '/api/v1/auth/login',
          FakeResponse.error(423, 'Too many failed attempts. Try again in 1 minute.'),
        );
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: _FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        isOnline: () async => true,
      );

      try {
        await repo.login(phone: '+251911234567', pin: '0000');
        fail('expected AccountLockedFailure');
      } on AccountLockedFailure catch (e) {
        expect(e.minutesRemaining, 1);
      }
    });
  });

  group('register', () {
    test('a 409 on register throws PhoneAlreadyRegisteredFailure', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio()
        ..stub(
          '/api/v1/auth/register',
          FakeResponse.error(409, 'That phone number is already registered'),
        );
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: _FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        isOnline: () async => true,
      );

      await expectLater(
        () => repo.register(
          phone: '+251911234567',
          pin: '1234',
          name: 'Abebe Girma',
          preferredLanguage: 'en',
        ),
        throwsA(isA<PhoneAlreadyRegisteredFailure>()),
      );
    });

    test('a successful register writes the session exactly as login does', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio()..stub('/api/v1/auth/register', FakeResponse.ok(_validJson));
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: _FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        isOnline: () async => true,
      );

      final user = await repo.register(
        phone: '+251911234567',
        pin: '1234',
        name: 'Abebe Girma',
        preferredLanguage: 'en',
      );

      expect(await repo.cachedUser(), user);
    });
  });

  group('getMe', () {
    test('a 401 on me throws SessionExpiredFailure, not InvalidCredentialsFailure', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio(token: 'header.payload.signature')
        ..stub('/api/v1/auth/me', FakeResponse.error(401, 'Unauthorized'));
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: _FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        isOnline: () async => true,
      );

      await expectLater(() => repo.getMe(), throwsA(isA<SessionExpiredFailure>()));
    });
  });

  group('logout', () {
    test('logout clears the token, the cached user, and the onboarding flag', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final tokens = _FakeTokenStore()..value = 'header.payload.signature';
      final local = AuthLocalDataSource(
        tokenStore: tokens,
        cachedUserDao: db.cachedUserDao,
        preferencesDao: db.preferencesDao,
      );
      await local.setNeedsOnboarding(true);
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(FakeDio().dio),
        local: local,
        isOnline: () async => true,
      );

      await repo.logout();

      expect(await tokens.read(), isNull);
      expect(await repo.cachedUser(), isNull);
      expect(await local.needsOnboarding(), isFalse);
    });
  });
}







class _FakeTokenStore extends TokenStore {
  _FakeTokenStore() : super(const FlutterSecureStorage());

  String? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String token) async => value = token;
}
