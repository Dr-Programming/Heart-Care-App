import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class AuthGate {

  bool get isSignedIn;

  bool get isResolved;

  bool get hasChosenLanguage;

  bool get needsOnboarding;
}

class OpenAuthGate implements AuthGate {
  const OpenAuthGate();

  @override
  bool get isSignedIn => true;

  @override
  bool get isResolved => true;

  @override
  bool get hasChosenLanguage => true;

  @override
  bool get needsOnboarding => false;
}

final Provider<AuthGate> authGateProvider = Provider<AuthGate>(
  (Ref ref) => const OpenAuthGate(),
);
