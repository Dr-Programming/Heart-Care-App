import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';
import '../core/router/auth_gate.dart';
import '../core/router/routes.dart';
import '../core/shell/home_card.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/presentation/screens/forgot_pin_screen.dart';
import '../features/auth/presentation/screens/language_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/education/presentation/screens/learn_screen.dart';
import '../features/education/presentation/screens/quiz_screen.dart';
import '../features/education/presentation/screens/topic_screen.dart';
import '../features/medication/presentation/home/todays_doses_card.dart';
import '../features/medication/presentation/screens/adherence_screen.dart';
import '../features/medication/presentation/screens/dose_history_screen.dart';
import '../features/medication/presentation/screens/medication_form_screen.dart';
import '../features/medication/presentation/screens/medications_screen.dart';
import '../features/medication/presentation/screens/reminder_settings_screen.dart';
import '../features/profile/presentation/home/profile_home_card.dart';
import '../features/profile/presentation/screens/onboarding_screen.dart';
import '../features/profile/presentation/screens/profile_edit_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/settings_screen.dart';
import '../features/symptoms/presentation/home/check_in_home_card.dart';
import '../features/symptoms/presentation/screens/check_in_hub_screen.dart';
import '../features/symptoms/presentation/screens/symptom_check_in_screen.dart';
import '../features/symptoms/presentation/screens/symptom_history_screen.dart';
import '../features/vitals/presentation/home/latest_vitals_card.dart';
import '../features/vitals/presentation/screens/vital_form_screen.dart';
import '../features/vitals/presentation/screens/vitals_history_screen.dart';
import '../features/vitals/presentation/screens/vitals_screen.dart';
import '../features/vitals/presentation/screens/vitals_trend_screen.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = buildRouter(ref, buildFeatureRoutes());
  ref.onDispose(router.dispose);
  return router;
});

FeatureRoutes buildFeatureRoutes() {
  return FeatureRoutes(
    topLevel: <RouteBase>[
      GoRoute(
        path: AppRoutes.splashPath,
        name: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.languagePath,
        name: AppRoutes.language,
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: AppRoutes.loginPath,
        name: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerPath,
        name: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPinPath,
        name: AppRoutes.forgotPin,
        builder: (context, state) => const ForgotPinScreen(),
      ),

      GoRoute(
        path: AppRoutes.onboardingPath,
        name: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.profilePath,
        name: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEditPath,
        name: AppRoutes.profileEdit,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.settingsPath,
        name: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    medications: TabRoutes(
      root: (BuildContext context) => const MedicationsScreen(),
      children: <RouteBase>[
        GoRoute(
          path: 'new',
          name: AppRoutes.medicationNew,
          builder: (BuildContext context, GoRouterState state) =>
              const MedicationFormScreen(),
        ),
        GoRoute(
          path: ':id/edit',
          name: AppRoutes.medicationEdit,
          builder: (BuildContext context, GoRouterState state) =>
              MedicationFormScreen(editingId: state.pathParameters['id']),
        ),
        GoRoute(
          path: 'history',
          name: AppRoutes.doseHistory,
          builder: (BuildContext context, GoRouterState state) =>
              const DoseHistoryScreen(),
        ),
        GoRoute(
          path: 'adherence',
          name: AppRoutes.adherence,
          builder: (BuildContext context, GoRouterState state) =>
              const AdherenceScreen(),
        ),
        GoRoute(
          path: 'reminders',
          name: AppRoutes.reminderSettings,
          builder: (BuildContext context, GoRouterState state) =>
              const ReminderSettingsScreen(),
        ),
      ],
    ),

    vitals: TabRoutes(
      root: (BuildContext context) => const VitalsScreen(),
      children: <RouteBase>[
        GoRoute(
          path: AppRoutes.vitalsLogPath.replaceFirst('/vitals/', ''),
          name: AppRoutes.vitalsLog,
          builder: (BuildContext context, GoRouterState state) =>
              const VitalFormScreen(),
        ),
        GoRoute(
          path: AppRoutes.vitalsHistoryPath.replaceFirst('/vitals/', ''),
          name: AppRoutes.vitalsHistory,
          builder: (BuildContext context, GoRouterState state) =>
              const VitalsHistoryScreen(),
        ),
        GoRoute(
          path: AppRoutes.vitalsTrendPath.replaceFirst('/vitals/', ''),
          name: AppRoutes.vitalsTrend,
          builder: (BuildContext context, GoRouterState state) =>
              VitalsTrendScreen(type: VitalsTrendScreen.typeFromRoute(state)),
        ),
      ],
    ),

    checkIn: TabRoutes(
      root: (BuildContext context) => const CheckInHubScreen(),
      children: <RouteBase>[
        GoRoute(
          path: AppRoutes.symptomCheckInPath.replaceFirst('/check-in/', ''),
          name: AppRoutes.symptomCheckIn,
          builder: (BuildContext context, GoRouterState state) =>
              const SymptomCheckInScreen(),
        ),
        GoRoute(
          path: AppRoutes.symptomHistoryPath.replaceFirst('/check-in/', ''),
          name: AppRoutes.symptomHistory,
          builder: (BuildContext context, GoRouterState state) =>
              const SymptomHistoryScreen(),
        ),
      ],
    ),

    learn: TabRoutes(
      root: (BuildContext context) => const LearnScreen(),
      children: <RouteBase>[
        GoRoute(
          path: AppRoutes.quizPath.replaceFirst('/learn/', ''),
          name: AppRoutes.quiz,
          builder: (BuildContext context, GoRouterState state) =>
              QuizScreen(topicId: QuizScreen.topicIdFromRoute(state)),
        ),
        GoRoute(
          path: AppRoutes.learnTopicPath.replaceFirst('/learn/', ''),
          name: AppRoutes.learnTopic,
          builder: (BuildContext context, GoRouterState state) =>
              TopicScreen(topicId: TopicScreen.topicIdFromRoute(state)),
        ),
      ],
    ),
  );
}

final List<HomeCard> _homeCards = <HomeCard>[
  todaysDosesHomeCard(),
  checkInHomeCard(),
  latestVitalsHomeCard(),
  profileHomeCard,
];

List<Override> featureOverrides() {
  return <Override>[
    authGateProvider.overrideWith((ref) => ref.watch(realAuthGateProvider)),

    homeCardsProvider.overrideWithValue(_homeCards),
  ];
}
