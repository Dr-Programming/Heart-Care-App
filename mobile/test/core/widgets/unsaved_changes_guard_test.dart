import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/widgets/unsaved_changes_guard.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  Future<void> openForm(WidgetTester tester, {required bool dirty}) async {
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => UnsavedChangesGuard(
                dirty: dirty,
                child: const Scaffold(body: Text('form')),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('back on a started form asks first and stays if told to', (
    tester,
  ) async {
    await openForm(tester, dirty: true);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('common.discard.title'.tr()), findsOneWidget);
    await tester.tap(find.text('common.discard.keepEditing'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('form'), findsOneWidget);
  });

  testWidgets('discarding leaves the form', (tester) async {
    await openForm(tester, dirty: true);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('common.discard.confirm'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('form'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('an untouched form closes straight away', (tester) async {
    await openForm(tester, dirty: false);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('common.discard.title'.tr()), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
