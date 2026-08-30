import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A titled block of content.
///
/// The unit every screen is built from: one card per idea, an optional action
/// in the corner. Use it instead of Material's `Card` so elevation, radius and
/// padding stay identical across five people's screens.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.action,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    super.key,
  });

  final Widget child;
  final String? title;

  /// Usually an `AppButton` with `AppButtonVariant.text`.
  final Widget? action;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null || action != null) ...<Widget>[
            Row(
              children: <Widget>[
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  )
                else
                  const Spacer(),
                ?action,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// One number with its label and unit — a blood pressure, a weight, an
/// adherence percentage.
///
/// [trailing] is where a `StatusChip` goes. [value] is rendered large because
/// on the dashboard it is the only thing a user scanning quickly will read.
class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.icon,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String label;

  /// Already formatted. Pass "—" when there is no reading yet rather than
  /// hiding the tile: an empty slot tells the user what they could record.
  final String value;
  final String? unit;

  /// Usually a relative timestamp — "2 hours ago".
  final String? caption;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    final Widget body = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: text.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(value, style: text.headlineMedium),
                  if (unit != null) ...<Widget>[
                    const SizedBox(width: AppSpacing.xs),
                    Text(unit!, style: text.bodySmall),
                  ],
                ],
              ),
              if (caption != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(caption!, style: text.labelSmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );

    if (onTap == null) return body;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: body,
      ),
    );
  }
}
