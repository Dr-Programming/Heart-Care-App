import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/education/domain/entities/content_block.dart';
import 'package:libu_care/features/education/presentation/widgets/block_renderer.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('renders a paragraph block', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: BlockRenderer(block: ParagraphBlock('Hello there'))),
    );
    expect(find.text('Hello there'), findsOneWidget);
  });

  testWidgets('renders a bullet list block', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: BlockRenderer(block: BulletListBlock(<String>['one', 'two'])),
      ),
    );
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('renders a callout block', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: BlockRenderer(
          block: CalloutBlock(style: CalloutStyle.warning, text: 'Be careful'),
        ),
      ),
    );
    expect(find.text('Be careful'), findsOneWidget);
  });

  testWidgets('renders a categoryRanges chart with its citation', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: BlockRenderer(
          block: CategoryRangesChartBlock(
            title: 'Test chart',
            citation: 'Test source',
            unit: 'mmHg',
            ranges: <CategoryRange>[],
          ),
        ),
      ),
    );
    expect(find.text('Test source'), findsOneWidget);
  });
}
