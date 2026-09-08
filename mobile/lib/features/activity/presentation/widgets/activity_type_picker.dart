import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/activity_session.dart';

/// Picks one of the seven activity types (FR-ACT-003).
///
/// `FARMING` and `HOUSEHOLD` render as ordinary chips alongside the rest —
/// deliberately not folded into `OTHER` (design decision, M5 spec §4): for
/// many patients they are the day's exercise.
class ActivityTypePicker extends StatelessWidget {
  const ActivityTypePicker({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ActivityType value;
  final ValueChanged<ActivityType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final ActivityType type in ActivityType.values)
          ChoiceChip(
            label: Text('activity.type.${type.wire.toLowerCase()}'.tr()),
            selected: type == value,
            onSelected: (_) => onChanged(type),
            selectedColor: AppColors.accentBg,
            labelStyle: TextStyle(
              color: type == value ? AppColors.accent : AppColors.ink,
              fontWeight: type == value ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
      ],
    );
  }
}
