import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../clinical/alert_evaluator.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Colours for one clinical severity, kept in one place so a "watch" reading
/// looks identical on the vitals list, the symptom history and the home card.
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

/// A clinical status pill.
///
/// Colour alone never carries the meaning — the label is always present.
/// Bright outdoor screens wash out hue (FR-LOC-008), and colour-blind users
/// would otherwise get nothing.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.severity, this.label, super.key});

  /// Reads the status straight off the server's `flagged` boolean, for lists
  /// that have no finer signal than "flagged or not".
  const StatusChip.flagged({required bool flagged, String? label, Key? key})
    : this(
        severity: flagged ? Severity.monitor : Severity.none,
        label: label,
        key: key,
      );

  final Severity severity;

  /// Overrides the default translated label.
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
