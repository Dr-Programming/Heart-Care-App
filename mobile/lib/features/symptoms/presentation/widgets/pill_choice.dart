import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class PillChoice extends StatelessWidget {
  const PillChoice({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<(String value, String label)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final (String optionValue, String label) in options) ...<Widget>[
          if (optionValue != options.first.$1)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: () => onChanged(optionValue),
              borderRadius: BorderRadius.circular(AppSpacing.md),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == optionValue
                      ? AppColors.accent
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppSpacing.md),
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: value == optionValue ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
