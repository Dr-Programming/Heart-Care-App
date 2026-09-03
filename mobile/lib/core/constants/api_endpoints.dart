/// Every API path in the app. Nothing else may hardcode a URL.
abstract final class ApiEndpoints {
  static const String _v1 = '/api/v1';

  // Auth
  static const String register = '$_v1/auth/register';
  static const String login = '$_v1/auth/login';
  static const String me = '$_v1/auth/me';
}
