/// Every route in the app, declared up front by the foundation slice.
///
/// Declaring all of them before any of them are built is deliberate. A feature
/// that needs to send the user somewhere outside itself — the medication card
/// on Home opening the medication list, the symptom result linking to the
/// exercise guidance — can name that destination today without importing the
/// feature that will eventually own it. That is what keeps architectural
/// rule #1 ("features never import each other") true for navigation as well
/// as for code.
///
/// Navigate by **name**, never by literal path:
/// `context.goNamed(AppRoutes.vitalsLog)`. Paths may still move; names will
/// not.
abstract final class AppRoutes {
  // ------------------------------------------------------------- Auth (M1)
  static const String splash = 'splash';
  static const String splashPath = '/';

  static const String language = 'language';
  static const String languagePath = '/language';

  static const String login = 'login';
  static const String loginPath = '/login';

  static const String register = 'register';
  static const String registerPath = '/register';

  static const String forgotPin = 'forgotPin';
  static const String forgotPinPath = '/forgot-pin';

  // -------------------------------------------- Profile & onboarding (M2)
  /// The three-step wizard shown once, straight after registration.
  static const String onboarding = 'onboarding';
  static const String onboardingPath = '/onboarding';

  static const String profile = 'profile';
  static const String profilePath = '/profile';

  static const String profileEdit = 'profileEdit';
  static const String profileEditPath = '/profile/edit';

  static const String settings = 'settings';
  static const String settingsPath = '/settings';

  // ------------------------------------------------------ Home tab (shell)
  static const String home = 'home';
  static const String homePath = '/home';

  // --------------------------------------------------- Medications (M3)
  static const String medications = 'medications';
  static const String medicationsPath = '/medications';

  static const String medicationNew = 'medicationNew';
  static const String medicationNewPath = '/medications/new';

  static const String medicationEdit = 'medicationEdit';
  static const String medicationEditPath = '/medications/:id/edit';

  static const String doseHistory = 'doseHistory';
  static const String doseHistoryPath = '/medications/history';

  static const String adherence = 'adherence';
  static const String adherencePath = '/medications/adherence';

  static const String reminderSettings = 'reminderSettings';
  static const String reminderSettingsPath = '/medications/reminders';

  // -------------------------------------------------------- Vitals (M4)
  static const String vitals = 'vitals';
  static const String vitalsPath = '/vitals';

  static const String vitalsLog = 'vitalsLog';
  static const String vitalsLogPath = '/vitals/log';

  static const String vitalsHistory = 'vitalsHistory';
  static const String vitalsHistoryPath = '/vitals/history';

  /// `:type` is a wire `VitalType` — BLOOD_PRESSURE, WEIGHT, GLUCOSE.
  static const String vitalsTrend = 'vitalsTrend';
  static const String vitalsTrendPath = '/vitals/trend/:type';

  // ------------------------------------------ Symptoms & activity (M5)
  static const String checkIn = 'checkIn';
  static const String checkInPath = '/check-in';

  static const String symptomCheckIn = 'symptomCheckIn';
  static const String symptomCheckInPath = '/check-in/symptoms';

  static const String symptomHistory = 'symptomHistory';
  static const String symptomHistoryPath = '/check-in/symptoms/history';

  static const String activityLog = 'activityLog';
  static const String activityLogPath = '/check-in/activity';

  static const String activityHistory = 'activityHistory';
  static const String activityHistoryPath = '/check-in/activity/history';

  // ------------------------------------------- Education & diet (M5)
  static const String learn = 'learn';
  static const String learnPath = '/learn';

  /// `:topic` is an education module id — `chd-basics`, `heart-attack`,
  /// `diet`, `exercise`, `medication-adherence`, `psychosocial`.
  static const String learnTopic = 'learnTopic';
  static const String learnTopicPath = '/learn/:topic';

  static const String quiz = 'quiz';
  static const String quizPath = '/learn/quiz';

  /// Routes a signed-out user is allowed to reach. The auth gate sends
  /// everything else to [login].
  static const Set<String> publicPaths = <String>{
    splashPath,
    languagePath,
    loginPath,
    registerPath,
    forgotPinPath,
  };
}
