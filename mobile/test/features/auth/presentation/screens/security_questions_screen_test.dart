import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/security_question.dart';
import 'package:libu_care/features/auth/presentation/screens/security_questions_screen.dart';

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
      const SecurityQuestionsScreen(),
      overrides: <Override>[
        pinRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(StubAuthRepository()),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(WidgetTester tester, List<String> answers, String pin) async {
    final Finder fields = find.byType(TextField);
    for (int i = 0; i < 3; i++) {
      await tester.enterText(fields.at(i), answers[i]);
    }
    await tester.enterText(fields.at(3), pin);
    await tester.ensureVisible(find.byKey(const Key('securityQuestionsSubmit')));
    await tester.tap(find.byKey(const Key('securityQuestionsSubmit')));
    await tester.pumpAndSettle();
  }

  testWidgets('starts with three different questions and sends the answers with the PIN', (tester) async {
    await pump(tester);
    await fillAndSubmit(tester, <String>['Bole Primary', 'Dawit', 'Ato Kebede'], '1234');

    final set = repo.answerSets.single;
    expect(set.currentPin, '1234');
    expect(set.answers.map((SecurityAnswer a) => a.question).toSet(), hasLength(3));
    expect(set.answers.map((SecurityAnswer a) => a.answer), <String>['Bole Primary', 'Dawit', 'Ato Kebede']);
  });

  testWidgets('too-short answers are caught before sending', (tester) async {
    await pump(tester);
    await fillAndSubmit(tester, <String>['B', 'Dawit', 'Ato Kebede'], '1234');

    expect(find.text('auth.securityQuestions.answerLength'.tr()), findsOneWidget);
    expect(repo.answerSets, isEmpty);
  });

  testWidgets('needs a connection', (tester) async {
    await pump(tester);
    repo.error = const NetworkFailure('offline');
    await fillAndSubmit(tester, <String>['Bole Primary', 'Dawit', 'Ato Kebede'], '1234');

    expect(find.text('auth.securityQuestions.needsConnection'.tr()), findsOneWidget);
  });
}
