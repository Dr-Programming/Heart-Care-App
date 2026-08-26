import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/dose_log.dart';

/// Three inline chips — Taken / Missed / Skipped — one tap logs a dose
/// (Decision 6).
class StatusSelector extends StatelessWidget {
  const StatusSelector({required this.onSelected, super.key});

  final ValueChanged<DoseStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Chip(label: 'meds.status.taken'.tr(), color: AppColors.success, onTap: () => onSelected(DoseStatus.taken)),
        const SizedBox(width: AppSpacing.xs),
        _Chip(label: 'meds.status.missed'.tr(), color: AppColors.critical, onTap: () => onSelected(DoseStatus.missed)),
        const SizedBox(width: AppSpacing.xs),
        _Chip(label: 'meds.status.skipped'.tr(), color: AppColors.textSecondary, onTap: () => onSelected(DoseStatus.skipped)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.lg),
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(AppSpacing.lg),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
