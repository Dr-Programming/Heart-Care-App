import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/clinical/activity_guidance.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// What to do and avoid today, from the check-in.
class ActivityGuidanceCard extends StatelessWidget {
  const ActivityGuidanceCard({required this.guidance, super.key});

  final ActivityGuidance guidance;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SectionCard(
      key: const Key('activityGuidanceCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('activityGuidance.title'.tr(), style: text.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(guidance.messageKey.tr(), style: text.bodyMedium),
          if (guidance.good.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text('activityGuidance.good'.tr(), style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            _ActivityChips(types: guidance.good, good: true),
          ],
          if (guidance.avoid.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text('activityGuidance.avoid'.tr(), style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            _ActivityChips(types: guidance.avoid, good: false),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'activityGuidance.note'.tr(),
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ActivityChips extends StatelessWidget {
  const _ActivityChips({required this.types, required this.good});

  final List<String> types;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final Color color = good ? AppColors.success : AppColors.critical;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final String type in types)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: good ? AppColors.successBg : AppColors.criticalBg,
              borderRadius: BorderRadius.circular(AppSpacing.xl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  good ? Icons.check_rounded : Icons.close_rounded,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'activity.type.$type'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.ink),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
