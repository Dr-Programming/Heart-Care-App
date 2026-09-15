import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/domain/vital_descriptors.dart';
import 'package:libu_care/features/vitals/presentation/widgets/vital_form_fields.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('shows two fields for BP', (WidgetTester tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: VitalFormFields(
          descriptor: vitalDescriptors[VitalType.bloodPressure]!,
          controllers: <String, TextEditingController>{
            'systolic': TextEditingController(),
            'diastolic': TextEditingController(),
          },
          errors: const <String, String>{},
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('shows three fields for cholesterol', (WidgetTester tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: VitalFormFields(
          descriptor: vitalDescriptors[VitalType.cholesterol]!,
          controllers: <String, TextEditingController>{
            'ldl': TextEditingController(),
            'hdl': TextEditingController(),
            'total': TextEditingController(),
          },
          errors: const <String, String>{},
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(3));
  });
}
