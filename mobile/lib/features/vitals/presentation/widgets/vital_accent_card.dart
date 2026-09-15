import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/vital_type.dart';

const Map<VitalType, Color> vitalAccents = <VitalType, Color>{
  VitalType.bloodPressure: AppColors.critical,
  VitalType.glucose: AppColors.accent,
  VitalType.heartRate: AppColors.warning,
  VitalType.weight: AppColors.success,
  VitalType.cholesterol: AppColors.primary,
};

class VitalAccentCard extends StatelessWidget {
  const VitalAccentCard({
    required this.accent,
    required this.child,
    this.onTap,
    super.key,
  });

  final Color accent;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg + AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: child,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Container(width: 5, color: accent),
          ),
          onTap == null ? content : InkWell(onTap: onTap, child: content),
        ],
      ),
    );
  }
}

class VitalAccentHeader extends StatelessWidget {
  const VitalAccentHeader({
    required this.icon,
    required this.accent,
    required this.label,
    super.key,
  });

  final IconData icon;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
