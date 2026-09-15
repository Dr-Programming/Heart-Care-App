import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/vital_series.dart';

class TrendChart extends StatelessWidget {
  const TrendChart({required this.series, super.key});

  final List<ChartSeries> series;

  static const List<Color> _lineColors = <Color>[
    AppColors.accent,
    AppColors.critical,
  ];

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty || series.first.points.isEmpty) {
      return const SizedBox.shrink();
    }

    final DateTime epoch = series.first.points.first.key;

    double x(DateTime t) => t.difference(epoch).inHours.toDouble();

    final List<HorizontalLine> targetLines = <HorizontalLine>[
      for (int i = 0; i < series.length; i++)
        if (series[i].targetValue != null)
          HorizontalLine(
            y: series[i].targetValue!,
            color: _lineColors[i % _lineColors.length].withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: <int>[6, 4],
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (series.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 16,
              children: <Widget>[
                for (int i = 0; i < series.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        color: _lineColors[i % _lineColors.length],
                      ),
                      const SizedBox(width: 4),
                      Text(series[i].label.tr()),
                    ],
                  ),
              ],
            ),
          ),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              extraLinesData: ExtraLinesData(horizontalLines: targetLines),
              lineBarsData: <LineChartBarData>[
                for (int i = 0; i < series.length; i++)
                  LineChartBarData(
                    isCurved: false,
                    color: _lineColors[i % _lineColors.length],
                    dotData: const FlDotData(show: true),
                    spots: <FlSpot>[
                      for (final MapEntry<DateTime, double> point in series[i].points)
                        FlSpot(x(point.key), point.value),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
