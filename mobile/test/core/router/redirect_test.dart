import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/router/app_router.dart';
import 'package:libu_care/core/router/auth_gate.dart';
import 'package:libu_care/core/router/routes.dart';

/// A gate whose answers are set directly, so the redirect can be tested
/// without a session, a database or a widget tree.
class _Gate implements AuthGate {
  const _Gate({
    this.isResolved = true,
    this.isSignedIn = false,
    this.hasChosenLanguage = true,
    this.needsOnboarding = false,
  });

  @override
  final bool isResolved;
  @override
  final bool isSignedIn;
  @override
  final bool hasChosenLanguage;
  @override
  final bool needsOnboarding;
}

void main() {
  group('while the session is still resolving', () {
    test('holds the user on splash', () {
      expect(
        redirectFor(const _Gate(isResolved: false), AppRoutes.homePath),
        AppRoutes.splashPath,
      );
    });

    test('does not redirect away from splash', () {
      expect(
        redirectFor(const _Gate(isResolved: false), AppRoutes.splashPath),
        isNull,
      );
    });
  });

  group('first run', () {
    test('language comes before everything, including login (FR-LOC-003)', () {
      const AuthGate gate = _Gate(hasChosenLanguage: false);
      expect(redirectFor(gate, AppRoutes.loginPath), AppRoutes.languagePath);
      expect(redirectFor(gate, AppRoutes.homePath), AppRoutes.languagePath);
    });

    test('the picker itself is reachable', () {
      expect(
        redirectFor(
          const _Gate(hasChosenLanguage: false),
          AppRoutes.languagePath,
        ),
        isNull,
      );
    });
  });

  group('signed out', () {
    const AuthGate gate = _Gate();

    test('any private route goes to login', () {
      expect(redirectFor(gate, AppRoutes.homePath), AppRoutes.loginPath);
      expect(redirectFor(gate, AppRoutes.vitalsPath), AppRoutes.loginPath);
      expect(redirectFor(gate, AppRoutes.profilePath), AppRoutes.loginPath);
    });

    test('the auth screens are reachable', () {
      for (final String path in AppRoutes.publicPaths) {
        expect(redirectFor(gate, path), isNull, reason: path);
      }
    });
  });

  group('signed in', () {
    const AuthGate gate = _Gate(isSignedIn: true);

    test('lands on home from splash - the offline relaunch path', () {
      expect(redirectFor(gate, AppRoutes.splashPath), AppRoutes.homePath);
    });

    test('cannot go back to login without signing out', () {
      expect(redirectFor(gate, AppRoutes.loginPath), AppRoutes.homePath);
      expect(redirectFor(gate, AppRoutes.registerPath), AppRoutes.homePath);
    });

    test('private routes are allowed through', () {
      expect(redirectFor(gate, AppRoutes.homePath), isNull);
      expect(redirectFor(gate, AppRoutes.medicationsPath), isNull);
      expect(redirectFor(gate, AppRoutes.settingsPath), isNull);
    });
  });

  group('onboarding', () {
    const AuthGate gate = _Gate(isSignedIn: true, needsOnboarding: true);

    test('a new account is held in the wizard', () {
      expect(redirectFor(gate, AppRoutes.homePath), AppRoutes.onboardingPath);
      expect(redirectFor(gate, AppRoutes.vitalsPath), AppRoutes.onboardingPath);
    });

    test('the wizard itself is reachable', () {
      expect(redirectFor(gate, AppRoutes.onboardingPath), isNull);
    });

    test('the language picker still wins over the wizard', () {
      expect(
        redirectFor(
          const _Gate(
            isSignedIn: true,
            needsOnboarding: true,
            hasChosenLanguage: false,
          ),
          AppRoutes.homePath,
        ),
        AppRoutes.languagePath,
      );
    });
  });

  test('OpenAuthGate lets the shell run before the auth slice exists', () {
    const AuthGate gate = OpenAuthGate();
    expect(redirectFor(gate, AppRoutes.homePath), isNull);
    expect(redirectFor(gate, AppRoutes.splashPath), AppRoutes.homePath);
  });
}
