import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/domain/entities/block.dart';
import 'package:libu_care/features/education/presentation/widgets/block_renderer.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('renders a paragraph', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: BlockRenderer(block: ParagraphBlock('CHD narrows arteries.')),
      ),
    );

    expect(find.text('CHD narrows arteries.'), findsOneWidget);
  });

  testWidgets('renders every item of a bullet list', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: BlockRenderer(
          block: BulletListBlock(<String>['Chest pain', 'Fatigue']),
        ),
      ),
    );

    expect(find.text('Chest pain'), findsOneWidget);
    expect(find.text('Fatigue'), findsOneWidget);
  });

  testWidgets('a warning callout shows the warning icon', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: BlockRenderer(
          block: CalloutBlock(
            text: 'Seek help immediately.',
            tone: CalloutTone.warning,
          ),
        ),
      ),
    );

    expect(find.text('Seek help immediately.'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('an info callout (the default tone) shows the info icon', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: BlockRenderer(block: CalloutBlock(text: 'FYI.')),
      ),
    );

    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  });

  testWidgets('tapping a reference link reports its url', (
    WidgetTester tester,
  ) async {
    String? opened;
    await pumpApp(
      tester,
      Scaffold(
        body: BlockRenderer(
          block: const ReferenceLinkBlock(
            label: 'World Heart Federation',
            url: 'https://world-heart-federation.org',
          ),
          onOpenLink: (String url) => opened = url,
        ),
      ),
    );

    await tester.tap(find.text('World Heart Federation'));
    await tester.pumpAndSettle();

    expect(opened, 'https://world-heart-federation.org');
  });
}
