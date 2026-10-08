import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'cards.dart';

/// Opens the "Staying physically active" topic in Learn, so the patient does
/// not have to find it there themselves.
class HealthyExercisesLink extends StatelessWidget {
  const HealthyExercisesLink({super.key});

  /// The id of the exercise topic in `assets/content/topics_*.json`.
  static const String topicId = 'exercise';

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SectionCard(
      key: const Key('healthyExercisesLink'),
      onTap: () => context.goNamed(
        AppRoutes.learnTopic,
        pathParameters: <String, String>{'topic': topicId},
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              size: 18,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'activityGuidance.learnTitle'.tr(),
                  style: text.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text('activityGuidance.learnBody'.tr(), style: text.bodyMedium),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
