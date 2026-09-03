abstract final class Routes {
  static const String splash = '/splash';
  static const String language = '/language';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPin = '/forgot-pin';
  static const String home = '/home';

  /// Screens reachable without a session.
  static const Set<String> public = <String>{login, register, forgotPin};
}
