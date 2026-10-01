import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/data/datasources/offline_credential_store.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/security_question.dart';

import '../../../../helpers/auth_fakes.dart';

const AuthUser _user = AuthUser(
  id: 'u1',
  name: 'Abebe Girma',
  phone: '+251911234567',
  preferredLanguage: 'en',
  role: 'PATIENT',
);

const List<SecurityAnswer> _answers = <SecurityAnswer>[
  SecurityAnswer(SecurityQuestion.firstSchool, 'Bole Primary'),
  SecurityAnswer(SecurityQuestion.childhoodFriend, 'Dawit'),
  SecurityAnswer(SecurityQuestion.favoriteTeacher, 'Ato Kebede'),
];

const List<SecurityAnswer> _oneWrong = <SecurityAnswer>[
  SecurityAnswer(SecurityQuestion.firstSchool, 'Bole Primary'),
  SecurityAnswer(SecurityQuestion.childhoodFriend, 'Dawit'),
  SecurityAnswer(SecurityQuestion.favoriteTeacher, 'Someone Else'),
];

void main() {
  late DateTime now;
  late MemoryCredentialStore store;

  setUp(() {
    now = DateTime.utc(2026, 10, 1, 9);
    store = MemoryCredentialStore(clock: () => now);
  });

  group('changePin', () {
    test('replaces the remembered PIN', () async {
      await store.remember(user: _user, pin: '1234');

      await store.changePin('5678');

      expect(await store.verify(phone: _user.phone, pin: '1234'), OfflineCheck.wrongPin);
      expect(await store.verify(phone: _user.phone, pin: '5678'), OfflineCheck.match);
    });

    test('keeps the stored security answers', () async {
      await store.remember(user: _user, pin: '1234');
      await store.rememberAnswers(_answers);

      await store.changePin('5678');

      expect(await store.rememberedQuestions(_user.phone), hasLength(3));
    });

    test('throws when nobody is remembered', () async {
      await expectLater(store.changePin('5678'), throwsStateError);
    });
  });

  group('remember', () {
    test('keeps the answers when the same user signs in again', () async {
      await store.remember(user: _user, pin: '1234');
      await store.rememberAnswers(_answers);

      await store.remember(user: _user, pin: '1234');

      expect(await store.verifyAnswers(phone: _user.phone, answers: _answers), OfflineCheck.match);
    });

    test('drops the answers when a different user signs in', () async {
      await store.remember(user: _user, pin: '1234');
      await store.rememberAnswers(_answers);

      await store.remember(
        user: const AuthUser(
          id: 'u2',
          name: 'Other',
          phone: '+251922222222',
          preferredLanguage: 'en',
          role: 'PATIENT',
        ),
        pin: '9999',
      );

      expect(await store.rememberedQuestions('+251922222222'), isEmpty);
    });
  });

  group('security answers', () {
    setUp(() async {
      await store.remember(user: _user, pin: '1234');
      await store.rememberAnswers(_answers);
    });

    test('stores only hashes, never the answers', () async {
      final String raw = store.values.values.single;
      expect(raw.contains('Dawit'), isFalse);
      expect(raw.toLowerCase().contains('dawit'), isFalse);
    });

    test('remembers which questions were chosen, for that phone only', () async {
      expect(await store.rememberedQuestions(_user.phone), <SecurityQuestion>[
        SecurityQuestion.firstSchool,
        SecurityQuestion.childhoodFriend,
        SecurityQuestion.favoriteTeacher,
      ]);
      expect(await store.rememberedQuestions('+251900000000'), isEmpty);
    });

    test('accepts the right answers typed with different case and spacing', () async {
      final OfflineCheck result = await store.verifyAnswers(
        phone: _user.phone,
        answers: const <SecurityAnswer>[
          SecurityAnswer(SecurityQuestion.favoriteTeacher, 'ato   KEBEDE'),
          SecurityAnswer(SecurityQuestion.firstSchool, ' bole primary '),
          SecurityAnswer(SecurityQuestion.childhoodFriend, 'DAWIT'),
        ],
      );
      expect(result, OfflineCheck.match);
    });

    test('one wrong answer fails', () async {
      expect(await store.verifyAnswers(phone: _user.phone, answers: _oneWrong), OfflineCheck.wrongPin);
    });

    test('answering other questions fails', () async {
      final OfflineCheck result = await store.verifyAnswers(
        phone: _user.phone,
        answers: const <SecurityAnswer>[
          SecurityAnswer(SecurityQuestion.childhoodStreet, 'Bole Primary'),
          SecurityAnswer(SecurityQuestion.childhoodFriend, 'Dawit'),
          SecurityAnswer(SecurityQuestion.favoriteTeacher, 'Ato Kebede'),
        ],
      );
      expect(result, OfflineCheck.wrongPin);
    });

    test('an unknown phone, or no stored answers, is unknownAccount', () async {
      expect(
        await store.verifyAnswers(phone: '+251900000000', answers: _answers),
        OfflineCheck.unknownAccount,
      );
      final MemoryCredentialStore empty = MemoryCredentialStore();
      await empty.remember(user: _user, pin: '1234');
      expect(await empty.verifyAnswers(phone: _user.phone, answers: _answers), OfflineCheck.unknownAccount);
    });

    test('five wrong attempts lock recovery for 60 minutes, like the server', () async {
      for (int i = 0; i < 4; i++) {
        expect(await store.verifyAnswers(phone: _user.phone, answers: _oneWrong), OfflineCheck.wrongPin);
      }
      expect(await store.verifyAnswers(phone: _user.phone, answers: _oneWrong), OfflineCheck.locked);
      expect(await store.recoveryLockedFor(), 60);

      // Locked means locked, even for the right answers...
      expect(await store.verifyAnswers(phone: _user.phone, answers: _answers), OfflineCheck.locked);
      // ...and the PIN itself is unaffected.
      expect(await store.verify(phone: _user.phone, pin: '1234'), OfflineCheck.match);

      now = now.add(const Duration(minutes: 61));
      expect(await store.verifyAnswers(phone: _user.phone, answers: _answers), OfflineCheck.match);
    });

    test('a successful check clears the recovery failures', () async {
      for (int i = 0; i < 4; i++) {
        await store.verifyAnswers(phone: _user.phone, answers: _oneWrong);
      }
      expect(await store.verifyAnswers(phone: _user.phone, answers: _answers), OfflineCheck.match);
      expect(await store.verifyAnswers(phone: _user.phone, answers: _oneWrong), OfflineCheck.wrongPin);
    });
  });
}
