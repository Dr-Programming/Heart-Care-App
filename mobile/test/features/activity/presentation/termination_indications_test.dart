import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/activity/presentation/widgets/termination_indications.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets(
    'shows the title and all four termination indications with no scrolling',
    (WidgetTester tester) async {
      await pumpApp(tester, const Scaffold(body: TerminationIndications()));

      expect(find.text('Stop and rest if you notice:'), findsOneWidget);
      expect(find.textContaining('Chest pain or pressure'), findsOneWidget);
      expect(find.textContaining('Dizziness or feeling faint'), findsOneWidget);
      expect(
        find.textContaining('Blood pressure outside your safe range'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Blood glucose below 6 or above 15 mmol/L'),
        findsOneWidget,
      );
    },
  );
}
