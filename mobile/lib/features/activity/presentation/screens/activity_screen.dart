import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/activity_summary.dart';
import '../../domain/entities/activity_entry.dart';
import '../controllers/activity_overview_controller.dart';

/// This week's activity against the 150-minute goal, then every entry.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ActivityOverview> state = ref.watch(
      activityOverviewControllerProvider,
    );

    return AppScaffold.banded(
      showBack: false,
      scrollable: false,
      bandChild: BandHeader(
        title: 'activity.title'.tr(),
        subtitle: 'activity.subtitle'.tr(),
      ),
      bottomBar: AppButton(
        label: 'activity.logCta'.tr(),
        icon: Icons.add_rounded,
        onPressed: () => context.pushNamed(AppRoutes.activityLog),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) => ErrorView(
          failure: error is Failure ? error : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(activityOverviewControllerProvider),
        ),
        data: (ActivityOverview overview) => ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: <Widget>[
            WeeklyActivityCard(summary: overview.summary),
            const SizedBox(height: AppSpacing.lg),
            const HealthyExercisesLink(),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'activity.historyTitle'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (overview.entries.isEmpty)
              EmptyState(
                icon: Iconsax.activity,
                title: 'activity.emptyTitle'.tr(),
                message: 'activity.emptyBody'.tr(),
              )
            else
              for (final ActivityEntry entry in overview.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _EntryTile(entry: entry),
                ),
          ],
        ),
      ),
    );
  }
}

/// Minutes this week against the goal; shared with the Home card.
class WeeklyActivityCard extends StatelessWidget {
  const WeeklyActivityCard({required this.summary, super.key});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool reached =
        summary.weekMinutes >= ActivitySummary.weeklyGoalMinutes;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('activity.thisWeek'.tr(), style: text.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('${summary.weekMinutes}', style: text.headlineLarge),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'activity.ofGoal'.tr(
                  namedArgs: <String, String>{
                    'goal': '${ActivitySummary.weeklyGoalMinutes}',
                  },
                ),
                style: text.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            child: LinearProgressIndicator(
              value: summary.weekProgress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceAlt,
              color: reached ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            reached
                ? 'activity.goalReached'.tr()
                : 'activity.todaySummary'.tr(
                    namedArgs: <String, String>{
                      'today': '${summary.todayMinutes}',
                      'days': '${summary.activeDaysThisWeek}',
                    },
                  ),
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String when = DateFormatter.displayDateTime(
      entry.measuredAt.toLocal(),
      context.locale.languageCode,
    );
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.activity,
              size: 20,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'activity.type.${entry.type.wire}'.tr(),
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${'activity.intensity.${entry.intensity.wire}'.tr()} · $when',
                  style: text.bodySmall,
                ),
                if (entry.note != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(entry.note!, style: text.bodySmall),
                ],
              ],
            ),
          ),
          Text(
            'activity.minutesShort'.tr(
              namedArgs: <String, String>{
                'minutes': '${entry.durationMinutes}',
              },
            ),
            style: text.titleMedium,
          ),
        ],
      ),
    );
  }
}
