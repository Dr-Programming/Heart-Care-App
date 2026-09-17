import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../domain/entities/vital_reading.dart';
import '../../domain/entities/vital_series.dart';
import '../../domain/entities/vital_type.dart';
import '../../domain/vital_descriptors.dart';
import '../controllers/vitals_trend_controller.dart';
import '../widgets/range_toggle.dart';
import '../widgets/reading_row.dart';
import '../widgets/trend_chart.dart';

class VitalsTrendScreen extends ConsumerWidget {
  const VitalsTrendScreen({required this.type, super.key});

  final VitalType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int windowDays = ref.watch(windowDaysProvider(type));
    final AsyncValue<VitalsTrendData> data = ref.watch(trendDataProvider(type));

    return AppScaffold(
      title: vitalDescriptors[type]!.labelKey.tr(),
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          RangeToggle(
            windowDays: windowDays,
            onChanged: (int days) =>
                ref.read(windowDaysProvider(type).notifier).state = days,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace st) => EmptyState(
                title: 'errors.generic'.tr(),
                icon: Icons.error_outline_rounded,
              ),
              data: (VitalsTrendData d) => d.insufficientData
                  ? _InsufficientData(readings: d.readingsInWindow)
                  : _TrendView(series: d.series),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsufficientData extends StatelessWidget {
  const _InsufficientData({required this.readings});

  final List<VitalReading> readings;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return EmptyState(
        icon: Icons.show_chart,
        title: 'vitals.trendEmptyTitle'.tr(),
      );
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'vitals.trendInsufficientData'.tr(
              namedArgs: <String, String>{'count': '$minReadingsForTrend'},
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: readings.length,
            separatorBuilder: (BuildContext context, int i) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int i) =>
                ReadingRow(reading: readings[i]),
          ),
        ),
      ],
    );
  }
}

class _TrendView extends StatelessWidget {
  const _TrendView({required this.series});

  final List<VitalSeries> series;

  static const List<Color> _seriesColors = <Color>[
    AppColors.accent,
    AppColors.primary,
  ];

  @override
  Widget build(BuildContext context) {
    final List<ChartSeries> chartSeries = <ChartSeries>[
      for (int i = 0; i < series.length; i++)
        ChartSeries(
          series: series[i],
          color: _seriesColors[i % _seriesColors.length],
        ),
    ];

    return ListView(
      children: <Widget>[
        TrendChart(series: chartSeries),
        const SizedBox(height: 16),
        for (final VitalSeries s in series)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'vitals.seriesSummary'.tr(
                namedArgs: <String, String>{
                  'key': 'vitals.field.${s.key}'.tr(),
                  'min': s.min.toStringAsFixed(1),
                  'max': s.max.toStringAsFixed(1),
                  'avg': s.avg.toStringAsFixed(1),
                },
              ),
            ),
          ),
      ],
    );
  }
}
