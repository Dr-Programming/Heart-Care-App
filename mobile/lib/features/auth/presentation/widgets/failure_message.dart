import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Turns a `Failure` into a sentence the patient can act on.
///
/// A lockout is phrased as a wait, never as a wrong PIN — re-prompting for the
/// PIN during a lockout invites the user to keep guessing when guessing cannot
/// possibly work.
String failureText(Failure failure) => switch (failure) {
      AccountLockedFailure(:final int? minutesRemaining) =>
        minutesRemaining == null
            ? 'errors.lockedNoTime'.tr()
            : 'errors.locked'.tr(namedArgs: <String, String>{
                'minutes': '$minutesRemaining',
              }),
      InvalidCredentialsFailure() => 'errors.invalidCredentials'.tr(),
      PhoneAlreadyRegisteredFailure() => 'errors.phoneTaken'.tr(),
      NetworkFailure(:final String message) =>
        message.startsWith('errors.') ? message.tr() : message,
      ValidationFailure(:final String message) => message,
      SessionExpiredFailure() => 'errors.invalidCredentials'.tr(),
      ServerFailure() || UnknownFailure() => 'errors.generic'.tr(),
    };

class FailureMessage extends StatelessWidget {
  const FailureMessage(this.failure, {super.key});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.criticalBg,
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: Text(
        failureText(failure),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.critical),
      ),
    );
  }
}
