import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/vital_series.dart';

/// A minimal, axis-free trend line for a tight space — the Vitals tab
/// root's per-type entry point into the full trend screen.
class Sparkline extends StatelessWidget {
  const Sparkline({
    required this.points,
    required this.color,
    this.height = 32,
    super.key,
  });

  final List<VitalPoint> points;
  final Color color;
  final double height;

  static const AxisTitles _hiddenAxis = AxisTitles(
    sideTitles: SideTitles(showTitles: false),
  );

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return SizedBox(height: height);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            leftTitles: _hiddenAxis,
            topTitles: _hiddenAxis,
            rightTitles: _hiddenAxis,
            bottomTitles: _hiddenAxis,
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: <FlSpot>[
                for (int i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].value),
              ],
              color: color,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
