import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/bp_trend.dart';
import '../controllers/bp_trend_controller.dart';
import '../widgets/bp_trend_chart.dart';
import '../widgets/range_toggle.dart';

class BpTrendScreen extends ConsumerWidget {
  const BpTrendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BpTrend> state = ref.watch(bpTrendControllerProvider);
    final BpTrendController controller = ref.read(
      bpTrendControllerProvider.notifier,
    );

    return AppScaffold.banded(
      showBack: false,
      scrollable: false,
      bandChild: BandHeader(
        title: 'vitals.bpTrend.title'.tr(),
        subtitle: 'vitals.bpTrend.subtitle'.tr(
          namedArgs: <String, String>{'days': '${controller.windowDays}'},
        ),
      ),
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
                failure: error is Failure
                    ? error
                    : UnknownFailure(error.toString()),
                onRetry: () => controller.setWindowDays(controller.windowDays),
              ),
              data: (BpTrend trend) => trend.hasData
                  ? _TrendBody(trend: trend, windowDays: controller.windowDays)
                  : EmptyState(
                      icon: Icons.monitor_heart_outlined,
                      title: 'vitals.bpTrend.emptyTitle'.tr(),
                      message: 'vitals.bpTrend.emptyBody'.tr(),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBody extends StatelessWidget {
  const _TrendBody({required this.trend, required this.windowDays});

  final BpTrend trend;
  final int windowDays;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double? change = trend.systolicChange;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'vitals.bpTrend.average'.tr(
                        namedArgs: <String, String>{'days': '$windowDays'},
                      ),
                      style: text.bodySmall,
                    ),
                  ),
                  _StatusBadge(status: trend.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(
                    trend.averageSystolic!.toStringAsFixed(0),
                    style: text.headlineLarge?.copyWith(fontSize: 36),
                  ),
                  Text(
                    ' /${trend.averageDiastolic!.toStringAsFixed(0)}',
                    style: text.headlineMedium,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('mmHg', style: text.bodySmall),
                ],
              ),
              if (change != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'vitals.bpTrend.change'.tr(
                    namedArgs: <String, String>{
                      'change': change > 0
                          ? '↑ +${change.toStringAsFixed(0)}'
                          : change < 0
                          ? '↓ ${change.toStringAsFixed(0)}'
                          : '0',
                    },
                  ),
                  style: text.bodySmall?.copyWith(
                    color: change > 0 ? AppColors.warning : AppColors.success,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                'vitals.bpTrend.targetLabel'.tr(
                  namedArgs: <String, String>{
                    'sys': trend.targetSystolic.toStringAsFixed(0),
                    'dia': trend.targetDiastolic.toStringAsFixed(0),
                  },
                ),
                style: text.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionCard(
          child: BpTrendChart(trend: trend, windowDays: windowDays),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (trend.daysAboveTarget > 0)
          _AdviceCard(
            severity: trend.status == BpTrendStatus.critical
                ? Severity.emergency
                : Severity.monitor,
            title: 'vitals.bpTrend.daysAbove'.tr(
              namedArgs: <String, String>{
                'above': '${trend.daysAboveTarget}',
                'days': '${trend.daysWithReadings}',
              },
            ),
            body: trend.status == BpTrendStatus.critical
                ? 'vitals.bpTrend.criticalAdvice'.tr()
                : 'vitals.bpTrend.discuss'.tr(),
          )
        else
          _AdviceCard(
            severity: Severity.none,
            title: 'vitals.bpTrend.allOnTarget'.tr(),
            body: 'vitals.bpTrend.keepGoing'.tr(),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BpTrendStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      BpTrendStatus.critical => StatusChip(
        severity: Severity.emergency,
        label: 'vitals.bpTrend.status.critical'.tr(),
      ),
      BpTrendStatus.aboveTarget => StatusChip(
        severity: Severity.monitor,
        label: 'vitals.bpTrend.status.aboveTarget'.tr(),
      ),
      BpTrendStatus.onTarget => StatusChip(
        severity: Severity.none,
        label: 'vitals.bpTrend.status.onTarget'.tr(),
      ),
      BpTrendStatus.noData => const SizedBox.shrink(),
    };
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({
    required this.severity,
    required this.title,
    required this.body,
  });

  final Severity severity;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final SeverityStyle style = SeverityStyle.of(severity);
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            severity == Severity.none
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            color: style.foreground,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: text.titleSmall?.copyWith(color: style.foreground),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: text.bodySmall?.copyWith(color: style.foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
