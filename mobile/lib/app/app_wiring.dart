import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import '../features/appointments/appointment_providers.dart';
import '../features/appointments/presentation/appointment_home_card.dart';
import '../features/appointments/presentation/screens/appointment_form_screen.dart';
import '../features/appointments/presentation/screens/appointments_screen.dart';
import '../core/clinic/clinic_home_cards.dart';
import '../core/db/app_database.dart' show PatientDataReset;
import '../core/providers/core_providers.dart';
import '../core/router/app_router.dart';
import 'visit_summary/visit_summary_controller.dart';
import 'visit_summary/visit_summary_screen.dart';
import '../core/router/auth_gate.dart';
import '../core/router/routes.dart';
import '../core/shell/home_card.dart';
import '../features/activity/presentation/controllers/activity_overview_controller.dart';
import '../features/activity/presentation/home/activity_home_card.dart';
import '../features/activity/presentation/screens/activity_form_screen.dart';
import '../features/activity/presentation/screens/activity_screen.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/presentation/screens/change_pin_screen.dart';
import '../features/auth/presentation/screens/forgot_pin_screen.dart';
import '../features/auth/presentation/screens/language_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/security_questions_screen.dart';
import '../features/auth/presentation/widgets/security_questions_prompt.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/education/presentation/screens/eat_well_screen.dart';
import '../features/education/presentation/screens/learn_screen.dart';
import '../features/education/presentation/screens/quiz_screen.dart';
import '../features/education/presentation/screens/topic_screen.dart';
import '../features/activity/activity_providers.dart';
import '../features/medication/data/repositories/medication_repository_impl.dart';
import '../features/medication/domain/entities/medication.dart';
import '../features/medication/domain/repositories/medication_repository.dart';
import '../features/symptoms/symptom_providers.dart';
import '../features/vitals/vitals_providers.dart';
import '../features/medication/medication_providers.dart';
import '../features/medication/presentation/controllers/adherence_controller.dart';
import '../features/medication/presentation/controllers/dose_history_controller.dart';
import '../features/medication/presentation/controllers/medication_list_controller.dart';
import '../features/medication/presentation/home/todays_doses_card.dart';
import '../features/medication/presentation/screens/adherence_screen.dart';
import '../features/medication/presentation/screens/dose_history_screen.dart';
import '../features/medication/presentation/screens/medication_form_screen.dart';
import '../features/medication/presentation/screens/medications_screen.dart';
import '../features/medication/presentation/screens/reminder_settings_screen.dart';
import '../features/profile/presentation/controllers/onboarding_controller.dart';
import '../features/profile/presentation/controllers/profile_controller.dart';
import '../features/profile/presentation/home/profile_home_card.dart';
import '../features/profile/presentation/screens/onboarding_screen.dart';
import '../features/profile/presentation/screens/profile_edit_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/settings_screen.dart';
import '../features/symptoms/presentation/controllers/check_in_hub_controller.dart';
import '../features/symptoms/presentation/home/check_in_home_card.dart';
import '../features/symptoms/presentation/screens/check_in_hub_screen.dart';
import '../features/symptoms/presentation/screens/symptom_check_in_screen.dart';
import '../features/symptoms/presentation/screens/symptom_history_screen.dart';
import '../features/vitals/presentation/controllers/vitals_history_controller.dart';
import '../features/vitals/presentation/controllers/vitals_list_controller.dart';
import '../features/vitals/presentation/controllers/vitals_trend_controller.dart';
import '../features/vitals/presentation/home/latest_vitals_card.dart';
import '../features/vitals/domain/entities/vital_type.dart';
import '../features/vitals/presentation/controllers/bp_trend_controller.dart';
import '../features/vitals/presentation/screens/bp_trend_screen.dart';
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
        path: AppRoutes.visitSummaryPath,
        name: AppRoutes.visitSummary,
        builder: (context, state) => const VisitSummaryScreen(),
      ),
      GoRoute(
        path: AppRoutes.appointmentsPath,
        name: AppRoutes.appointments,
        builder: (context, state) => const AppointmentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.appointmentNewPath,
        name: AppRoutes.appointmentNew,
        builder: (context, state) => const AppointmentFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.appointmentEditPath,
        name: AppRoutes.appointmentEdit,
        builder: (context, state) => AppointmentFormScreen(
          appointmentId: AppointmentFormScreen.idFromRoute(state),
        ),
      ),
      GoRoute(
        path: AppRoutes.settingsPath,
        name: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePinPath,
        name: AppRoutes.changePin,
        builder: (context, state) => const ChangePinScreen(),
      ),
      GoRoute(
        path: AppRoutes.securityQuestionsPath,
        name: AppRoutes.securityQuestions,
        builder: (context, state) => const SecurityQuestionsScreen(),
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
          builder: (BuildContext context, GoRouterState state) {
            final VitalType type = VitalsTrendScreen.typeFromRoute(state);
            return type == VitalType.bloodPressure
                ? const BpTrendScreen()
                : VitalsTrendScreen(type: type);
          },
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
          path: AppRoutes.activityPath.replaceFirst('/check-in/', ''),
          name: AppRoutes.activity,
          builder: (BuildContext context, GoRouterState state) =>
              const ActivityScreen(),
          routes: <RouteBase>[
            GoRoute(
              path: 'log',
              name: AppRoutes.activityLog,
              builder: (BuildContext context, GoRouterState state) =>
                  const ActivityFormScreen(),
            ),
          ],
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
          path: AppRoutes.eatWellPath.replaceFirst('/learn/', ''),
          name: AppRoutes.eatWell,
          builder: (BuildContext context, GoRouterState state) =>
              const EatWellScreen(),
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
  HomeCard(
    id: 'securityQuestionsPrompt',
    order: -1,
    builder: (BuildContext context) => const SecurityQuestionsPrompt(),
  ),
  urgentClinicHomeCard(),
  todaysDosesHomeCard(),
  checkInHomeCard(),
  activityHomeCard(),
  latestVitalsHomeCard(),
  profileHomeCard,
  clinicHomeCard(),
  // Next appointment, how to prepare, and the visit summary.
  appointmentHomeCard(),
];

