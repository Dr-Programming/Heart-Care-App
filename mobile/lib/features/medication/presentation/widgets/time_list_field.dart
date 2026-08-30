import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class TimeListField extends StatelessWidget {
  const TimeListField({required this.times, required this.onChanged, super.key});

  final List<String> times;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    // Pill roundness/padding matches the app's other selectable-chip
    // widgets (`StatusChip`, `StatusSelector`'s `_Chip`) rather than a new
    // radius, per the M3 Figma-fidelity restyle (frame 368:2706): this is a
    // visual-only change, so the `Wrap`/chip-list mechanics that fixed the
    // original overflow bug (see medication_widgets_test.dart) are untouched.
    final OutlinedBorder chipShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.lg),
    );
    const EdgeInsets chipPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('meds.form.scheduleTimes'.tr(), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final String time in times)
              InputChip(
                label: Text(time),
                onDeleted: () => onChanged(times.where((String t) => t != time).toList()),
                backgroundColor: AppColors.surfaceAlt,
                side: const BorderSide(color: AppColors.border),
                shape: chipShape,
                padding: chipPadding,
                labelStyle: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600),
                deleteIconColor: AppColors.textSecondary,
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: AppColors.accent),
              label: Text('common.add'.tr()),
              onPressed: () => _pickTime(context),
              backgroundColor: AppColors.accentBg,
              side: const BorderSide(color: AppColors.accent),
              shape: chipShape,
              padding: chipPadding,
              labelStyle: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    final String formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (times.contains(formatted)) return;
    onChanged(<String>[...times, formatted]..sort());
  }
}
