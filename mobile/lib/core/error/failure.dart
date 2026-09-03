/// Everything the UI needs to know about a request that did not succeed.
///
/// Repositories throw these; Riverpod's `AsyncValue.guard` captures them into
/// `AsyncError`, and screens switch on the subtype. Deliberately a sealed class
/// so a missed case is a compile error rather than a silent fallthrough.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// No usable connection, or the request timed out. Retryable.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// 400 — the server rejected the body. `message` is `field: reason` pairs
/// joined by `; ` and sorted.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// 401 on login — deliberately identical for an unknown phone and a wrong PIN.
final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure(super.message);
}

/// 423 — five consecutive failures locked the account for 15 minutes.
/// Must be surfaced as "wait", never as "wrong PIN", and must not be retried
/// on a timer.
final class AccountLockedFailure extends Failure {
  const AccountLockedFailure(super.message, {this.minutesRemaining});
  final int? minutesRemaining;
}

/// 409 on register.
final class PhoneAlreadyRegisteredFailure extends Failure {
  const PhoneAlreadyRegisteredFailure(super.message);
}

/// 401 on an authenticated call — the 7-day token expired or was rejected.
/// There is no refresh endpoint, so the only cure is signing in again.
final class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure(super.message);
}

/// 500 — the only transient server condition worth retrying.
final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

final RegExp _lockoutPattern = RegExp(r'(\d+)\s+minute');

/// Pulls the remaining minutes out of a 423 message.
///
/// The API sends "Try again in 15 minutes." but switches to the singular
/// "Try again in 1 minute." on the final minute — matching on "minutes"
/// would break exactly when the user is one minute from getting back in.
int? parseLockoutMinutes(String message) {
  final RegExpMatch? match = _lockoutPattern.firstMatch(message);
  return match == null ? null : int.tryParse(match.group(1)!);
}
