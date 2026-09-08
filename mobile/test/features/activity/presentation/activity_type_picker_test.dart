import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/activity/domain/entities/activity_session.dart';
import 'package:libu_care/features/activity/presentation/widgets/activity_type_picker.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets(
    'shows all seven types, including farming and household as their own chips',
    (WidgetTester tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: ActivityTypePicker(
            value: ActivityType.walking,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Walking'), findsOneWidget);
      expect(find.text('Jogging'), findsOneWidget);
      expect(find.text('Cycling'), findsOneWidget);
      expect(find.text('Household work'), findsOneWidget);
      expect(find.text('Farming'), findsOneWidget);
      expect(find.text('Stretching'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    },
  );

  testWidgets('tapping a chip reports the selected type', (
    WidgetTester tester,
  ) async {
    ActivityType? selected;
    await pumpApp(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Scaffold(
            body: ActivityTypePicker(
              value: ActivityType.walking,
              onChanged: (ActivityType type) => setState(() => selected = type),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Farming'));
    await tester.pumpAndSettle();

    expect(selected, ActivityType.farming);
  });
}
