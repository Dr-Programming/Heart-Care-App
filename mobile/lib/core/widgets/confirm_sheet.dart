import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Asks the user to confirm something irreversible.
///
/// A bottom sheet rather than a dialog: the buttons land under the thumb, and
/// the target users are more likely to be on a large low-end phone held
/// one-handed. Returns true only on an explicit confirm — dismissing by tap or
/// swipe is a no.
///
/// ```dart
/// final ok = await ConfirmSheet.show(
///   context,
///   title: 'meds.deactivateTitle'.tr(),
///   message: 'meds.deactivateBody'.tr(),
///   confirmLabel: 'meds.deactivate'.tr(),
///   isDestructive: true,
/// );
/// ```
abstract final class ConfirmSheet {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? message,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.xl),
        ),
      ),
      builder: (BuildContext sheetContext) {
        final TextTheme text = Theme.of(sheetContext).textTheme;

        return SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: text.headlineMedium),
              if (message != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(message, style: text.bodyLarge),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: confirmLabel,
                variant: isDestructive
                    ? AppButtonVariant.secondary
                    : AppButtonVariant.primary,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: cancelLabel ?? 'common.cancel'.tr(),
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }
}
