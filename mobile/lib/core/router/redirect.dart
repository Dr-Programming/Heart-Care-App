import 'routes.dart';

/// The auth gate, as a pure function so it can be tested without a widget tree.
///
/// Order matters:
///   1. Nothing is decided until the session has been read from disk.
///   2. A first-run user picks a language before seeing any other screen.
///   3. Then the ordinary signed-in / signed-out split.
///
/// Returns the location to redirect to, or null to stay put.
String? resolveRedirect({
  required String location,
  required bool sessionResolved,
  required bool languageChosen,
  required bool authenticated,
}) {
  if (!sessionResolved) {
    return location == Routes.splash ? null : Routes.splash;
  }

  if (!languageChosen) {
    return location == Routes.language ? null : Routes.language;
  }

  if (authenticated) {
    return location == Routes.home ? null : Routes.home;
  }

  return Routes.public.contains(location) ? null : Routes.login;
}
