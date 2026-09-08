import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/clinical/alert_evaluator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

/// Every severity comes with an action (design decision 3, FR-SYM-010,
/// FR-DEC-009). `EMERGENCY` renders completely differently from the other
/// three — full-width, solid critical red, no chip — because this is the
/// one place in the app where interrupting the user is correct, and it
/// must not be missable by scrolling past.
class SeverityResultBanner extends StatelessWidget {
  const SeverityResultBanner({required this.severity, super.key});

  final Severity severity;

  @override
  Widget build(BuildContext context) {
    return severity == Severity.emergency
        ? _EmergencyBanner(action: actionKeyFor(severity).tr())
        : _StandardBanner(
            severity: severity,
            action: actionKeyFor(severity).tr(),
          );
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.critical,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.warning_rounded,
                color: AppColors.surface,
                size: 28,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'clinical.severity.emergency'.tr(),
                  style: text.headlineMedium?.copyWith(
                    color: AppColors.surface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            action,
            style: text.bodyLarge?.copyWith(color: AppColors.surface),
          ),
        ],
      ),
    );
  }
}

class _StandardBanner extends StatelessWidget {
  const _StandardBanner({required this.severity, required this.action});

  final Severity severity;
  final String action;

  @override
  Widget build(BuildContext context) {
    final SeverityStyle style = SeverityStyle.of(severity);
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StatusChip(severity: severity),
          const SizedBox(height: AppSpacing.sm),
          Text(
            action,
            style: text.bodyMedium?.copyWith(color: style.foreground),
          ),
        ],
      ),
    );
  }
}
