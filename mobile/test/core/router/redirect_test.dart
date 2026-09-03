import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/router/redirect.dart';
import 'package:libu_care/core/router/routes.dart';

String? redirect({
  required String location,
  bool sessionResolved = true,
  bool languageChosen = true,
  bool authenticated = false,
}) =>
    resolveRedirect(
      location: location,
      sessionResolved: sessionResolved,
      languageChosen: languageChosen,
      authenticated: authenticated,
    );

void main() {
  test('holds on splash until the session has been read from disk', () {
    expect(redirect(location: Routes.splash, sessionResolved: false), isNull);
    expect(redirect(location: Routes.login, sessionResolved: false), Routes.splash);
  });

  test('sends a first-run user to the language picker before anything else', () {
    expect(redirect(location: Routes.login, languageChosen: false), Routes.language);
    expect(redirect(location: Routes.language, languageChosen: false), isNull);
  });

  test('an authenticated user landing on splash goes Home', () {
    expect(redirect(location: Routes.splash, authenticated: true), Routes.home);
  });

  test('an unauthenticated user landing on splash goes to Login', () {
    expect(redirect(location: Routes.splash), Routes.login);
  });

  test('an unauthenticated user cannot reach Home', () {
    expect(redirect(location: Routes.home), Routes.login);
  });

  test('an authenticated user is bounced off the auth screens', () {
    expect(redirect(location: Routes.login, authenticated: true), Routes.home);
    expect(redirect(location: Routes.register, authenticated: true), Routes.home);
  });

  test('an unauthenticated user may sit on login, register and forgot-PIN', () {
    expect(redirect(location: Routes.login), isNull);
    expect(redirect(location: Routes.register), isNull);
    expect(redirect(location: Routes.forgotPin), isNull);
  });

  test('an authenticated user stays on Home', () {
    expect(redirect(location: Routes.home, authenticated: true), isNull);
  });
}
