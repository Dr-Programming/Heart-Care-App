import 'package:flutter/material.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// A row of tappable pills, one per [AppLanguage], each labelled in its own
/// script — used by the first-run language picker and by Register's
/// preferred-language field.
class LanguageChoice extends StatelessWidget {
  const LanguageChoice({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final AppLanguage language in AppLanguage.values) ...<Widget>[
          if (language != AppLanguage.values.first)
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _Pill(
              language: language,
              selected: language == selected,
              onTap: () => onChanged(language),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: Container(
        height: AppSpacing.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.borderStrong,
          ),
        ),
        child: Text(
          language.nativeLabel,
          style: text.titleMedium?.copyWith(
            color: selected ? AppColors.surface : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
