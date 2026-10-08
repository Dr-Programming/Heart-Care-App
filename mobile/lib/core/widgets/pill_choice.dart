import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// One choice out of a few, as a row of pills. With [wrap], the pills keep
/// their natural width and flow onto more lines, for longer option lists.
class PillChoice extends StatelessWidget {
  const PillChoice({
    required this.options,
    required this.value,
    required this.onChanged,
    this.wrap = false,
    super.key,
  });

  final List<(String value, String label)> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    if (wrap) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: <Widget>[
          for (final (String optionValue, String label) in options)
            _pill(
              context,
              optionValue,
              label,
              horizontalPadding: AppSpacing.lg,
            ),
        ],
      );
    }
    return Row(
      children: <Widget>[
        for (final (String optionValue, String label) in options) ...<Widget>[
          if (optionValue != options.first.$1)
            const SizedBox(width: AppSpacing.sm),
          Expanded(child: _pill(context, optionValue, label)),
        ],
      ],
    );
  }

  Widget _pill(
    BuildContext context,
    String optionValue,
    String label, {
    double horizontalPadding = 0,
  }) {
    final bool selected = value == optionValue;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => onChanged(optionValue),
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: horizontalPadding,
          ),
          alignment: horizontalPadding == 0 ? Alignment.center : null,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppSpacing.xl),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: selected ? Colors.white : AppColors.ink),
          ),
        ),
      ),
    );
  }
}
