

sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure(super.message);
}

final class AccountLockedFailure extends Failure {
  const AccountLockedFailure(super.message, {this.minutesRemaining});
  final int? minutesRemaining;
}

final class PhoneAlreadyRegisteredFailure extends Failure {
  const PhoneAlreadyRegisteredFailure(super.message);
}

final class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure(super.message);
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

final RegExp _lockoutPattern = RegExp(r'(\d+)\s+minute');

int? parseLockoutMinutes(String message) {
  final RegExpMatch? match = _lockoutPattern.firstMatch(message);
  return match == null ? null : int.tryParse(match.group(1)!);
}
