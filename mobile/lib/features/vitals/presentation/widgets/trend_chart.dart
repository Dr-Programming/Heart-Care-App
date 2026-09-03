import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/vital_series.dart';

/// A [VitalSeries] plus the colour it draws in — the presentation-layer
/// counterpart to the Flutter-free domain entity (Decision 5).
class ChartSeries {
  const ChartSeries({required this.series, required this.color});

  final VitalSeries series;
  final Color color;
}

/// One chart, parameterised by series — the same widget draws a single
/// glucose line and blood pressure's two lines sharing an axis. Never called
/// with fewer than `minReadingsForTrend` points per series; that gate lives
/// in the trend screen (Task 15), not here.
class TrendChart extends StatelessWidget {
  const TrendChart({required this.series, super.key});

  final List<ChartSeries> series;

  static const AxisTitles _hiddenAxis = AxisTitles(
    sideTitles: SideTitles(showTitles: false),
  );

  @override
  Widget build(BuildContext context) {
    final Iterable<double> allValues = series.expand(
      (ChartSeries c) => c.series.points.map((VitalPoint p) => p.value),
    );
    final double minY = allValues.reduce((double a, double b) => a < b ? a : b);
    final double maxY = allValues.reduce((double a, double b) => a > b ? a : b);
    final double pad = (maxY - minY) * 0.15 + 1;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: minY - pad,
          maxY: maxY + pad,
          gridData: const FlGridData(drawVerticalLine: false),
          titlesData: const FlTitlesData(
            leftTitles: _hiddenAxis,
            topTitles: _hiddenAxis,
            rightTitles: _hiddenAxis,
            bottomTitles: _hiddenAxis,
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: <LineChartBarData>[
            for (final ChartSeries c in series)
              LineChartBarData(
                spots: <FlSpot>[
                  for (final VitalPoint p in c.series.points)
                    FlSpot(p.date.millisecondsSinceEpoch.toDouble(), p.value),
                ],
                color: c.color,
                barWidth: 2,
                dotData: const FlDotData(show: true),
              ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: <HorizontalLine>[
              for (final ChartSeries c in series)
                if (c.series.targetValue != null)
                  HorizontalLine(
                    y: c.series.targetValue!,
                    color: c.color.withValues(alpha: 0.5),
                    dashArray: const <int>[6, 4],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
