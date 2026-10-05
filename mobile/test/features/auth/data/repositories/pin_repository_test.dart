import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:libu_care/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:libu_care/features/auth/data/datasources/offline_credential_store.dart';
import 'package:libu_care/features/auth/data/datasources/pending_pin_change_store.dart';
import 'package:libu_care/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:libu_care/features/auth/domain/repositories/pin_repository.dart';
import 'package:libu_care/features/auth/domain/security_question.dart';

import '../../../../helpers/auth_fakes.dart';
import '../../../../helpers/fake_dio.dart';
import '../../../../helpers/test_database.dart';

const String _phone = '+251911234567';

const Map<String, dynamic> _session = <String, dynamic>{
  'token': 'header.payload.signature',
  'user': <String, dynamic>{
    'id': 'u1',
    'name': 'Abebe Girma',
    'phone': _phone,
    'preferredLanguage': 'en',
    'role': 'PATIENT',
  },
};

const List<SecurityAnswer> _answers = <SecurityAnswer>[
  SecurityAnswer(SecurityQuestion.firstSchool, 'Bole Primary'),
  SecurityAnswer(SecurityQuestion.childhoodFriend, 'Dawit'),
  SecurityAnswer(SecurityQuestion.favoriteTeacher, 'Ato Kebede'),
];

const List<SecurityAnswer> _wrongAnswers = <SecurityAnswer>[
  SecurityAnswer(SecurityQuestion.firstSchool, 'Bole Primary'),
  SecurityAnswer(SecurityQuestion.childhoodFriend, 'Dawit'),
  SecurityAnswer(SecurityQuestion.favoriteTeacher, 'Nobody'),
];

