import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
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

  static VitalType typeFromRoute(GoRouterState routeState) =>
      VitalType.fromWire(routeState.pathParameters['type']!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VitalSeriesResult> state = ref.watch(
      vitalsTrendControllerProvider(type),
    );
    final VitalsTrendController controller = ref.read(
      vitalsTrendControllerProvider(type).notifier,
    );

    return AppScaffold(
      title: '${vitalDescriptors[type]!.labelKey.tr()} — ${'vitals.trend.title'.tr()}',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: RangeToggle(
              selectedDays: controller.windowDays,
              onChanged: controller.setWindowDays,
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace _) => ErrorView(
                failure: error is Failure ? error : UnknownFailure(error.toString()),
                onRetry: () => controller.setWindowDays(controller.windowDays),
              ),
              data: (VitalSeriesResult result) => switch (result) {
                VitalTrendData(:final series, :final readings) => _TrendBody(
                  series: series,
                  readings: readings,
                ),
                VitalInsufficientData(:final readings) => _InsufficientBody(
                  readings: readings,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBody extends StatelessWidget {
  const _TrendBody({required this.series, required this.readings});

  final List<ChartSeries> series;
  final List<VitalReading> readings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      children: <Widget>[
        TrendChart(series: series),
        const SizedBox(height: AppSpacing.lg),
        for (final ChartSeries s in series) ...<Widget>[
          SectionCard(
            title: series.length > 1 ? s.label.tr() : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _Stat(label: 'vitals.trend.min'.tr(), value: _min(s)),
                _Stat(label: 'vitals.trend.max'.tr(), value: _max(s)),
                _Stat(label: 'vitals.trend.average'.tr(), value: _average(s)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  double _min(ChartSeries s) =>
      s.points.map((MapEntry<DateTime, double> e) => e.value).reduce((a, b) => a < b ? a : b);
  double _max(ChartSeries s) =>
      s.points.map((MapEntry<DateTime, double> e) => e.value).reduce((a, b) => a > b ? a : b);
  double _average(ChartSeries s) {
    final List<double> values = s.points.map((MapEntry<DateTime, double> e) => e.value).toList();
    return values.reduce((a, b) => a + b) / values.length;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value.toStringAsFixed(1), style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _InsufficientBody extends StatelessWidget {
  const _InsufficientBody({required this.readings});

  final List<VitalReading> readings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[
              Text(
                'vitals.trend.insufficientTitle'.tr(),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'vitals.trend.insufficientBody'.tr(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        for (final VitalReading reading in readings)
          ReadingRow(reading: reading, localeCode: context.locale.languageCode),
      ],
    );
  }
}
