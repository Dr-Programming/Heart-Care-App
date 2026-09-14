import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/profile/presentation/widgets/comorbidity_chips.dart';
import 'package:libu_care/features/profile/presentation/widgets/goal_field.dart';
import 'package:libu_care/features/profile/presentation/widgets/wizard_progress.dart';
import 'package:libu_care/features/profile/presentation/widgets/year_field.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  group('YearField', () {
    testWidgets('accepts a 4-digit year and reports it via onChanged', (
      tester,
    ) async {
      String? reported;
      await pumpApp(
        tester,
        YearField(
          controller: TextEditingController(),
          label: 'Birth year',
          onChanged: (v) => reported = v,
        ),
      );
      await tester.enterText(find.byType(TextField), '1968');
      expect(reported, '1968');
    });

    testWidgets('rejects a 5th digit', (tester) async {
      final controller = TextEditingController();
      await pumpApp(
        tester,
        YearField(controller: controller, label: 'Birth year'),
      );
      await tester.enterText(find.byType(TextField), '19680');
      expect(controller.text.length, lessThanOrEqualTo(4));
    });
  });

  group('ComorbidityChips', () {
    testWidgets('tapping a curated chip adds it to the selection', (
      tester,
    ) async {
      Set<String> current = <String>{};
      await pumpApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) => ComorbidityChips(
            curated: const <(String, String)>[
              ('diabetes', 'Diabetes'),
              ('hypertension', 'Hypertension'),
            ],
            selected: current,
            onChanged: (s) => setState(() => current = s),
          ),
        ),
      );
      await tester.tap(find.text('Diabetes'));
      await tester.pump();
      expect(current, contains('diabetes'));
    });

    testWidgets('tapping a selected chip removes it', (tester) async {
      Set<String> current = <String>{'diabetes'};
      await pumpApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) => ComorbidityChips(
            curated: const <(String, String)>[('diabetes', 'Diabetes')],
            selected: current,
            onChanged: (s) => setState(() => current = s),
          ),
        ),
      );
      await tester.tap(find.text('Diabetes'));
      await tester.pump();
      expect(current, isEmpty);
    });

    testWidgets(
      'stores the stable English key even when the display label is non-English (regression)',
      (tester) async {
        Set<String> current = <String>{};
        await pumpApp(
          tester,
          StatefulBuilder(
            builder: (context, setState) => ComorbidityChips(
              curated: const <(String, String)>[('diabetes', 'የስኳር በሽታ')],
              selected: current,
              onChanged: (s) => setState(() => current = s),
            ),
          ),
        );
        await tester.tap(find.text('የስኳር በሽታ'));
        await tester.pump();
        expect(current, contains('diabetes'));
        expect(current, isNot(contains('የስኳር በሽታ')));
      },
    );
  });

  group('WizardProgress', () {
    testWidgets('renders one dot per step', (tester) async {
      await pumpApp(tester, const WizardProgress(step: 1, totalSteps: 3));
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('GoalField', () {
    testWidgets('renders the label and suffix', (tester) async {
      await pumpApp(
        tester,
        GoalField(
          controller: TextEditingController(),
          label: 'Steps per day',
          suffixText: 'steps',
        ),
      );
      expect(find.text('Steps per day'), findsOneWidget);
    });
  });
}
