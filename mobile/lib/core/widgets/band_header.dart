import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Title block for the header band of a pushed screen: a back arrow, the
/// title and an optional subtitle. Same layout as the medication form, so
/// every screen opened from a tab looks the same.
class BandHeader extends StatelessWidget {
  const BandHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = true,
    this.onBack,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// False hides the arrow even when the screen could go back.
  final bool showBack;

  /// Replaces the default back action; the arrow always shows when set.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool hasBack =
        onBack != null || (showBack && Navigator.of(context).canPop());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (hasBack) ...<Widget>[
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(title, style: text.headlineMedium),
              ),
            ),
            ?trailing,
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          // One line, shrunk if needed, so a long subtitle never makes this
          // header taller than the others.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle!,
              maxLines: 1,
              style: text.bodyMedium?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ],
    );
  }
}