void main() {
  late MemoryCredentialStore remembered;
  late MemoryPendingPinChangeStore pending;
  late FakeTokenStore tokens;
  late OfflineSession session;
  late FakeDio fake;
  late bool online;
  late AuthRepositoryImpl repo;

  setUp(() {
    final db = testDatabase();
    addTearDown(db.close);
    remembered = MemoryCredentialStore();
    pending = MemoryPendingPinChangeStore();
    tokens = FakeTokenStore();
    session = OfflineSession();
    fake = FakeDio()
      ..stub('/api/v1/auth/login', FakeResponse.ok(_session))
      ..stub('/api/v1/auth/register', FakeResponse.ok(_session))
      ..stub('/api/v1/auth/pin-change', FakeResponse.ok(_session))
      ..stub('/api/v1/auth/reset-pin', FakeResponse.ok(_session))
      ..stub(
        '/api/v1/auth/security-answers',
        FakeResponse.ok(<String, dynamic>{
          'configured': true,
          'questions': <String>[
            'FIRST_SCHOOL',
            'CHILDHOOD_FRIEND',
            'FAVORITE_TEACHER',
          ],
        }),
      )
      ..stub(
        '/api/v1/auth/recovery/questions',
        FakeResponse.ok(<String, dynamic>{
          'questions': <String>[
            'CHILDHOOD_STREET',
            'FIRST_JOB_PLACE',
            'CHILDHOOD_HERO',
          ],
        }),
      );
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
      pending: pending,
      isOnline: () async => online,
    );
  });

  /// Signed in online once with PIN 1234 (so this phone remembers the account).
  Future<void> signedIn({bool withAnswers = false}) async {
    await repo.login(phone: _phone, pin: '1234');
    if (withAnswers) {
      await repo.setSecurityAnswers(currentPin: '1234', answers: _answers);
    }
    fake.requests.clear();
  }

  Future<bool> offlineLoginWorks(String pin) async {
    final bool wasOnline = online;
    online = false;
    try {
      await repo.login(phone: _phone, pin: pin);
      return true;
    } on Failure {
      return false;
    } finally {
      online = wasOnline;
      session.end();
    }
  }

  group('changePin', () {
    test('online: the server applies it straight away', () async {
      await signedIn();

      final PinChangeOutcome outcome = await repo.changePin(
        currentPin: '1234',
        newPin: '5678',
      );

      expect(outcome, PinChangeOutcome.applied);
      final RecordedRequest request = fake.requests.single;
      expect(request.path, '/api/v1/auth/pin-change');
      expect(request.json['phone'], _phone);
      expect(request.json['currentPin'], '1234');
      expect(request.json['newPin'], '5678');
      expect(request.json['changeId'], isA<String>());
      expect(await pending.read(), isNull);
      expect(await offlineLoginWorks('5678'), isTrue);
      expect(await offlineLoginWorks('1234'), isFalse);
    });

    test(
      'online: a wrong current PIN is refused and nothing changes',
      () async {
        await signedIn();
        fake.stub(
          '/api/v1/auth/pin-change',
          FakeResponse.error(401, 'Invalid phone or PIN'),
        );

        await expectLater(
          repo.changePin(currentPin: '9999', newPin: '5678'),
          throwsA(isA<InvalidCredentialsFailure>()),
        );
        expect(await pending.read(), isNull);
        expect(await offlineLoginWorks('1234'), isTrue);
      },
    );

    test('offline: checked on the phone, applied locally and queued', () async {
      await signedIn();
      online = false;

      final PinChangeOutcome outcome = await repo.changePin(
        currentPin: '1234',
        newPin: '5678',
      );

      expect(outcome, PinChangeOutcome.queued);
      expect(fake.requests, isEmpty);
      final PendingPinChange queued = (await pending.read())!;
      expect(queued.kind, PendingPinChangeKind.change);
      expect(queued.currentPin, '1234');
      expect(queued.newPin, '5678');
      expect(await offlineLoginWorks('5678'), isTrue);
      expect(await offlineLoginWorks('1234'), isFalse);
      expect(await repo.hasPendingPinChange(), isTrue);
    });

    test(
      'a server that cannot be reached falls back to the offline path',
      () async {
        await signedIn();
        fake.stub('/api/v1/auth/pin-change', FakeResponse.offline());

        expect(
          await repo.changePin(currentPin: '1234', newPin: '5678'),
          PinChangeOutcome.queued,
        );
        expect((await pending.read())!.newPin, '5678');
      },
    );

    test('offline: a wrong current PIN is refused, five lock it', () async {
      await signedIn();
      online = false;

      for (int i = 0; i < 4; i++) {
        await expectLater(
          repo.changePin(currentPin: '9999', newPin: '5678'),
          throwsA(isA<InvalidCredentialsFailure>()),
        );
      }
      await expectLater(
        repo.changePin(currentPin: '9999', newPin: '5678'),
        throwsA(isA<AccountLockedFailure>()),
      );
      expect(await pending.read(), isNull);
    });

    test(
      'offline twice: the server-side proof stays the original PIN',
      () async {
        await signedIn();
        online = false;

        await repo.changePin(currentPin: '1234', newPin: '5678');
        await repo.changePin(currentPin: '5678', newPin: '2468');

        final PendingPinChange queued = (await pending.read())!;
        expect(queued.currentPin, '1234');
        expect(queued.newPin, '2468');
      },
    );

    test(
      'online with a change already queued: queues behind it, then syncs',
      () async {
        await signedIn();
        online = false;
        await repo.changePin(currentPin: '1234', newPin: '5678');
        online = true;

        final PinChangeOutcome outcome = await repo.changePin(
          currentPin: '5678',
          newPin: '2468',
        );

        expect(outcome, PinChangeOutcome.applied);
        final RecordedRequest request = fake.requests.single;
        expect(request.json['currentPin'], '1234');
        expect(request.json['newPin'], '2468');
        expect(await pending.read(), isNull);
      },
    );
  });

  group('flushPendingPinChange', () {
    Future<PendingPinChange> queueOfflineChange() async {
      await signedIn();
      online = false;
      await repo.changePin(currentPin: '1234', newPin: '5678');
      online = true;
      return (await pending.read())!;
    }

    test('nothing pending makes no request', () async {
      await signedIn();
      expect(await repo.flushPendingPinChange(), PinSyncResult.nothingPending);
      expect(fake.requests, isEmpty);
    });

    test('accepted: the change is cleared and a session is stored', () async {
      final PendingPinChange queued = await queueOfflineChange();
      tokens.value = null;

      expect(await repo.flushPendingPinChange(), PinSyncResult.applied);

      expect(fake.requests.single.json['changeId'], queued.changeId);
      expect(fake.requests.single.json['currentPin'], '1234');
      expect(await pending.read(), isNull);
      expect(await tokens.read(), 'header.payload.signature');
      expect(await offlineLoginWorks('5678'), isTrue);
    });

    test(
      'server wins: a 401 drops the change and signs the patient out',
      () async {
        await queueOfflineChange();
        fake.stub(
          '/api/v1/auth/pin-change',
          FakeResponse.error(401, 'Invalid phone or PIN'),
        );

        expect(await repo.flushPendingPinChange(), PinSyncResult.conflict);

        expect(await pending.read(), isNull);
        expect(await repo.isSignedIn(), isFalse);
        expect(await remembered.rememberedUser(), isNull);
        expect(repo.takeSignOutReason(), SignOutReason.pinChangedElsewhere);
        expect(repo.takeSignOutReason(), isNull);
      },
    );

    test('server down or locked: the change waits for the next sync', () async {
      await queueOfflineChange();

      fake.stub('/api/v1/auth/pin-change', FakeResponse.offline());
      expect(await repo.flushPendingPinChange(), PinSyncResult.kept);
      fake.stub('/api/v1/auth/pin-change', FakeResponse.error(503, 'down'));
      expect(await repo.flushPendingPinChange(), PinSyncResult.kept);
      fake.stub(
        '/api/v1/auth/pin-change',
        FakeResponse.error(
          423,
          'Too many failed attempts. Try again in 15 minutes.',
        ),
      );
      expect(await repo.flushPendingPinChange(), PinSyncResult.kept);

      expect(await pending.read(), isNotNull);
      expect(await offlineLoginWorks('5678'), isTrue);
    });

    test(
      'a queued reset is sent with its answers; a 400 is a conflict',
      () async {
        await signedIn(withAnswers: true);
        online = false;
        await repo.resetPin(phone: _phone, answers: _answers, newPin: '5678');
        online = true;
        fake.stub(
          '/api/v1/auth/reset-pin',
          FakeResponse.error(400, "The answers don't match"),
        );

        expect(await repo.flushPendingPinChange(), PinSyncResult.conflict);

        final RecordedRequest request = fake.requests.single;
        expect(request.path, '/api/v1/auth/reset-pin');
        expect((request.json['answers'] as List<dynamic>), hasLength(3));
        expect(request.json['changeId'], isA<String>());
        expect(await repo.isSignedIn(), isFalse);
      },
    );
  });

  group('refreshSession and login with a queued change', () {
    test(
      'refreshSession sends the queued change instead of the stale sign-in',
      () async {
        await signedIn();
        online = false;
        await repo.changePin(currentPin: '1234', newPin: '5678');
        await repo.login(
          phone: _phone,
          pin: '5678',
        ); // offline session with the new PIN
        online = true;
        // The server still has 1234: an ordinary re-login with 5678 would be refused.
        fake.stub(
          '/api/v1/auth/login',
          FakeResponse.error(401, 'Invalid phone or PIN'),
        );

        expect(await repo.refreshSession(), isTrue);

        expect(fake.requests.single.path, '/api/v1/auth/pin-change');
        expect(session.isActive, isFalse);
        expect(await tokens.read(), 'header.payload.signature');
      },
    );

    test('refreshSession never wipes the new PIN while the change is still waiting', () async {
      await signedIn();
      online = false;
      await repo.changePin(currentPin: '1234', newPin: '5678');
      await repo.login(phone: _phone, pin: '5678');
      online = true;
      fake
        ..stub('/api/v1/auth/pin-change', FakeResponse.offline())
        ..stub(
          '/api/v1/auth/login',
          FakeResponse.error(401, 'Invalid phone or PIN'),
        );

      expect(await repo.refreshSession(), isTrue);

      expect(await remembered.rememberedUser(), isNotNull);
      expect(await pending.read(), isNotNull);
      expect(
        fake.requests.where(
          (RecordedRequest r) => r.path == '/api/v1/auth/login',
        ),
        isEmpty,
      );
    });

    test(
      'signing in online with the new PIN sends the queued change first',
      () async {
        await signedIn();
        online = false;
        await repo.changePin(currentPin: '1234', newPin: '5678');
        await repo.logout();
        online = true;

        final user = await repo.login(phone: _phone, pin: '5678');

        expect(user.id, 'u1');
        expect(fake.requests.map((RecordedRequest r) => r.path), <String>[
          '/api/v1/auth/pin-change',
        ]);
        expect(await pending.read(), isNull);
      },
    );
  });

  group('resetPin (forgot PIN)', () {
    test(
      'online: the server checks the answers; this phone keeps them for later',
      () async {
        await signedIn();
        await repo.logout();

        expect(
          await repo.resetPin(phone: _phone, answers: _answers, newPin: '5678'),
          PinChangeOutcome.applied,
        );

        final RecordedRequest request = fake.requests.single;
        expect(request.path, '/api/v1/auth/reset-pin');
        expect(request.json['newPin'], '5678');
        expect(await tokens.read(), 'header.payload.signature');
        expect(await remembered.rememberedQuestions(_phone), hasLength(3));
        expect(await offlineLoginWorks('5678'), isTrue);
      },
    );

    test(
      "online: answers the server rejects throw InvalidCredentialsFailure",
      () async {
        await signedIn();
        fake.stub(
          '/api/v1/auth/reset-pin',
          FakeResponse.error(400, "The answers don't match"),
        );

        await expectLater(
          repo.resetPin(phone: _phone, answers: _wrongAnswers, newPin: '5678'),
          throwsA(isA<InvalidCredentialsFailure>()),
        );
      },
    );

    test(
      'offline: checked against this phone, signed in, and queued',
      () async {
        await signedIn(withAnswers: true);
        await repo.logout();
        online = false;

        expect(
          await repo.resetPin(phone: _phone, answers: _answers, newPin: '5678'),
          PinChangeOutcome.queued,
        );

        expect(fake.requests, isEmpty);
        expect(await repo.isSignedIn(), isTrue);
        final PendingPinChange queued = (await pending.read())!;
        expect(queued.kind, PendingPinChangeKind.reset);
        expect(queued.answers, _answers);
        session.end();
        expect(await offlineLoginWorks('5678'), isTrue);
      },
    );

    test(
      'offline: wrong answers are refused, five lock recovery for 60 minutes',
      () async {
        await signedIn(withAnswers: true);
        online = false;

        for (int i = 0; i < 4; i++) {
          await expectLater(
            repo.resetPin(
              phone: _phone,
              answers: _wrongAnswers,
              newPin: '5678',
            ),
            throwsA(isA<InvalidCredentialsFailure>()),
          );
        }
        try {
          await repo.resetPin(
            phone: _phone,
            answers: _wrongAnswers,
            newPin: '5678',
          );
          fail('expected AccountLockedFailure');
        } on AccountLockedFailure catch (e) {
          expect(e.minutesRemaining, 60);
        }
        expect(await pending.read(), isNull);
      },
    );

    test(
      'offline on a phone without stored answers needs the internet',
      () async {
        await signedIn();
        online = false;

        await expectLater(
          repo.resetPin(phone: _phone, answers: _answers, newPin: '5678'),
          throwsA(isA<NetworkFailure>()),
        );
      },
    );
  });

  group('security questions', () {
    test('recovery questions come from the server when online', () async {
      expect(await repo.recoveryQuestions(_phone), <SecurityQuestion>[
        SecurityQuestion.childhoodStreet,
        SecurityQuestion.firstJobPlace,
        SecurityQuestion.childhoodHero,
      ]);
    });

    test('recovery questions come from this phone when offline', () async {
      await signedIn(withAnswers: true);
      online = false;

      expect(await repo.recoveryQuestions(_phone), <SecurityQuestion>[
        SecurityQuestion.firstSchool,
        SecurityQuestion.childhoodFriend,
        SecurityQuestion.favoriteTeacher,
      ]);
    });

    test(
      'offline with nothing stored for that phone needs the internet',
      () async {
        online = false;
        await expectLater(
          repo.recoveryQuestions(_phone),
          throwsA(isA<NetworkFailure>()),
        );
      },
    );

    test(
      'setting answers sends them with the PIN and keeps hashes here',
      () async {
        await signedIn();

        await repo.setSecurityAnswers(currentPin: '1234', answers: _answers);

        final RecordedRequest request = fake.requests.single;
        expect(request.method, 'PUT');
        expect(request.json['currentPin'], '1234');
        expect((request.json['answers'] as List<dynamic>), hasLength(3));
        expect(await repo.configuredQuestions(), hasLength(3));
      },
    );

    test('setting answers needs the internet', () async {
      await signedIn();
      online = false;
      await expectLater(
        repo.setSecurityAnswers(currentPin: '1234', answers: _answers),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('sign-up with security answers', () {
    test(
      'register sends the answers and keeps hashes here for offline reset',
      () async {
        await repo.register(
          phone: _phone,
          pin: '1234',
          name: 'Abebe Girma',
          preferredLanguage: 'en',
          securityAnswers: _answers,
        );

        final RecordedRequest request = fake.requests.single;
        expect(request.path, '/api/v1/auth/register');
        final List<dynamic> sent =
            request.json['securityAnswers'] as List<dynamic>;
        expect(
          sent.map((dynamic a) => (a as Map<String, dynamic>)['questionId']),
          <String>['FIRST_SCHOOL', 'CHILDHOOD_FRIEND', 'FAVORITE_TEACHER'],
        );
        expect(await repo.configuredQuestions(), hasLength(3));

        // Straight after sign-up, this phone can already reset the PIN offline.
        await repo.logout();
        online = false;
        expect(
          await repo.resetPin(phone: _phone, answers: _answers, newPin: '5678'),
          PinChangeOutcome.queued,
        );
      },
    );

    test('register without answers sends none', () async {
      await repo.register(
        phone: _phone,
        pin: '1234',
        name: 'Abebe Girma',
        preferredLanguage: 'en',
      );

      expect(fake.requests.single.json.containsKey('securityAnswers'), isFalse);
      expect(await repo.configuredQuestions(), isEmpty);
    });
  });

  group('securityQuestionsStatus', () {
    test('online: asks the server', () async {
      await signedIn();
      expect(await repo.securityQuestionsStatus(), isTrue);
      expect(fake.requests.single.method, 'GET');

      fake.stub(
        '/api/v1/auth/security-answers',
        FakeResponse.ok(<String, dynamic>{
          'configured': false,
          'questions': <String>[],
        }),
      );
      expect(await repo.securityQuestionsStatus(), isFalse);
    });

    test(
      'offline or unreachable: unknown, so nobody is nagged by mistake',
      () async {
        await signedIn();
        online = false;
        expect(await repo.securityQuestionsStatus(), isNull);

        online = true;
        fake.stub('/api/v1/auth/security-answers', FakeResponse.offline());
        expect(await repo.securityQuestionsStatus(), isNull);
      },
    );
  });
}
