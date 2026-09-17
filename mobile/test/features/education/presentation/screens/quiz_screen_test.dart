import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/presentation/screens/quiz_screen.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  setUp(rootBundle.clear);

  testWidgets('shows an explanation for a wrong answer', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const QuizScreen(topicId: 'chd-basics'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('The heart becomes too large'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Not quite - CHD is about narrowed arteries, not the size of the heart itself.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows an explanation for a right answer too', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const QuizScreen(topicId: 'chd-basics'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Plaque builds up in the arteries that supply the heart'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Right - that build-up is what narrows the arteries and reduces blood flow to the heart.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('finishing all questions shows the retake button', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const QuizScreen(topicId: 'chd-basics'));
    await tester.pumpAndSettle();

    for (int i = 0; i < 3; i++) {
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      final Finder nextOrFinish = find.text('Next').evaluate().isNotEmpty
          ? find.text('Next')
          : find.text('Finish');
      await tester.tap(nextOrFinish);
      await tester.pumpAndSettle();
    }

    expect(find.text('Retake quiz'), findsOneWidget);
  });
}
