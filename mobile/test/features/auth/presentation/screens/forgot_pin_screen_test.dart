import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/security_question.dart';
import 'package:libu_care/features/auth/presentation/screens/forgot_pin_screen.dart';

import '../../../../helpers/fake_pin_repository.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  late FakePinRepository repo;

  Future<void> pump(WidgetTester tester) async {
    repo = FakePinRepository();
    final db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      const ForgotPinScreen(),
      overrides: <Override>[
        pinRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(StubAuthRepository()),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
  }

  Future<void> findQuestions(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '+251911234567');
    await tester.tap(find.byKey(const Key('forgotPinFindQuestions')));
    await tester.pumpAndSettle();
  }

  testWidgets('starts by asking for the phone number, with a way back', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('auth.forgotPin.title'.tr()), findsOneWidget);
    expect(find.text('auth.forgotPin.back'.tr()), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows the questions for that phone', (tester) async {
    await pump(tester);
    await findQuestions(tester);

    expect(repo.questionLookups.single, '+251911234567');
    expect(
      find.text(SecurityQuestion.firstSchool.labelKey.tr()),
      findsOneWidget,
    );
    expect(
      find.text(SecurityQuestion.childhoodFriend.labelKey.tr()),
      findsOneWidget,
    );
    expect(
      find.text(SecurityQuestion.favoriteTeacher.labelKey.tr()),
      findsOneWidget,
    );
  });

  testWidgets('sends the answers and the new PIN', (tester) async {
    await pump(tester);
    await findQuestions(tester);

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Bole Primary');
    await tester.enterText(fields.at(1), 'Dawit');
    await tester.enterText(fields.at(2), 'Ato Kebede');
    await tester.enterText(fields.at(3), '5678');
    await tester.enterText(fields.at(4), '5678');
    await tester.ensureVisible(find.byKey(const Key('forgotPinSubmit')));
    await tester.tap(find.byKey(const Key('forgotPinSubmit')));
    await tester.pumpAndSettle();

    final reset = repo.resets.single;
    expect(reset.phone, '+251911234567');
    expect(reset.newPin, '5678');
    expect(reset.answers.map((SecurityAnswer a) => a.answer), <String>[
      'Bole Primary',
      'Dawit',
      'Ato Kebede',
    ]);
  });

  testWidgets('wrong answers show their error', (tester) async {
    await pump(tester);
    await findQuestions(tester);
    repo.error = const InvalidCredentialsFailure("The answers don't match");

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'aa');
    await tester.enterText(fields.at(1), 'bb');
    await tester.enterText(fields.at(2), 'cc');
    await tester.enterText(fields.at(3), '5678');
    await tester.enterText(fields.at(4), '5678');
    await tester.ensureVisible(find.byKey(const Key('forgotPinSubmit')));
    await tester.tap(find.byKey(const Key('forgotPinSubmit')));
    await tester.pumpAndSettle();

    expect(find.text('auth.forgotPin.answersDontMatch'.tr()), findsOneWidget);
  });

  testWidgets(
    'offline on a phone with no stored answers asks for a connection',
    (tester) async {
      await pump(tester);
      repo.error = const NetworkFailure('no connection');
      await findQuestions(tester);

      expect(find.text('auth.forgotPin.needsConnection'.tr()), findsOneWidget);
    },
  );

  testWidgets('answer fields use the text keyboard, not the phone pad', (
    tester,
  ) async {
    await pump(tester);
    await findQuestions(tester);

    for (int i = 0; i < 3; i++) {
      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(Key('forgotPinAnswer$i')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.keyboardType, TextInputType.text);
    }
  });

  testWidgets('a short answer shows its error under that answer only', (
    tester,
  ) async {
    await pump(tester);
    await findQuestions(tester);

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Bole Primary');
    await tester.enterText(fields.at(1), 'Dawit');
    await tester.enterText(fields.at(2), 'a');
    await tester.enterText(fields.at(3), '5678');
    await tester.enterText(fields.at(4), '5678');
    await tester.ensureVisible(find.byKey(const Key('forgotPinSubmit')));
    await tester.tap(find.byKey(const Key('forgotPinSubmit')));
    await tester.pumpAndSettle();

    final Finder error = find.text('auth.securityQuestions.answerLength'.tr());
    expect(error, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('forgotPinAnswer2')),
        matching: error,
      ),
      findsOneWidget,
    );
    expect(repo.resets, isEmpty);
  });

  testWidgets("asks the patient's own question too when this phone has one", (
    tester,
  ) async {
    await pump(tester);
    repo.customQuestion = 'What did I name my first goat?';
    await findQuestions(tester);

    expect(find.text('What did I name my first goat?'), findsOneWidget);

    final Finder fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Bole Primary');
    await tester.enterText(fields.at(1), 'Dawit');
    await tester.enterText(fields.at(2), 'Ato Kebede');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('forgotPinOwnAnswer')),
        matching: find.byType(TextField),
      ),
      'Chaltu',
    );
    await tester.enterText(fields.at(4), '5678');
    await tester.enterText(fields.at(5), '5678');
    await tester.ensureVisible(find.byKey(const Key('forgotPinSubmit')));
    await tester.tap(find.byKey(const Key('forgotPinSubmit')));
    await tester.pumpAndSettle();

    expect(repo.customAnswers.single, 'Chaltu');
  });

  testWidgets('without an own question, none is asked', (tester) async {
    await pump(tester);
    await findQuestions(tester);

    expect(find.byKey(const Key('forgotPinOwnAnswer')), findsNothing);
  });
}
