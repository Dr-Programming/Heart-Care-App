import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Horizontal row of selectable pills — selected pill filled `ink`, others
/// outlined. Mirrors the language / choice controls on Figma frame `368:632`.
class ChoicePills<T> extends StatelessWidget {
  const ChoicePills({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < values.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: i == values.length - 1 ? 0 : AppSpacing.md),
              child: _Pill(
                text: label(values[i]),
                selected: values[i] == selected,
                onTap: () => onChanged(values[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.selected, required this.onTap});

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
      child: Container(
        height: AppSpacing.pillHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          border: Border.all(color: selected ? AppColors.ink : AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: selected ? AppColors.surface : AppColors.ink,
              ),
        ),
      ),
    );
  }
}
