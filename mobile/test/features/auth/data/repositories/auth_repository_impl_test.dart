import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/security/token_store.dart';
import 'package:libu_care/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:libu_care/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/fake_secure_storage.dart';
import '../../../../helpers/test_database.dart';

const FlutterSecureStorage _storage = FlutterSecureStorage();
const TokenStore _tokenStore = TokenStore(_storage);

const Map<String, dynamic> _userJson = <String, dynamic>{
  'id': 'u1',
  'name': 'Abebe Girma',
  'phone': '+251911234567',
  'preferredLanguage': 'en',
  'role': 'PATIENT',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(setUpFakeSecureStorage);

  late AppDatabase db;
  late FakeDio fake;
  bool online = true;

  AuthRepository makeRepository() {
    fake = FakeDio();
    online = true;
    db = testDatabase();
    return AuthRepositoryImpl(
      remote: AuthRemoteDataSource(fake.dio),
      local: AuthLocalDataSource(
        tokenStore: _tokenStore,
        cachedUserDao: db.cachedUserDao,
      ),
      isOnline: () async => online,
    );
  }

  tearDown(() => db.close());

  group('login', () {
    test('fails fast when offline, without making a request', () async {
      final AuthRepository repo = makeRepository();
      online = false;

      await expectLater(
        () => repo.login(phone: '+251911234567', pin: '1234'),
        throwsA(isA<NetworkFailure>()),
      );
      expect(fake.requests, isEmpty);
    });

    test('saves the session and returns the user on success', () async {
      final AuthRepository repo = makeRepository();
      fake.stub(
        '/api/v1/auth/login',
        FakeResponse.ok(<String, dynamic>{
          'token': 'jwt-token',
          'user': _userJson,
        }),
      );

      final AuthUser user = await repo.login(
        phone: '+251911234567',
        pin: '1234',
      );

      expect(user.id, 'u1');
      expect(
        await repo.hasValidSession(),
        isFalse,
      ); // no exp claim -> fail closed
      final AuthUser? cached = await repo.cachedUser();
      expect(cached?.id, 'u1');
    });

    test(
      'maps a 401 to InvalidCredentialsFailure and saves no session',
      () async {
        final AuthRepository repo = makeRepository();
        fake.stub(
          '/api/v1/auth/login',
          FakeResponse.error(401, 'Invalid phone or PIN'),
        );

        await expectLater(
          () => repo.login(phone: '+251911234567', pin: '0000'),
          throwsA(isA<InvalidCredentialsFailure>()),
        );
        expect(await repo.cachedUser(), isNull);
      },
    );

    test('maps a 423 to AccountLockedFailure with parsed minutes', () async {
      final AuthRepository repo = makeRepository();
      fake.stub(
        '/api/v1/auth/login',
        FakeResponse.error(
          423,
          'Too many failed attempts. Try again in 12 minutes.',
        ),
      );

      try {
        await repo.login(phone: '+251911234567', pin: '0000');
        fail('expected AccountLockedFailure');
      } on AccountLockedFailure catch (e) {
        expect(e.minutesRemaining, 12);
      }
    });
  });

  group('register', () {
    test('fails fast when offline, without making a request', () async {
      final AuthRepository repo = makeRepository();
      online = false;

      await expectLater(
        () => repo.register(
          phone: '+251911234567',
          pin: '1234',
          name: 'Abebe Girma',
          language: AppLanguage.en,
        ),
        throwsA(isA<NetworkFailure>()),
      );
      expect(fake.requests, isEmpty);
    });

    test('sends the language code and auto-logs-in on success', () async {
      final AuthRepository repo = makeRepository();
      fake.stub(
        '/api/v1/auth/register',
        FakeResponse.ok(<String, dynamic>{
          'token': 'jwt-token',
          'user': _userJson,
        }),
      );

      final AuthUser user = await repo.register(
        phone: '+251911234567',
        pin: '1234',
        name: 'Abebe Girma',
        language: AppLanguage.en,
      );

      expect(user.id, 'u1');
      expect(fake.requests.single.json['preferredLanguage'], 'en');
      expect(await repo.cachedUser(), isNotNull);
    });

    test('maps a 409 to PhoneAlreadyRegisteredFailure', () async {
      final AuthRepository repo = makeRepository();
      fake.stub(
        '/api/v1/auth/register',
        FakeResponse.error(409, 'Phone already registered'),
      );

      await expectLater(
        () => repo.register(
          phone: '+251911234567',
          pin: '1234',
          name: 'Abebe Girma',
          language: AppLanguage.en,
        ),
        throwsA(isA<PhoneAlreadyRegisteredFailure>()),
      );
    });
  });

  group('getMe', () {
    test('refreshes the cache and returns the user on success', () async {
      final AuthRepository repo = makeRepository();
      fake.stub('/api/v1/auth/me', FakeResponse.ok(_userJson));

      final AuthUser user = await repo.getMe();

      expect(user.id, 'u1');
      expect(await repo.cachedUser(), isNotNull);
    });

    test(
      'maps a 401 to SessionExpiredFailure, not InvalidCredentialsFailure',
      () async {
        final AuthRepository repo = makeRepository();
        fake.stub('/api/v1/auth/me', FakeResponse.error(401, 'Unauthorized'));

        await expectLater(
          () => repo.getMe(),
          throwsA(isA<SessionExpiredFailure>()),
        );
      },
    );
  });

  group('cachedUser / hasValidSession / logout', () {
    test(
      'cachedUser is null and hasValidSession is false with no session',
      () async {
        final AuthRepository repo = makeRepository();

        expect(await repo.cachedUser(), isNull);
        expect(await repo.hasValidSession(), isFalse);
      },
    );

    test('logout clears the token and the cached user', () async {
      final AuthRepository repo = makeRepository();
      fake.stub(
        '/api/v1/auth/login',
        FakeResponse.ok(<String, dynamic>{
          'token': 'jwt-token',
          'user': _userJson,
        }),
      );
      await repo.login(phone: '+251911234567', pin: '1234');

      await repo.logout();

      expect(await repo.cachedUser(), isNull);
      expect(await _tokenStore.read(), isNull);
    });
  });
}
