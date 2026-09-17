import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app currently has a usable session.
///
/// Declared in `core/` and implemented in the auth slice, so the router can
/// gate every route without `core/` importing `features/auth` — architectural
/// rule #1 holds even for the one thing that genuinely is global.
///
/// The contract that matters is **this must not touch the network**. The gate
/// runs on every navigation, including a cold start in a village with no
/// signal, and an offline launch has to land on Home rather than hang on a
/// spinner or bounce the user to Login. Read the token from secure storage,
/// check the JWT `exp` claim locally with `core/security/jwt.dart`, and answer
/// from that alone. `GET /auth/me` is for refreshing the cached user later,
/// never for deciding whether the user is signed in.
abstract interface class AuthGate {
  /// True when a token exists and has not locally expired.
  bool get isSignedIn;

  /// True once the first check has finished. While false the router holds the
  /// user on the splash route instead of flashing Login at a signed-in user.
  bool get isResolved;

  /// True when the user has picked a language. False sends a first-run user
  /// to the picker before anything else (FR-LOC-003).
  bool get hasChosenLanguage;

  /// True when the profile wizard still has to run — set after registration,
  /// cleared once the profile is saved (M2).
  bool get needsOnboarding;
}

/// The gate before the auth slice exists.
///
/// Reports "resolved, signed in, language chosen, no onboarding needed" so the
/// shell is reachable and the rest of the team can build and run screens
/// against a working app while M1 is still in progress.
///
/// M1 replaces this by overriding [authGateProvider] in `lib/app/app_wiring.dart`
/// — it does not edit this file.
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

/// Overridden by the auth slice. Watched by the router's redirect, so any
/// change to the session re-evaluates navigation.
final Provider<AuthGate> authGateProvider = Provider<AuthGate>(
  (Ref ref) => const OpenAuthGate(),
);
