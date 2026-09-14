import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum AppButtonVariant {

  primary,

  secondary,

  text,

  danger,
}

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
