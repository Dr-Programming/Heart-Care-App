import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../error/failure.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Shown where a list would be if the list is empty.
///
/// Always offers the action that would fill it. A bare "No records" is a dead
/// end for a user who is not sure what the screen is for (FR-LOC-004).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders a [Failure] with a retry affordance.
///
/// Retry is deliberately withheld for failures that retrying cannot fix — a
/// rejected payload or an expired session will fail identically every time,
/// and offering the button teaches the user to distrust it.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.failure, this.onRetry, super.key});

  final Failure failure;
  final VoidCallback? onRetry;

  bool get _isRetryable => switch (failure) {
    NetworkFailure() || ServerFailure() || UnknownFailure() => true,
    ValidationFailure() ||
    InvalidCredentialsFailure() ||
    AccountLockedFailure() ||
    PhoneAlreadyRegisteredFailure() ||
    SessionExpiredFailure() => false,
  };

  @override
  Widget build(BuildContext context) {
    final bool offline = failure is NetworkFailure;

    return EmptyState(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: offline ? 'sync.offlineTitle'.tr() : 'errors.generic'.tr(),
      message: failure.message,
      actionLabel: onRetry != null && _isRetryable ? 'common.retry'.tr() : null,
      onAction: _isRetryable ? onRetry : null,
    );
  }
}

/// Dims and blocks the screen behind a spinner.
///
/// For operations the user must not interrupt — submitting a form, signing
/// out. Never for a plain list load; use a skeleton or an inline spinner there
/// so the app does not feel like it freezes on a slow connection.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    required this.isLoading,
    required this.child,
    this.message,
    super.key,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        if (isLoading)
          ColoredBox(
            color: AppColors.ink.withValues(alpha: 0.35),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(),
                  if (message != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      message!,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.surface),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
