import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/caregiver/caregiver_contact.dart';
import 'package:libu_care/core/widgets/critical_alert.dart';

import '../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  Future<void> open(
    WidgetTester tester, {
    CaregiverContact? caregiver,
    Future<void> Function(String number)? dial,
    VoidCallback? onAddCaregiver,
  }) async {
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => showCriticalAlert(
            context,
            caregiver: caregiver,
            dial: dial ?? (_) async {},
            onAddCaregiver: onAddCaregiver ?? () {},
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('tells the patient what to do and calls their caregiver', (
    tester,
  ) async {
    String? dialled;
    await open(
      tester,
      caregiver: const CaregiverContact(name: 'Almaz', phone: '+251911555666'),
      dial: (String number) async => dialled = number,
    );

    expect(find.text('clinical.critical.title'.tr()), findsOneWidget);
    expect(find.text('clinical.critical.body'.tr()), findsOneWidget);

    await tester.tap(
      find.text(
        'clinical.critical.callCaregiver'.tr(
          namedArgs: <String, String>{'name': 'Almaz'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(dialled, '+251911555666');
  });

  testWidgets('with no caregiver saved, it offers to add one', (tester) async {
    bool adding = false;
    await open(tester, onAddCaregiver: () => adding = true);

    expect(find.text('clinical.critical.noCaregiver'.tr()), findsOneWidget);
    await tester.tap(find.text('clinical.critical.addCaregiver'.tr()));
    await tester.pumpAndSettle();

    expect(adding, isTrue);
    expect(find.text('clinical.critical.title'.tr()), findsNothing);
  });

  testWidgets('closing it returns to the app', (tester) async {
    await open(tester);

    await tester.tap(find.text('clinical.critical.understood'.tr()));
    await tester.pumpAndSettle();

    expect(find.text('clinical.critical.title'.tr()), findsNothing);
  });
}