List<Override> featureOverrides() {
  return <Override>[
    authGateProvider.overrideWith((ref) => ref.watch(realAuthGateProvider)),
    sessionRefresherProvider.overrideWith(
      (ref) => ref.watch(authSessionRefresherProvider),
    ),
    sessionExpiredHandlerProvider.overrideWith(
      (ref) => ref.watch(authSessionExpiredHandlerProvider),
    ),

    patientSwitchHandlerProvider.overrideWith(
      (ref) =>
          () => _clearPreviousPatient(ref),
    ),
    beforeSignOutProvider.overrideWith(
      (ref) =>
          () => _flushBeforeSignOut(ref),
    ),
    restoreFromServerProvider.overrideWith(
      (ref) =>
          () => _restoreFromServer(ref),
    ),
    sessionChangedHandlerProvider.overrideWith(
      (ref) =>
          () => _resetPatientState(ref),
    ),

    discardUnsentRecordsProvider.overrideWith(
      (ref) =>
          () => _clearPreviousPatient(ref),
    ),
    onboardingDoneHandlerProvider.overrideWith(
      (ref) =>
          () => ref.read(realAuthGateProvider.notifier).refresh(),
    ),

    homeCardsProvider.overrideWithValue(_homeCards),
  ];
}

/// A different patient signed in: their predecessor's reminders must stop
/// firing on this phone, then their records go.
Future<void> _clearPreviousPatient(Ref ref) async {
  try {
    final List<Medication> previous = await ref
        .read(medicationRepositoryProvider)
        .allMedications(includeInactive: true);
    await ref.read(medicationNotificationsProvider).cancelAll(previous);
  } on Object {
    // Reminders are best effort; the records must be cleared regardless.
  }
  try {
    await ref.read(appointmentRemindersProvider).cancelAll();
  } on Object {
    // As above.
  }
  await ref.read(appDatabaseProvider).clearPatientData();
}

/// Downloads the patient's records each feature is missing, then refreshes
/// the screens and reschedules medication reminders. One feature failing
/// (a dropped connection) doesn't stop the others.
Future<void> _restoreFromServer(Ref ref) async {
  Future<void> safely(Future<void> Function() restore) =>
      restore().catchError((Object _) {});
  await Future.wait(<Future<void>>[
    safely(() async {
      final MedicationRepository meds = ref.read(medicationRepositoryProvider);
      if (meds is MedicationRepositoryImpl) await meds.restoreFromServer();
    }),
    safely(() => ref.read(vitalsRepositoryImplProvider).restoreFromServer()),
    safely(() => ref.read(symptomRepositoryImplProvider).restoreFromServer()),
    safely(() => ref.read(activityRepositoryImplProvider).restoreFromServer()),
  ]);
  _resetPatientState(ref);
  // Restored medications need their reminders on this phone.
  await safely(() => ref.read(medicationReminderBootstrapProvider).start());
}

/// Sends what is still waiting while the patient's token works. Bounded, so
/// a slow network never traps someone on the sign-out button.
Future<void> _flushBeforeSignOut(Ref ref) async {
  if (!await ref.read(isOnlineProvider)()) return;
  await Future.wait(<Future<void>>[
    ref.read(medicationRepositoryProvider).replayPendingEdits(),
    ref.read(syncServiceProvider).syncNow(),
  ]).timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
}

/// Every provider that keeps a patient's data in memory. Reset on sign-in and
/// sign-out so nobody sees the previous patient's numbers, even briefly.
void _resetPatientState(Ref ref) {
  ref
    ..invalidate(medicationListControllerProvider)
    ..invalidate(adherenceControllerProvider)
    ..invalidate(doseHistoryControllerProvider)
    ..invalidate(medicationRemindersStartupProvider)
    ..invalidate(profileControllerProvider)
    ..invalidate(onboardingControllerProvider)
    ..invalidate(checkInHubControllerProvider)
    ..invalidate(symptomHistoryProvider)
    ..invalidate(activityOverviewControllerProvider)
    ..invalidate(vitalsListControllerProvider)
    ..invalidate(vitalsHistoryControllerProvider)
    ..invalidate(vitalsTrendControllerProvider)
    ..invalidate(bpTrendControllerProvider)
    ..invalidate(visitSummaryControllerProvider);
}
