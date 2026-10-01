import '../security_question.dart';

/// What happened to a PIN change or reset the patient just made.
enum PinChangeOutcome {
  /// The server accepted it; it is in effect everywhere.
  applied,

  /// In effect on this phone; it reaches the server at the next sync.
  queued,
}

/// The result of sending a queued PIN change to the server.
enum PinSyncResult {
  nothingPending,
  applied,

  /// The server could not take it yet (offline, down, or locked); it waits.
  kept,

  /// The server refused it because the PIN, or the answers, changed elsewhere
  /// first. The change was dropped and the patient signed out.
  conflict,
}

/// Why the app signed the patient out on its own.
enum SignOutReason { pinChangedElsewhere }

/// PIN change and forgot-PIN, both of which work offline.
///
/// The rule is the same as sign-in: when the server can be reached it
/// decides; when it can't, the phone checks the PIN (or the security answers)
/// itself, applies the change locally, and queues it. The queued change is
/// sent at the next sync and the server checks it again. If the PIN was
/// changed elsewhere in the meantime, the server's PIN wins.
abstract interface class PinRepository {
  /// Changes the PIN of the signed-in patient.
  Future<PinChangeOutcome> changePin({
    required String currentPin,
    required String newPin,
  });

  /// The three questions to ask on the Forgot PIN screen for [phone].
  Future<List<SecurityQuestion>> recoveryQuestions(String phone);

  /// Forgot PIN: sets [newPin] when [answers] are right, and signs in.
  Future<PinChangeOutcome> resetPin({
    required String phone,
    required List<SecurityAnswer> answers,
    required String newPin,
  });

  /// Sets or replaces the signed-in patient's answers. Needs a connection.
  Future<void> setSecurityAnswers({
    required String currentPin,
    required List<SecurityAnswer> answers,
  });

  /// Whether the signed-in patient has security questions on the server:
  /// null when that can't be checked right now (offline or unreachable).
  Future<bool?> securityQuestionsStatus();

  /// The questions this phone has answers for (for the signed-in patient).
  Future<List<SecurityQuestion>> configuredQuestions();

  Future<bool> hasPendingPinChange();

  /// Sends the queued change, if any. Called at the start of every sync.
  Future<PinSyncResult> flushPendingPinChange();

  /// Why the app last signed the patient out by itself, once; then null.
  SignOutReason? takeSignOutReason();
}
