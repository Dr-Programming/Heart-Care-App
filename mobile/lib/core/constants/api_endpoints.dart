

abstract final class ApiEndpoints {
  static const String _v1 = '/api/v1';

  static const String health = '$_v1/health';

  static const String register = '$_v1/auth/register';
  static const String login = '$_v1/auth/login';
  static const String me = '$_v1/auth/me';
  static const String pinChange = '$_v1/auth/pin-change';
  static const String resetPin = '$_v1/auth/reset-pin';
  static const String recoveryQuestions = '$_v1/auth/recovery/questions';
  static const String securityAnswers = '$_v1/auth/security-answers';

  static const String patientMe = '$_v1/patients/me';

  static const String medications = '$_v1/medications';

  static String medication(String id) => '$_v1/medications/$id';

  static String medicationDoses(String medicationId) =>
      '$_v1/medications/$medicationId/doses';

  static const String doseLogs = '$_v1/dose-logs';

  static const String vitals = '$_v1/vitals';

  static const String symptoms = '$_v1/symptoms';

  static const String activities = '$_v1/activities';

  static const String sync = '$_v1/sync';
}
