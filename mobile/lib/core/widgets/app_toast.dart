import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A short, floating message — the app's equivalent of an Android toast.
///
/// Built on `SnackBar` rather than a toast plugin so it inherits the app theme
/// and stays inside the Flutter tree (it is reachable from widget tests, and
/// it respects the bottom navigation bar).
///
/// The current message is dismissed first, so tapping a blocked field over and
/// over re-shows one message instead of queueing a backlog that keeps
/// reappearing long after the patient has stopped tapping.
void showAppToast(
  BuildContext context,
  String message, {
  IconData? icon,
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.critical : AppColors.ink,
        duration: duration,
        margin: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
        content: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 20, color: AppColors.surface),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.surface),
              ),
            ),
          ],
        ),
      ),
    );
}
