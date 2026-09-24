import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/security/token_store.dart';
import 'package:libu_care/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:libu_care/features/auth/data/datasources/offline_credential_store.dart';
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
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
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
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
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
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
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
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
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
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
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
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
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
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
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
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
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
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
        isOnline: () async => true,
      );

      await repo.logout();

      expect(await tokens.read(), isNull);
      expect(await repo.cachedUser(), isNull);
      expect(await local.needsOnboarding(), isFalse);
    });
  });

  group('offline sign-in', () {
    late _MemoryCredentialStore remembered;
    late _FakeTokenStore tokens;
    late OfflineSession session;
    late FakeDio fake;
    late bool online;
    late AuthRepositoryImpl repo;

    setUp(() {
      final db = testDatabase();
      addTearDown(db.close);
      remembered = _MemoryCredentialStore();
      tokens = _FakeTokenStore();
      session = OfflineSession();
      fake = FakeDio()
        ..stub('/api/v1/auth/login', FakeResponse.ok(_validJson));
      online = true;
      repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: tokens,
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        offline: remembered,
        session: session,
        isOnline: () async => online,
      );
    });

    /// A patient who signed in on this phone once, then signed out.
    Future<void> signedInBefore() async {
      await repo.login(phone: '+251911234567', pin: '1234');
      await repo.logout();
      fake.requests.clear();
    }

    test('a patient who signed in here before can sign in with no network',
        () async {
      await signedInBefore();
      online = false;

      final user = await repo.login(phone: '+251911234567', pin: '1234');

      expect(user.name, 'Abebe Girma');
      expect(fake.requests, isEmpty);
      expect(await repo.isSignedIn(), isTrue);
      expect(await repo.cachedUser(), user);
    });

    test('a wrong PIN offline is rejected', () async {
      await signedInBefore();
      online = false;

      await expectLater(
        () => repo.login(phone: '+251911234567', pin: '9999'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
      expect(await repo.isSignedIn(), isFalse);
    });

    test('five wrong PINs offline lock the account for 15 minutes', () async {
      await signedInBefore();
      online = false;

      for (int i = 0; i < 4; i++) {
        await expectLater(
          () => repo.login(phone: '+251911234567', pin: '9999'),
          throwsA(isA<InvalidCredentialsFailure>()),
        );
      }
      try {
        await repo.login(phone: '+251911234567', pin: '9999');
        fail('expected AccountLockedFailure');
      } on AccountLockedFailure catch (e) {
        expect(e.minutesRemaining, 15);
      }
      // Even the right PIN waits out the lock.
      await expectLater(
        () => repo.login(phone: '+251911234567', pin: '1234'),
        throwsA(isA<AccountLockedFailure>()),
      );
    });

    test('a server that cannot be reached falls back to the remembered account',
        () async {
      await signedInBefore();
      fake.stub('/api/v1/auth/login', FakeResponse.offline());

      final user = await repo.login(phone: '+251911234567', pin: '1234');

      expect(user.id, 'u1');
      expect(await repo.isSignedIn(), isTrue);
    });

    test('a dead ngrok tunnel counts as unreachable, not as a reply', () async {
      await signedInBefore();
      fake.stub(
        '/api/v1/auth/login',
        const FakeResponse(
          statusCode: 404,
          body: <String, dynamic>{},
          headers: <String, String>{'ngrok-error-code': 'ERR_NGROK_3200'},
        ),
      );

      final user = await repo.login(phone: '+251911234567', pin: '1234');

      expect(user.id, 'u1');
    });

    test('a server that answers 401 wins over a matching remembered PIN',
        () async {
      await signedInBefore();
      fake.stub(
        '/api/v1/auth/login',
        FakeResponse.error(401, 'Invalid phone or PIN'),
      );

      await expectLater(
        () => repo.login(phone: '+251911234567', pin: '1234'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
    });

    test('a phone that never signed in here still needs the server', () async {
      online = false;

      await expectLater(
        () => repo.login(phone: '+251911234567', pin: '1234'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('logout keeps the remembered account', () async {
      await signedInBefore();
      expect((await remembered.rememberedUser())?.id, 'u1');
    });

    test('refreshSession trades an offline sign-in for a server token',
        () async {
      await signedInBefore();
      online = false;
      await repo.login(phone: '+251911234567', pin: '1234');
      expect(session.isActive, isTrue);
      expect(await tokens.read(), isNull);

      online = true;
      expect(await repo.refreshSession(), isTrue);

      expect(session.isActive, isFalse);
      expect(await tokens.read(), 'header.payload.signature');
      expect(fake.requests.single.path, '/api/v1/auth/login');
    });

    test('refreshSession is a no-op without an offline session', () async {
      expect(await repo.refreshSession(), isTrue);
      expect(fake.requests, isEmpty);
    });

    test('refreshSession keeps the offline session while the server is down',
        () async {
      await signedInBefore();
      online = false;
      await repo.login(phone: '+251911234567', pin: '1234');
      online = true;
      fake.stub('/api/v1/auth/login', FakeResponse.offline());

      expect(await repo.refreshSession(), isTrue);
      expect(session.isActive, isTrue);
    });

    test('a PIN the server no longer accepts ends the session and is forgotten',
        () async {
      await signedInBefore();
      online = false;
      await repo.login(phone: '+251911234567', pin: '1234');
      online = true;
      fake.stub(
        '/api/v1/auth/login',
        FakeResponse.error(401, 'Invalid phone or PIN'),
      );

      expect(await repo.refreshSession(), isFalse);
      expect(await repo.isSignedIn(), isFalse);
      expect(await repo.cachedUser(), isNull);
      expect(await remembered.rememberedUser(), isNull);
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

class _MemoryCredentialStore extends OfflineCredentialStore {
  _MemoryCredentialStore() : super(const FlutterSecureStorage());

  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> readRaw(String key) async => _values[key];

  @override
  Future<void> writeRaw(String key, String value) async => _values[key] = value;

  @override
  Future<void> deleteRaw(String key) async => _values.remove(key);
}
