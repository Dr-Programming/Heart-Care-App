import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/domain/security_question.dart';
import 'package:libu_care/features/auth/presentation/widgets/security_questions_fields.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  test('the error belongs to the answer that is wrong', () {
    final SecurityQuestionsFieldsController c =
        SecurityQuestionsFieldsController();
    c.answers[0].text = 'Bole Primary';
    c.answers[1].text = 'Dawit';
    c.answers[2].text = '';

    expect(c.validate(), isNull);
    expect(c.errorIndex, 2);
  });

  testWidgets('the chosen question is shown in full on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final SecurityQuestionsFieldsController c =
        SecurityQuestionsFieldsController();
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: SecurityQuestionsFields(controller: c),
        ),
      ),
    );

    final Finder picker = find.byKey(const Key('securityQuestionPicker0'));
    final Finder question = find.descendant(
      of: picker,
      matching: find.text(c.chosen[0].labelKey.tr()),
    );
    final Rect text = tester.getRect(question);
    final Rect box = tester.getRect(picker);
    // Wraps onto more than one line, and every line sits inside the field.
    expect(text.height, greaterThan(30));
    expect(
      box.contains(text.topLeft) &&
          box.contains(text.bottomRight - const Offset(1, 1)),
      isTrue,
    );
  });

  testWidgets('tapping the question opens the list to choose another', (
    tester,
  ) async {
    final SecurityQuestionsFieldsController c =
        SecurityQuestionsFieldsController();
    await pumpApp(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: SecurityQuestionsFields(controller: c),
        ),
      ),
    );
    final SecurityQuestion other = SecurityQuestion.values.last;

    await tester.tap(find.byKey(const Key('securityQuestionPicker0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(other.labelKey.tr()).last);
    await tester.pumpAndSettle();

    expect(c.chosen[0], other);
  });
}
