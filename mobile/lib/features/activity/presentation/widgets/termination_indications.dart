import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// The indications to stop and rest during activity (FR-ACT-002).
///
/// Design decision 7: this is the one piece of guidance in the whole slice
/// whose absence could cause harm, so it sits on the activity screen itself,
/// before and during logging — not three taps into education. Copy mirrors
/// the approved wording exactly; nothing here is an improvised threshold.
class TerminationIndications extends StatelessWidget {
  const TerminationIndications({super.key});

  static const List<String> _itemKeys = <String>[
    'activity.termination.chestPain',
    'activity.termination.dizziness',
    'activity.termination.bloodPressure',
    'activity.termination.glucose',
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'activity.termination.title'.tr(),
                  style: text.titleMedium?.copyWith(color: AppColors.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final String key in _itemKeys)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('•  ${key.tr()}', style: text.bodyMedium),
            ),
        ],
      ),
    );
  }
}
