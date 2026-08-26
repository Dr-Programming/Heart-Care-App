import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

class TimeListField extends StatelessWidget {
  const TimeListField({required this.times, required this.onChanged, super.key});

  final List<String> times;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
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
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text('common.add'.tr()),
              onPressed: () => _pickTime(context),
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
