import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ComorbidityChips extends StatelessWidget {
  const ComorbidityChips({
    required this.curated,
    required this.selected,
    required this.onChanged,
    this.allowOther = false,
    this.otherController,
    super.key,
  });

  final List<(String key, String label)> curated;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool allowOther;
  final TextEditingController? otherController;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (final (key, label) in curated)
            FilterChip(
              label: Text(label),
              selected: selected.contains(key),
              selectedColor: AppColors.ink,
              onSelected: (bool value) {
                final next = Set<String>.from(selected);
                value ? next.add(key) : next.remove(key);
                onChanged(next);
              },
            ),
          if (allowOther)
            SizedBox(
              width: 160,
              child: TextField(
                controller: otherController,
                decoration: const InputDecoration(hintText: 'Other'),
              ),
            ),
        ],
      ),
    );
  }
}
