import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_reading.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_type.dart';
import 'package:libu_care/features/vitals/presentation/widgets/reading_row.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('saving a systolic of 190 shows an urgent status', (WidgetTester tester) async {
    final VitalReading reading = VitalReading(
      clientRecordId: 'c1',
      serverId: null,
      type: VitalType.bloodPressure,
      values: <String, double>{'systolic': 190, 'diastolic': 100},
      flagged: true,
      bmi: null,
      measuredAt: DateTime.utc(2026, 9, 5),
      note: null,
    );

    await pumpApp(
      tester,
      Scaffold(body: ReadingRow(reading: reading, localeCode: 'en')),
    );

    expect(find.text('190/100 mmHg'), findsOneWidget);
  });
}
