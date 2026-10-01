import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/domain/repositories/pin_repository.dart';
import 'package:libu_care/features/auth/domain/security_question.dart';

/// Scriptable [PinRepository] for screen tests: set an outcome or an error,
/// then assert on what the screen sent.
class FakePinRepository implements PinRepository {
  PinChangeOutcome outcome = PinChangeOutcome.applied;
  Failure? error;
  List<SecurityQuestion> questions = const <SecurityQuestion>[
    SecurityQuestion.firstSchool,
    SecurityQuestion.childhoodFriend,
    SecurityQuestion.favoriteTeacher,
  ];
  List<SecurityQuestion> configured = const <SecurityQuestion>[];

  /// What [securityQuestionsStatus] answers: null means "unknown" (offline).
  bool? status;

  final List<({String currentPin, String newPin})> changes = <({String currentPin, String newPin})>[];
  final List<({String phone, List<SecurityAnswer> answers, String newPin})> resets =
      <({String phone, List<SecurityAnswer> answers, String newPin})>[];
  final List<({String currentPin, List<SecurityAnswer> answers})> answerSets =
      <({String currentPin, List<SecurityAnswer> answers})>[];
  final List<String> questionLookups = <String>[];

  @override
  Future<PinChangeOutcome> changePin({required String currentPin, required String newPin}) async {
    changes.add((currentPin: currentPin, newPin: newPin));
    if (error != null) throw error!;
    return outcome;
  }

  @override
  Future<List<SecurityQuestion>> recoveryQuestions(String phone) async {
    questionLookups.add(phone);
    if (error != null) throw error!;
    return questions;
  }

  @override
  Future<PinChangeOutcome> resetPin({
    required String phone,
    required List<SecurityAnswer> answers,
    required String newPin,
  }) async {
    resets.add((phone: phone, answers: answers, newPin: newPin));
    if (error != null) throw error!;
    return outcome;
  }

  @override
  Future<void> setSecurityAnswers({
    required String currentPin,
    required List<SecurityAnswer> answers,
  }) async {
    answerSets.add((currentPin: currentPin, answers: answers));
    if (error != null) throw error!;
  }

  @override
  Future<List<SecurityQuestion>> configuredQuestions() async => configured;

  @override
  Future<bool?> securityQuestionsStatus() async => status;

  @override
  Future<bool> hasPendingPinChange() async => false;

  @override
  Future<PinSyncResult> flushPendingPinChange() async => PinSyncResult.nothingPending;

  @override
  SignOutReason? takeSignOutReason() => null;
}

/// Minimal [AuthRepository] so screens that refresh the auth gate don't build
/// the real one (database, secure storage) under test.
class StubAuthRepository implements AuthRepository {
  static const AuthUser user = AuthUser(
    id: 'u1',
    name: 'Abebe Girma',
    phone: '+251911234567',
    preferredLanguage: 'en',
    role: 'PATIENT',
  );

  @override
  Future<AuthUser> login({required String phone, required String pin}) async => user;

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
    List<SecurityAnswer>? securityAnswers,
  }) async => user;

  @override
  Future<AuthUser> getMe() async => user;

  @override
  Future<bool> refreshSession() async => true;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser?> cachedUser() async => user;

  @override
  Future<bool> isSignedIn() async => true;

  @override
  Future<bool> needsOnboarding() async => false;
}
