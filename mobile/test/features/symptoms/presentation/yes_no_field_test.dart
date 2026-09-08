import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/symptoms/presentation/widgets/yes_no_field.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('shows the label and both Yes/No options', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: YesNoField(label: 'Chest pain?', value: false, onChanged: (_) {}),
      ),
    );

    expect(find.text('Chest pain?'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('tapping Yes reports true', (WidgetTester tester) async {
    bool? reported;
    await pumpApp(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Scaffold(
            body: YesNoField(
              label: 'Chest pain?',
              value: false,
              onChanged: (bool v) => setState(() => reported = v),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();

    expect(reported, isTrue);
  });

  testWidgets('tapping No reports false', (WidgetTester tester) async {
    bool? reported;
    await pumpApp(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Scaffold(
            body: YesNoField(
              label: 'Swelling?',
              value: true,
              onChanged: (bool v) => setState(() => reported = v),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();

    expect(reported, isFalse);
  });

  testWidgets('renders in Amharic', (WidgetTester tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: YesNoField(label: 'የደረት ህመም?', value: false, onChanged: (_) {}),
      ),
      language: AppLanguage.am,
    );

    expect(find.text('አዎ'), findsOneWidget);
    expect(find.text('አይ'), findsOneWidget);
  });
}
