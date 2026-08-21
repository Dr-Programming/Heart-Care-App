import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Visual weight of a button, not its behaviour.
enum AppButtonVariant {
  /// Amber fill. One per screen — the thing the user came here to do.
  primary,

  /// Outlined. Secondary actions that still deserve a button.
  secondary,

  /// Text only, in the accent blue. Navigational, never destructive.
  text,

  /// Text only, in the critical red. Deleting and deactivating.
  danger,
}

/// The app's only button.
///
/// Two things it guarantees that a bare `FilledButton` does not:
///
///  * a 44dp minimum tap target (FR-LOC-006), which matters for users who are
///    unfamiliar with touchscreens;
///  * a loading state that keeps the button's width, so a form does not jump
///    when it is submitted.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    super.key,
  });

  final String label;

  /// Null disables the button. During [isLoading] the press is swallowed
  /// regardless, so a double-tap cannot submit a form twice.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  static const double _minTapTarget = 44;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? handler = isLoading ? null : onPressed;
    final Widget child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : _label(context);

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: handler,
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: handler,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: handler,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(_minTapTarget, _minTapTarget),
        ),
        child: child,
      ),
      AppButtonVariant.danger => TextButton(
        onPressed: handler,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.critical,
          minimumSize: const Size(_minTapTarget, _minTapTarget),
        ),
        child: child,
      ),
    };

    if (!expand ||
        variant == AppButtonVariant.text ||
        variant == AppButtonVariant.danger) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }

  Widget _label(BuildContext context) {
    if (icon == null) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(label),
      ],
    );
  }
}
