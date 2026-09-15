import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class Sparkline extends StatelessWidget {
  const Sparkline({required this.points, super.key});

  final List<double> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      width: 64,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              isCurved: true,
              color: AppColors.accent,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              spots: <FlSpot>[
                for (int i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
