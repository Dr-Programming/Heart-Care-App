import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/presentation/screens/forgot_pin_screen.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('shows the guidance copy and a way back to sign in', (tester) async {
    await pumpApp(tester, const ForgotPinScreen());
    expect(find.text('auth.forgotPin.title'.tr()), findsOneWidget);
    expect(find.text('auth.forgotPin.back'.tr()), findsOneWidget);
  });

  testWidgets('has no input fields at all', (tester) async {
    await pumpApp(tester, const ForgotPinScreen());
    expect(find.byType(TextField), findsNothing);
  });
}
