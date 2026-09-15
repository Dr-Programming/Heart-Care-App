import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class RangeToggle extends StatelessWidget {
  const RangeToggle({required this.selectedDays, required this.onChanged, super.key});

  final int selectedDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(int days, String labelKey) {
      final bool selected = days == selectedDays;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(days),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            alignment: Alignment.center,
            child: Text(
              labelKey.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: selected ? AppColors.surface : AppColors.ink,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      ),
      child: Row(
        children: <Widget>[
          segment(7, 'vitals.trend.range7'),
          segment(30, 'vitals.trend.range30'),
        ],
      ),
    );
  }
}
