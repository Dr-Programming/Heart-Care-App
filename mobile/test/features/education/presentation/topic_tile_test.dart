import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/domain/entities/section.dart';
import 'package:libu_care/features/education/domain/entities/topic.dart';
import 'package:libu_care/features/education/presentation/widgets/topic_tile.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  const Topic topic = Topic(
    id: 'diet',
    title: 'Eating for your heart',
    summary: 'Whole-teff injera, shiro and other heart-friendly staples.',
    sections: <ContentSection>[],
  );

  testWidgets('shows the title and summary', (WidgetTester tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: TopicTile(topic: topic, onTap: () {}),
      ),
    );

    expect(find.text('Eating for your heart'), findsOneWidget);
    expect(
      find.text('Whole-teff injera, shiro and other heart-friendly staples.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping calls onTap', (WidgetTester tester) async {
    bool tapped = false;
    await pumpApp(
      tester,
      Scaffold(
        body: TopicTile(topic: topic, onTap: () => tapped = true),
      ),
    );

    await tester.tap(find.byType(TopicTile));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
