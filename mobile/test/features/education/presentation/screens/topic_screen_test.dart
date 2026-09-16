import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/presentation/screens/topic_screen.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  setUp(rootBundle.clear);

  testWidgets('renders the real chd-basics topic content', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const TopicScreen(topicId: 'chd-basics'));
    await tester.pumpAndSettle();
    expect(find.text('Understanding coronary heart disease'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Take the quiz'), 500);
    expect(find.text('Take the quiz'), findsOneWidget);
  });

  testWidgets('shows the empty state for an unknown topic id', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const TopicScreen(topicId: 'not-a-real-topic'));
    await tester.pumpAndSettle();
    expect(find.text('No topics available'), findsOneWidget);
  });
}
