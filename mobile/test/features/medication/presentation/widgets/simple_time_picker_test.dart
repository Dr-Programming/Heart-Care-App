import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/presentation/widgets/simple_time_picker.dart';

import '../../../../helpers/pump_app.dart';

class _Captured {
  TimeOfDay? value;
}

void main() {
  Future<_Captured> openPicker(
    WidgetTester tester, {
    TimeOfDay initialTime = const TimeOfDay(hour: 0, minute: 0),
  }) async {
    final _Captured captured = _Captured();
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext context) => Material(
          child: TextButton(
            onPressed: () async {
              captured.value = await SimpleTimePicker.show(context, initialTime: initialTime);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return captured;
  }

  testWidgets('opens showing the given initial time in 12-hour form', (tester) async {
    await openPicker(tester, initialTime: const TimeOfDay(hour: 14, minute: 30));

    expect(find.text('02'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('meds.form.pm'.tr()), findsOneWidget);
  });

  testWidgets(
    'tapping a field selects its entire current value — the actual fix '
    "(Flutter's own inputOnly time picker only places a cursor on tap, "
    'which is why typing there means deleting first)',
    (tester) async {
      final _Captured captured = await openPicker(tester);

      final Finder hourField = find.byWidgetPredicate(
        (Widget w) => w is TextField && w.controller?.text == '12',
      );
      await tester.tap(hourField);
      await tester.pump();

      final TextField widget = tester.widget<TextField>(hourField);
      final TextEditingController controller = widget.controller!;
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 2),
        reason: 'the whole "12" must be selected on focus, not just a cursor placed in it',
      );

      await tester.tap(find.text('common.confirm'.tr()));
      await tester.pumpAndSettle();
      expect(captured.value, isNotNull);
    },
  );

  testWidgets('confirming with the default fields returns 00:00 (12:00 AM)', (tester) async {
    final _Captured captured = await openPicker(tester);

    await tester.tap(find.text('common.confirm'.tr()));
    await tester.pumpAndSettle();

    expect(captured.value, const TimeOfDay(hour: 0, minute: 0));
  });

  testWidgets('switching to PM with the default hour returns 12:00 (noon)', (tester) async {
    final _Captured captured = await openPicker(tester);

    await tester.tap(find.text('meds.form.pm'.tr()));
    await tester.pump();
    await tester.tap(find.text('common.confirm'.tr()));
    await tester.pumpAndSettle();

    expect(captured.value, const TimeOfDay(hour: 12, minute: 0));
  });

  testWidgets('Cancel returns null and adds nothing', (tester) async {
    final _Captured captured = await openPicker(tester);

    await tester.tap(find.text('common.cancel'.tr()));
    await tester.pumpAndSettle();

    expect(captured.value, isNull);
  });

  testWidgets(
    'an out-of-range typed value is clamped rather than rejected with an error',
    (tester) async {
      final _Captured captured = await openPicker(tester);

      final Finder minuteField = find.byWidgetPredicate(
        (Widget w) => w is TextField && w.controller?.text == '00',
      );
      await tester.enterText(minuteField, '99');
      await tester.pump();
      await tester.tap(find.text('common.confirm'.tr()));
      await tester.pumpAndSettle();

      expect(captured.value!.minute, 59);
      expect(tester.takeException(), isNull);
    },
  );
}
