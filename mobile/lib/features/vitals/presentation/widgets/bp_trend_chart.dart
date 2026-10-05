import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/bp_trend.dart';

/// Daily systolic and diastolic averages with the patient's target and the
/// critical line drawn across, as in the BP trend design.
class BpTrendChart extends StatelessWidget {
  const BpTrendChart({
    required this.trend,
    required this.windowDays,
    super.key,
  });

  final BpTrend trend;
  final int windowDays;

  static const Color systolicColor = AppColors.accent;
  static const Color diastolicColor = AppColors.ink;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime start = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    ).subtract(Duration(days: windowDays - 1));
    double x(DateTime day) => day.difference(start).inDays.toDouble();

    final double maxValue = <double>[
      BpTrend.criticalSystolic + 10,
      ...trend.days.map((BpDay d) => d.systolic + 10),
    ].reduce((double a, double b) => a > b ? a : b);
    final double minValue = <double>[
      60,
      ...trend.days.map((BpDay d) => d.diastolic - 10),
    ].reduce((double a, double b) => a < b ? a : b);

    HorizontalLine line(double y, Color color, String label) => HorizontalLine(
      y: y,
      color: color,
      strokeWidth: 1,
      dashArray: <int>[5, 4],
      label: HorizontalLineLabel(
        show: true,
        alignment: Alignment.topRight,
        style: text.labelSmall?.copyWith(color: color),
        labelResolver: (_) => label,
      ),
    );

    final String localeCode = context.locale.languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.lg,
          children: <Widget>[
            _Legend(color: systolicColor, label: 'vitals.field.systolic'.tr()),
            _Legend(
              color: diastolicColor,
              label: 'vitals.field.diastolic'.tr(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 240,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (windowDays - 1).toDouble(),
              minY: minValue,
              maxY: maxValue,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                horizontalLines: <HorizontalLine>[
                  line(
                    trend.targetSystolic,
                    AppColors.success,
                    'vitals.bpTrend.target'.tr(),
                  ),
                  line(
                    BpTrend.criticalSystolic,
                    AppColors.critical,
                    'vitals.bpTrend.critical'.tr(),
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 20,
                    getTitlesWidget: (double value, TitleMeta meta) =>
                        Text(value.toInt().toString(), style: text.labelSmall),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: windowDays <= 7 ? 1 : 7,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final DateTime day = start.add(
                        Duration(days: value.toInt()),
                      );
                      final String label = windowDays <= 7
                          ? DateFormat.E(localeCode).format(day)
                          : DateFormat.Md(localeCode).format(day);
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(label, style: text.labelSmall),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: <LineChartBarData>[
                _bar(systolicColor, <FlSpot>[
                  for (final BpDay d in trend.days)
                    FlSpot(x(d.day), d.systolic),
                ]),
                _bar(diastolicColor, <FlSpot>[
                  for (final BpDay d in trend.days)
                    FlSpot(x(d.day), d.diastolic),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LineChartBarData _bar(Color color, List<FlSpot> spots) => LineChartBarData(
    spots: spots,
    color: color,
    barWidth: 2,
    dotData: const FlDotData(show: true),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
