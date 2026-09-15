import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../clinical/alert_evaluator.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class SeverityStyle {
  const SeverityStyle(this.foreground, this.background);

  final Color foreground;
  final Color background;

  static SeverityStyle of(Severity severity) => switch (severity) {
    Severity.none => const SeverityStyle(
      AppColors.success,
      AppColors.successBg,
    ),
    Severity.monitor => const SeverityStyle(
      AppColors.warning,
      AppColors.warningBg,
    ),
    Severity.urgent => const SeverityStyle(
      AppColors.critical,
      AppColors.criticalBg,
    ),
    Severity.emergency => const SeverityStyle(
      AppColors.surface,
      AppColors.critical,
    ),
  };
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.severity, this.label, super.key});

  const StatusChip.flagged({required bool flagged, String? label, Key? key})
    : this(
        severity: flagged ? Severity.monitor : Severity.none,
        label: label,
        key: key,
      );

  final Severity severity;

  final String? label;

  @override
  Widget build(BuildContext context) {
    final SeverityStyle style = SeverityStyle.of(severity);
    final String text = label ?? 'clinical.severity.${severity.name}'.tr();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: style.foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}
