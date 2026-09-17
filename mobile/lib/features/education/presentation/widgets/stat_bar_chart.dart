import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/content_block.dart';

class StatBarChart extends StatelessWidget {
  const StatBarChart({required this.chart, super.key});

  final BarChartBlock chart;

  @override
  Widget build(BuildContext context) {
    if (chart.bars.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(chart.title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            chart.citation,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      );
    }

    final double maxValue = chart.bars
        .map((BarDatum b) => b.value)
        .reduce((double a, double b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(chart.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxValue * 1.2,
              barGroups: <BarChartGroupData>[
                for (int i = 0; i < chart.bars.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: <BarChartRodData>[
                      BarChartRodData(
                        toY: chart.bars[i].value,
                        color: AppColors.accent,
                        width: 24,
                      ),
                    ],
                  ),
              ],
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final int index = value.toInt();
                      if (index < 0 || index >= chart.bars.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SizedBox(
                          width: 56,
                          child: Text(
                            chart.bars[index].label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontSize: 9),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (double value, TitleMeta meta) => Text(
                      value.toInt().toString(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${chart.citation} (${chart.unit})',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
