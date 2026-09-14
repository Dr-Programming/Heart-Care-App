import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class WizardProgress extends StatelessWidget {
  const WizardProgress({
    required this.step,
    required this.totalSteps,
    super.key,
  });

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (var i = 0; i < totalSteps; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == step ? AppColors.ink : AppColors.border,
            ),
          ),
        ],
      ],
    );
  }
}
