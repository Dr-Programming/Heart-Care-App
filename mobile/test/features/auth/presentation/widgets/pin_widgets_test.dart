import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/presentation/widgets/pin_box_input.dart';
import 'package:libu_care/features/auth/presentation/widgets/pin_field.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  group('PinField', () {
    testWidgets('is obscured and shows the bound controller text length', (tester) async {
      final controller = TextEditingController();
      await pumpApp(tester, PinField(controller: controller, label: '4-digit PIN'));

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pump();

      expect(controller.text, '1234');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
    });

    testWidgets('shows an error message when errorText is set', (tester) async {
      await pumpApp(
        tester,
        PinField(
          controller: TextEditingController(),
          label: '4-digit PIN',
          errorText: 'Your PIN must be exactly 4 digits',
        ),
      );

      expect(find.text('Your PIN must be exactly 4 digits'), findsOneWidget);
    });
  });

  group('PinBoxInput', () {
    testWidgets('renders 4 separate digit boxes', (tester) async {
      await pumpApp(tester, PinBoxInput(onCompleted: (_) {}));
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('typing 4 digits calls onCompleted with the full PIN', (tester) async {
      String? completed;
      await pumpApp(tester, PinBoxInput(onCompleted: (pin) => completed = pin));

      final boxes = find.byType(TextField);
      for (var i = 0; i < 4; i++) {
        await tester.enterText(boxes.at(i), '${i + 1}');
        await tester.pump();
      }

      expect(completed, '1234');
    });

    testWidgets('focus auto-advances to the next box after a digit', (tester) async {
      await pumpApp(tester, PinBoxInput(onCompleted: (_) {}));
      final boxes = find.byType(TextField);

      await tester.enterText(boxes.at(0), '1');
      await tester.pump();

      final secondField = tester.widget<TextField>(boxes.at(1));
      expect(secondField.focusNode?.hasFocus, isTrue);
    });

    
    
    
    
    testWidgets(
      'deleting the last digit and entering a different one calls onCompleted '
      'again with the corrected value',
      (tester) async {
        final List<String> completions = <String>[];
        await pumpApp(
          tester,
          PinBoxInput(onCompleted: completions.add),
        );

        final boxes = find.byType(TextField);
        for (var i = 0; i < 4; i++) {
          await tester.enterText(boxes.at(i), '${i + 1}');
          await tester.pump();
        }
        expect(completions, <String>['1234']);

        
        
        await tester.enterText(boxes.at(3), '');
        await tester.pump();
        expect(completions, <String>['1234']);

        
        
        await tester.enterText(boxes.at(3), '9');
        await tester.pump();
        expect(completions, <String>['1234', '1239']);
      },
    );

    
    
    
    
    
    testWidgets(
      'onIncomplete fires when a completed PIN is edited below 4 digits, '
      'and onCompleted fires again once re-completed',
      (tester) async {
        final List<String> completions = <String>[];
        var incompleteCalls = 0;
        await pumpApp(
          tester,
          PinBoxInput(
            onCompleted: completions.add,
            onIncomplete: () => incompleteCalls++,
          ),
        );

        final boxes = find.byType(TextField);
        for (var i = 0; i < 4; i++) {
          await tester.enterText(boxes.at(i), '${i + 1}');
          await tester.pump();
        }
        expect(completions, <String>['1234']);
        
        
        
        
        final int incompleteCallsAfterFill = incompleteCalls;

        
        
        await tester.enterText(boxes.at(3), '');
        await tester.pump();
        expect(incompleteCalls, greaterThan(incompleteCallsAfterFill));
        expect(completions, <String>['1234']);
        final int incompleteCallsAfterBackspace = incompleteCalls;

        
        
        
        await tester.enterText(boxes.at(3), '9');
        await tester.pump();
        expect(completions, <String>['1234', '1239']);
        expect(incompleteCalls, incompleteCallsAfterBackspace);
      },
    );
  });
}
