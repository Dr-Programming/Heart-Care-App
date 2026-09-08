import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/symptoms/presentation/widgets/severity_slider.dart';

import '../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('shows the label and the current value', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: SeveritySlider(
          label: 'Chest pain severity',
          value: 6,
          onChanged: (_) {},
        ),
      ),
    );

    expect(find.text('Chest pain severity'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('dragging to the maximum reports 10', (
    WidgetTester tester,
  ) async {
    int? reported;
    await pumpApp(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Scaffold(
            body: SeveritySlider(
              label: 'Chest pain severity',
              value: 0,
              onChanged: (int v) => setState(() => reported = v),
            ),
          );
        },
      ),
    );

    final Slider slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(10);
    await tester.pumpAndSettle();

    expect(reported, 10);
  });

  testWidgets('respects a custom min/max range', (WidgetTester tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: SeveritySlider(
          label: 'Energy',
          value: 5,
          min: 0,
          max: 10,
          onChanged: (_) {},
        ),
      ),
    );

    final Slider slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 0);
    expect(slider.max, 10);
    expect(slider.value, 5);
  });
}
