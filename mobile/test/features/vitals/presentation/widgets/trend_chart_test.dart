import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_series.dart';
import 'package:libu_care/features/vitals/presentation/widgets/trend_chart.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('renders one line per series without throwing', (WidgetTester tester) async {
    final DateTime day0 = DateTime.utc(2026, 9, 1);
    final List<ChartSeries> series = <ChartSeries>[
      ChartSeries(
        label: 'vitals.field.systolic',
        points: <MapEntry<DateTime, double>>[
          MapEntry<DateTime, double>(day0, 120),
          MapEntry<DateTime, double>(day0.add(const Duration(days: 1)), 122),
          MapEntry<DateTime, double>(day0.add(const Duration(days: 2)), 118),
        ],
        targetValue: 120,
      ),
      ChartSeries(
        label: 'vitals.field.diastolic',
        points: <MapEntry<DateTime, double>>[
          MapEntry<DateTime, double>(day0, 80),
          MapEntry<DateTime, double>(day0.add(const Duration(days: 1)), 81),
          MapEntry<DateTime, double>(day0.add(const Duration(days: 2)), 79),
        ],
      ),
    ];

    await pumpApp(tester, Scaffold(body: TrendChart(series: series)));

    expect(find.byType(TrendChart), findsOneWidget);
  });
}
