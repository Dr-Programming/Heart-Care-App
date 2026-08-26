import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/dose_log.dart';

/// Taken / Missed / Skipped chips — one tap logs a dose (Decision 6). Laid
/// out in a `Wrap`, not a `Row`, so the three chips can flow onto a second
/// line instead of overflowing when labels run long (longer Amharic
/// translations, a larger accessibility text-scale factor, or a narrow
/// device) — see the layout note in [build].
class StatusSelector extends StatelessWidget {
  const StatusSelector({required this.onSelected, super.key});

  final ValueChanged<DoseStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    // A `Wrap` (rather than a `Row`) lets the three chips flow onto a second
    // line instead of demanding a single line's worth of unbounded width —
    // a plain `Row` lays out non-flexible children at their full intrinsic
    // width regardless of the space actually available, which is what
    // produces a hard `RenderFlex` overflow once labels are long enough
    // (longer Amharic translations, a larger text-scale factor, or a
    // narrower device than the Figma reference frame).
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _Chip(label: 'meds.status.taken'.tr(), color: AppColors.success, onTap: () => onSelected(DoseStatus.taken)),
        _Chip(label: 'meds.status.missed'.tr(), color: AppColors.critical, onTap: () => onSelected(DoseStatus.missed)),
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
        constraints: const BoxConstraints(minHeight: AppSpacing.xxl),
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
