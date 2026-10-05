import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:libu_care/features/auth/data/datasources/offline_credential_store.dart';
import 'package:libu_care/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:libu_care/features/auth/domain/repositories/pin_repository.dart';
import 'package:libu_care/features/auth/domain/security_question.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';

import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/auth_fakes.dart';

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
    test(
      'a successful login writes both the token and the cached user',
      () async {
        final db = testDatabase();
        addTearDown(db.close);
        final fake = FakeDio()
          ..stub('/api/v1/auth/login', FakeResponse.ok(_validJson));
        final repo = AuthRepositoryImpl(
          remote: AuthRemoteDataSource(fake.dio),
          local: AuthLocalDataSource(
            tokenStore: FakeTokenStore(),
            cachedUserDao: db.cachedUserDao,
            preferencesDao: db.preferencesDao,
          ),
          offline: _MemoryCredentialStore(),
          session: OfflineSession(),
          pending: MemoryPendingPinChangeStore(),
          isOnline: () async => true,
        );

        final user = await repo.login(phone: '+251911234567', pin: '1234');

        expect(user.name, 'Abebe Girma');
        expect(await repo.cachedUser(), user);
      },
    );

    test('login while offline makes no request at all', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio();
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
        pending: MemoryPendingPinChangeStore(),
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
        ..stub(
          '/api/v1/auth/login',
          FakeResponse.error(401, 'Invalid phone or PIN'),
        );
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
        pending: MemoryPendingPinChangeStore(),
        isOnline: () async => true,
      );

      await expectLater(
        () => repo.login(phone: '+251911234567', pin: '0000'),
        throwsA(isA<InvalidCredentialsFailure>()),
      );
    });

    test(
      'a 423 on login throws AccountLockedFailure with minutesRemaining',
      () async {
        final db = testDatabase();
        addTearDown(db.close);
        final fake = FakeDio()
          ..stub(
            '/api/v1/auth/login',
            FakeResponse.error(
              423,
              'Too many failed attempts. Try again in 15 minutes.',
            ),
          );
        final repo = AuthRepositoryImpl(
          remote: AuthRemoteDataSource(fake.dio),
          local: AuthLocalDataSource(
            tokenStore: FakeTokenStore(),
            cachedUserDao: db.cachedUserDao,
            preferencesDao: db.preferencesDao,
          ),
          offline: _MemoryCredentialStore(),
          session: OfflineSession(),
          pending: MemoryPendingPinChangeStore(),
          isOnline: () async => true,
        );

        try {
          await repo.login(phone: '+251911234567', pin: '0000');
          fail('expected AccountLockedFailure');
        } on AccountLockedFailure catch (e) {
          expect(e.minutesRemaining, 15);
        }
      },
    );

    test('the final-minute singular wording still parses to 1', () async {
      final db = testDatabase();
      addTearDown(db.close);
      final fake = FakeDio()
        ..stub(
          '/api/v1/auth/login',
          FakeResponse.error(
            423,
            'Too many failed attempts. Try again in 1 minute.',
          ),
        );
      final repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
        pending: MemoryPendingPinChangeStore(),
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
          tokenStore: FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        offline: _MemoryCredentialStore(),
        session: OfflineSession(),
        pending: MemoryPendingPinChangeStore(),
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

    test(
      'a successful register writes the session exactly as login does',
      () async {
        final db = testDatabase();
        addTearDown(db.close);
        final fake = FakeDio()
          ..stub('/api/v1/auth/register', FakeResponse.ok(_validJson));
        final repo = AuthRepositoryImpl(
          remote: AuthRemoteDataSource(fake.dio),
          local: AuthLocalDataSource(
            tokenStore: FakeTokenStore(),
            cachedUserDao: db.cachedUserDao,
            preferencesDao: db.preferencesDao,
          ),
          offline: _MemoryCredentialStore(),
          session: OfflineSession(),
          pending: MemoryPendingPinChangeStore(),
          isOnline: () async => true,
        );

        final user = await repo.register(
          phone: '+251911234567',
          pin: '1234',
          name: 'Abebe Girma',
          preferredLanguage: 'en',
        );

        expect(await repo.cachedUser(), user);
        // A new account is sent through the setup wizard once.
        expect(await repo.needsOnboarding(), isTrue);
      },
    );
  });

  group('getMe', () {
    test(
      'a 401 on me throws SessionExpiredFailure, not InvalidCredentialsFailure',
      () async {
        final db = testDatabase();
        addTearDown(db.close);
        final fake = FakeDio(token: 'header.payload.signature')
          ..stub('/api/v1/auth/me', FakeResponse.error(401, 'Unauthorized'));
        final repo = AuthRepositoryImpl(
          remote: AuthRemoteDataSource(fake.dio),
          local: AuthLocalDataSource(
            tokenStore: FakeTokenStore(),
            cachedUserDao: db.cachedUserDao,
            preferencesDao: db.preferencesDao,
          ),
          offline: _MemoryCredentialStore(),
          session: OfflineSession(),
          pending: MemoryPendingPinChangeStore(),
          isOnline: () async => true,
        );

        await expectLater(
          () => repo.getMe(),
          throwsA(isA<SessionExpiredFailure>()),
        );
      },
    );
  });

  group('logout', () {
    test(
      'logout clears the token, the cached user, and the onboarding flag',
      () async {
        final db = testDatabase();
        addTearDown(db.close);
        final tokens = FakeTokenStore()..value = 'header.payload.signature';
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
          pending: MemoryPendingPinChangeStore(),
          isOnline: () async => true,
        );

        await repo.logout();

        expect(await tokens.read(), isNull);
        expect(await repo.cachedUser(), isNull);
        expect(await local.needsOnboarding(), isFalse);
      },
    );
  });

  group('refresh tokens', () {
    late FakeTokenStore tokens;
    late FakeDio fake;
    late OfflineSession session;
    late bool online;
    late AuthRepositoryImpl repo;

    setUp(() {
      final db = testDatabase();
      addTearDown(db.close);
      tokens = FakeTokenStore();
      session = OfflineSession();
      online = true;
      fake = FakeDio()
        ..stub(
          '/api/v1/auth/login',
          FakeResponse.ok(<String, dynamic>{
            ..._validJson,
            'refreshToken': 'refresh-1',
            'refreshTokenExpiresAt': '2099-01-01T00:00:00Z',
          }),
        )
        ..stub('/api/v1/auth/logout', FakeResponse.ok(null));
      repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: tokens,
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        offline: _MemoryCredentialStore(),
        session: session,
        pending: MemoryPendingPinChangeStore(),
        isOnline: () async => online,
      );
    });

    test('signing in stores the refresh token', () async {
      await repo.login(phone: '+251911234567', pin: '1234');

      expect(await tokens.readRefresh(), 'refresh-1');
    });

    test('signing out revokes the refresh token on the server', () async {
      await repo.login(phone: '+251911234567', pin: '1234');

      await repo.logout();

      final RecordedRequest call = fake.requests.last;
      expect(call.path, '/api/v1/auth/logout');
      expect(call.json['refreshToken'], 'refresh-1');
      expect(await tokens.readRefresh(), isNull);
    });

    test('signing out offline still ends the session on this phone', () async {
      await repo.login(phone: '+251911234567', pin: '1234');
      online = false;
      fake.requests.clear();

      await repo.logout();

      expect(fake.requests, isEmpty);
      expect(await tokens.read(), isNull);
      expect(await repo.isSignedIn(), isFalse);
    });

    test('an expired server session signs the patient out', () async {
      await repo.login(phone: '+251911234567', pin: '1234');
      await tokens.clear();

      await repo.expireSession();

      expect(await repo.cachedUser(), isNull);
      expect(await repo.isSignedIn(), isFalse);
    });

    test('an expired server session keeps an offline sign-in', () async {
      session.begin(phone: '+251911234567', pin: '1234');

      await repo.expireSession();

      expect(await repo.isSignedIn(), isTrue);
    });
  });

  group('a different patient on the same phone', () {
    late FakeDio fake;
    late AuthLocalDataSource local;
    late _MemoryCredentialStore remembered;
    late int switches;
    late AuthRepositoryImpl repo;

    Map<String, dynamic> loginAs(String id) => <String, dynamic>{
      ..._validJson,
      'user': <String, dynamic>{
        ...(_validJson['user'] as Map<String, dynamic>),
        'id': id,
      },
    };

    setUp(() {
      final db = testDatabase();
      addTearDown(db.close);
      fake = FakeDio();
      switches = 0;
      remembered = _MemoryCredentialStore();
      local = AuthLocalDataSource(
        tokenStore: FakeTokenStore(),
        cachedUserDao: db.cachedUserDao,
        preferencesDao: db.preferencesDao,
      );
      repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: local,
        offline: remembered,
        session: OfflineSession(),
        pending: MemoryPendingPinChangeStore(),
        isOnline: () async => true,
        onPatientSwitch: () async => switches++,
      );
    });

    test('the first patient on a phone keeps what is there', () async {
      fake.stub('/api/v1/auth/login', FakeResponse.ok(loginAs('u1')));

      await repo.login(phone: '+251911234567', pin: '1234');

      expect(switches, 0);
    });

    test('the same patient signing in again keeps their data', () async {
      fake.stub('/api/v1/auth/login', FakeResponse.ok(loginAs('u1')));
      await repo.login(phone: '+251911234567', pin: '1234');
      await repo.logout();

      await repo.login(phone: '+251911234567', pin: '1234');

      expect(switches, 0);
    });

    test(
      'another patient signing in clears the previous patient’s data',
      () async {
        fake.stub('/api/v1/auth/login', FakeResponse.ok(loginAs('u1')));
        await repo.login(phone: '+251911234567', pin: '1234');
        await repo.logout();

        fake.stub('/api/v1/auth/login', FakeResponse.ok(loginAs('u2')));
        await repo.login(phone: '+251911234567', pin: '1234');

        expect(switches, 1);
      },
    );

    test(
      'a phone used before this check existed is still recognised',
      () async {
        await remembered.remember(
          user: const AuthUser(
            id: 'u1',
            name: 'A',
            phone: '+251911000000',
            preferredLanguage: 'en',
            role: 'PATIENT',
          ),
          pin: '1111',
        );
        fake.stub('/api/v1/auth/login', FakeResponse.ok(loginAs('u2')));

        await repo.login(phone: '+251911234567', pin: '1234');

        expect(switches, 1);
      },
    );
  });

  group('switching patients on one phone', () {
    late FakeDio fake;
    late _MemoryCredentialStore remembered;
    late int switches;
    late int unsent;
    late bool online;
    late AuthRepositoryImpl repo;

    const List<SecurityAnswer> answers = <SecurityAnswer>[
      SecurityAnswer(SecurityQuestion.firstSchool, 'Bole Primary'),
      SecurityAnswer(SecurityQuestion.childhoodFriend, 'Dawit'),
      SecurityAnswer(SecurityQuestion.favoriteTeacher, 'Ato Kebede'),
    ];

    Map<String, dynamic> account(String id, String phone) => <String, dynamic>{
      ..._validJson,
      'user': <String, dynamic>{
        ...(_validJson['user'] as Map<String, dynamic>),
        'id': id,
        'phone': phone,
      },
    };

    setUp(() async {
      final db = testDatabase();
      addTearDown(db.close);
      fake = FakeDio();
      switches = 0;
      unsent = 0;
      online = true;
      remembered = _MemoryCredentialStore();
      repo = AuthRepositoryImpl(
        remote: AuthRemoteDataSource(fake.dio),
        local: AuthLocalDataSource(
          tokenStore: FakeTokenStore(),
          cachedUserDao: db.cachedUserDao,
          preferencesDao: db.preferencesDao,
        ),
        offline: remembered,
        session: OfflineSession(),
        pending: MemoryPendingPinChangeStore(),
        isOnline: () async => online,
        onPatientSwitch: () async => switches++,
        unsentRecordCount: () async => unsent,
      );

      // Hana uses the phone, then Abebe, both online. Abebe's records are
      // the ones on the phone now.
      fake.stub(
        '/api/v1/auth/login',
        FakeResponse.ok(account('u2', '+251922222222')),
      );
      await repo.login(phone: '+251922222222', pin: '9999');
      await repo.logout();
      fake.stub(
        '/api/v1/auth/login',
        FakeResponse.ok(account('u1', '+251911234567')),
      );
      await repo.login(phone: '+251911234567', pin: '1234');
      await remembered.rememberAnswers(answers);
      await repo.logout();
      switches = 0;
    });

    test('offline, a different patient is asked to connect first', () async {
      online = false;

      await expectLater(
        () => repo.login(phone: '+251922222222', pin: '9999'),
        throwsA(
          isA<PatientSwitchFailure>().having(
            (PatientSwitchFailure f) => f.needsConnection,
            'needsConnection',
            isTrue,
          ),
        ),
      );
      expect(switches, 0);
      expect(await repo.cachedUser(), isNull);
    });

    test(
      'offline, the patient whose records are here signs in as usual',
      () async {
        online = false;

        final user = await repo.login(phone: '+251911234567', pin: '1234');

        expect(user.id, 'u1');
        expect(switches, 0);
      },
    );

    test('online, a different patient is refused while records are unsent, then allowed once they are gone', () async {
      unsent = 3;
      fake.stub(
        '/api/v1/auth/login',
        FakeResponse.ok(account('u2', '+251922222222')),
      );

      await expectLater(
        () => repo.login(phone: '+251922222222', pin: '9999'),
        throwsA(
          isA<PatientSwitchFailure>()
              .having(
                (PatientSwitchFailure f) => f.unsentRecords,
                'unsentRecords',
                3,
              )
              .having(
                (PatientSwitchFailure f) => f.needsConnection,
                'needsConnection',
                isFalse,
              ),
        ),
      );
      expect(switches, 0);

      // Sent, or deleted by the patient's choice.
      unsent = 0;
      final user = await repo.login(phone: '+251922222222', pin: '9999');

      expect(user.id, 'u2');
      expect(switches, 1);
    });

    test(
      'a new account on a phone with unsent records is refused too',
      () async {
        unsent = 1;
        fake.stub(
          '/api/v1/auth/register',
          FakeResponse.ok(account('u3', '+251933333333')),
        );

        await expectLater(
          () => repo.register(
            phone: '+251933333333',
            pin: '5555',
            name: 'New Patient',
            preferredLanguage: 'en',
          ),
          throwsA(isA<PatientSwitchFailure>()),
        );
      },
    );

    test('once back online, an offline PIN reset becomes a server session and says so once', () async {
      online = false;
      await repo.resetPin(
        phone: '+251911234567',
        answers: answers,
        newPin: '4321',
      );
      online = true;
      fake.stub(
        '/api/v1/auth/reset-pin',
        FakeResponse.ok(account('u1', '+251911234567')),
      );

      expect(await repo.refreshSession(), isTrue);

      expect(repo.takeServerSessionStarted(), isTrue);
      expect(repo.takeServerSessionStarted(), isFalse);
    });

    group("with the patient's own question on this phone", () {
      setUp(() async {
        fake.stub(
          '/api/v1/auth/login',
          FakeResponse.ok(account('u1', '+251911234567')),
        );
        await repo.login(phone: '+251911234567', pin: '1234');
        await repo.setCustomQuestion(
          currentPin: '1234',
          question: 'What did I name my first goat?',
          answer: 'Chaltu',
        );
        await repo.logout();
      });

      test('it is offered on the Forgot PIN screen', () async {
        expect(
          await repo.customRecoveryQuestion('+251911234567'),
          'What did I name my first goat?',
        );
      });

      test('offline, the reset needs the own answer too', () async {
        online = false;

        await expectLater(
          () => repo.resetPin(
            phone: '+251911234567',
            answers: answers,
            newPin: '4321',
          ),
          throwsA(isA<InvalidCredentialsFailure>()),
        );
        expect(
          await repo.resetPin(
            phone: '+251911234567',
            answers: answers,
            newPin: '4321',
            customAnswer: 'Chaltu',
          ),
          PinChangeOutcome.queued,
        );
      });

      test(
        'online, a wrong own answer stops the reset before the server is asked',
        () async {
          fake.requests.clear();

          await expectLater(
            () => repo.resetPin(
              phone: '+251911234567',
              answers: answers,
              newPin: '4321',
              customAnswer: 'Wrong',
            ),
            throwsA(isA<InvalidCredentialsFailure>()),
          );
          expect(
            fake.requests.where(
              (RecordedRequest r) => r.path.endsWith('/reset-pin'),
            ),
            isEmpty,
          );
        },
      );

      test('saving it needs the current PIN', () async {
        await repo.login(phone: '+251911234567', pin: '1234');

        await expectLater(
          () => repo.setCustomQuestion(
            currentPin: '0000',
            question: 'Another?',
            answer: 'Yes',
          ),
          throwsA(isA<InvalidCredentialsFailure>()),
        );
        await repo.clearCustomQuestion(currentPin: '1234');
        expect(await repo.customRecoveryQuestion('+251911234567'), isNull);
      });
    });

    test('offline, the patient whose records are here resets a forgotten PIN, then signs in with it', () async {
      online = false;
      expect(await repo.recoveryQuestions('+251911234567'), hasLength(3));

      final outcome = await repo.resetPin(
        phone: '+251911234567',
        answers: answers,
        newPin: '4321',
      );

      expect(outcome, PinChangeOutcome.queued);
      expect(switches, 0);
      await repo.logout();
      expect((await repo.login(phone: '+251911234567', pin: '4321')).id, 'u1');
    });
  });

  group('offline sign-in', () {
    late _MemoryCredentialStore remembered;
    late FakeTokenStore tokens;
    late OfflineSession session;
    late FakeDio fake;
    late bool online;
    late AuthRepositoryImpl repo;

    setUp(() {
      final db = testDatabase();
      addTearDown(db.close);
      remembered = _MemoryCredentialStore();
      tokens = FakeTokenStore();
      session = OfflineSession();
      fake = FakeDio()..stub('/api/v1/auth/login', FakeResponse.ok(_validJson));
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
        pending: MemoryPendingPinChangeStore(),
        isOnline: () async => online,
      );
    });

    /// A patient who signed in on this phone once, then signed out.
    Future<void> signedInBefore() async {
      await repo.login(phone: '+251911234567', pin: '1234');
      await repo.logout();
      fake.requests.clear();
    }

    test(
      'a patient who signed in here before can sign in with no network',
      () async {
        await signedInBefore();
        online = false;

        final user = await repo.login(phone: '+251911234567', pin: '1234');

        expect(user.name, 'Abebe Girma');
        expect(fake.requests, isEmpty);
        expect(await repo.isSignedIn(), isTrue);
        expect(await repo.cachedUser(), user);
      },
    );

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

    test(
      'a server that cannot be reached falls back to the remembered account',
      () async {
        await signedInBefore();
        fake.stub('/api/v1/auth/login', FakeResponse.offline());

        final user = await repo.login(phone: '+251911234567', pin: '1234');

        expect(user.id, 'u1');
        expect(await repo.isSignedIn(), isTrue);
      },
    );

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

    test(
      'a server that answers 401 wins over a matching remembered PIN',
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
      },
    );

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

    test(
      'refreshSession trades an offline sign-in for a server token',
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
      },
    );

    test('refreshSession is a no-op without an offline session', () async {
      expect(await repo.refreshSession(), isTrue);
      expect(fake.requests, isEmpty);
    });

    test(
      'refreshSession keeps the offline session while the server is down',
      () async {
        await signedInBefore();
        online = false;
        await repo.login(phone: '+251911234567', pin: '1234');
        online = true;
        fake.stub('/api/v1/auth/login', FakeResponse.offline());

        expect(await repo.refreshSession(), isTrue);
        expect(session.isActive, isTrue);
      },
    );

    test(
      'a PIN the server no longer accepts ends the session and is forgotten',
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
      },
    );
  });
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
