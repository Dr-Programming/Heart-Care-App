import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/features/vitals/domain/entities/vital_series.dart';
import 'package:libu_care/features/vitals/presentation/widgets/trend_chart.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  VitalSeries seriesOf(String key, List<double> values, {double? target}) {
    final DateTime start = DateTime(2026, 8, 1);
    return VitalSeries(
      key: key,
      points: <VitalPoint>[
        for (int i = 0; i < values.length; i++)
          VitalPoint(start.add(Duration(days: i)), values[i]),
      ],
      targetValue: target,
    );
  }

  testWidgets('renders one line per series, blood pressure included', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      TrendChart(
        series: <ChartSeries>[
          ChartSeries(
            series: seriesOf('systolic', <double>[120, 130, 125]),
            color: AppColors.accent,
          ),
          ChartSeries(
            series: seriesOf('diastolic', <double>[80, 85, 82]),
            color: AppColors.primary,
          ),
        ],
      ),
    );

    final LineChart chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));
  });

  testWidgets('draws a reference line only for a series with a target', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      TrendChart(
        series: <ChartSeries>[
          ChartSeries(
            series: seriesOf('glucose', <double>[5.0, 5.5, 6.0]),
            color: AppColors.accent,
          ),
        ],
      ),
    );

    final LineChart chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.extraLinesData.horizontalLines, isEmpty);
  });

  testWidgets('draws a reference line when a target is set', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      TrendChart(
        series: <ChartSeries>[
          ChartSeries(
            series: seriesOf('weight', <double>[70, 69, 68], target: 65),
            color: AppColors.accent,
          ),
        ],
      ),
    );

    final LineChart chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.extraLinesData.horizontalLines, hasLength(1));
    expect(chart.data.extraLinesData.horizontalLines.single.y, 65);
  });
}
