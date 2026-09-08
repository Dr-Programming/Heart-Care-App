import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/clinical/alert_evaluator.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/features/symptoms/presentation/widgets/severity_result_banner.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('a NONE result shows the normal chip and its action', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: SeverityResultBanner(severity: Severity.none)),
    );

    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('No action needed. Keep monitoring.'), findsOneWidget);
    expect(find.byIcon(Icons.warning_rounded), findsNothing);
  });

  testWidgets('an URGENT result shows the urgent chip and its action', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: SeverityResultBanner(severity: Severity.urgent)),
    );

    expect(find.text('Urgent'), findsOneWidget);
    expect(find.text('Contact your clinician today.'), findsOneWidget);
  });

  testWidgets(
    'an EMERGENCY result renders as a full-width critical-red banner, not a chip',
    (WidgetTester tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: SeverityResultBanner(severity: Severity.emergency),
        ),
      );

      expect(find.text('Emergency'), findsOneWidget);
      expect(find.text('Call your emergency contact now.'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);

      final Container container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.critical);
      expect(
        (container.constraints?.maxWidth == double.infinity) ||
            container.constraints == null,
        isTrue,
      );
    },
  );

  testWidgets('renders the emergency action in Amharic', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: SeverityResultBanner(severity: Severity.emergency)),
      language: AppLanguage.am,
    );

    expect(find.text('ድንገተኛ'), findsOneWidget);
    expect(find.text('አሁኑኑ ለድንገተኛ አደጋ ተጠሪዎ ይደውሉ።'), findsOneWidget);
  });
}
