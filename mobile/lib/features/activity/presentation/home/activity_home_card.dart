import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/shell/home_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/activity_summary.dart';
import '../controllers/activity_overview_controller.dart';

HomeCard activityHomeCard() =>
    const HomeCard(id: 'activity', order: 160, builder: _ActivityCard.build);

abstract final class _ActivityCard {
  static Widget build(BuildContext context) => const _Card();
}

class _Card extends ConsumerWidget {
  const _Card();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ActivityOverview> state = ref.watch(
      activityOverviewControllerProvider,
    );
    final TextTheme text = Theme.of(context).textTheme;

    return AccentCard(
      accent: AppColors.success,
      icon: Iconsax.activity,
      title: 'activity.title'.tr(),
      action: AppButton(
        label: 'activity.logShort'.tr(),
        variant: AppButtonVariant.text,
        expand: false,
        onPressed: () => context.pushNamed(AppRoutes.activityLog),
      ),
      child: state.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (Object _, StackTrace _) =>
            Text('common.noValue'.tr(), style: text.bodyMedium),
        data: (ActivityOverview overview) {
          final ActivitySummary summary = overview.summary;
          return InkWell(
            onTap: () => context.pushNamed(AppRoutes.activity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'activity.homeSummary'.tr(
                    namedArgs: <String, String>{
                      'minutes': '${summary.weekMinutes}',
                      'goal': '${ActivitySummary.weeklyGoalMinutes}',
                    },
                  ),
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: LinearProgressIndicator(
                    value: summary.weekProgress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceAlt,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
