import 'package:easy_localization/easy_localization.dart';

import '../../../../core/error/failure.dart';

/// Turns a [Failure] from the auth vertical into the exact sentence a Login
/// or Register screen shows above the form.
///
/// [Failure.message] means two different things depending on the subtype: a
/// client-constructed [NetworkFailure] carries a translation key (e.g.
/// `errors.offline`), while every server-originated failure carries English
/// text straight from the API — there is nothing to translate it against, so
/// it is shown verbatim.
String authFailureText(Failure failure) {
  return switch (failure) {
    AccountLockedFailure(:final minutesRemaining) =>
      minutesRemaining == null
          ? 'auth.errors.lockedNoTime'.tr()
          : 'auth.errors.locked'.tr(
              namedArgs: <String, String>{'minutes': '$minutesRemaining'},
            ),
    InvalidCredentialsFailure() => 'auth.errors.invalidCredentials'.tr(),
    PhoneAlreadyRegisteredFailure() => 'auth.errors.phoneTaken'.tr(),
    NetworkFailure(:final message) =>
      message.startsWith('errors.') ? message.tr() : message,
    ValidationFailure(:final message) => message,
    SessionExpiredFailure() ||
    ServerFailure() ||
    UnknownFailure() => 'errors.generic'.tr(),
  };
}
