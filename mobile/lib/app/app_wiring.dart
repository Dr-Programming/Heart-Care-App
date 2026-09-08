import 'package:flutter/widgets.dart' show BuildContext, Widget;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` lives in flutter_riverpod's `misc.dart`, not its main barrel.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';
import '../core/router/routes.dart';
import '../core/shell/home_card.dart';
import '../features/activity/presentation/home/activity_card.dart';
import '../features/activity/presentation/screens/activity_history_screen.dart';
import '../features/activity/presentation/screens/activity_log_screen.dart';
import '../features/education/presentation/screens/learn_screen.dart';
import '../features/education/presentation/screens/quiz_screen.dart';
import '../features/education/presentation/screens/topic_screen.dart';
import '../features/symptoms/presentation/home/check_in_card.dart';
import '../features/symptoms/presentation/screens/check_in_hub_screen.dart';
import '../features/symptoms/presentation/screens/symptom_check_in_screen.dart';
import '../features/symptoms/presentation/screens/symptom_history_screen.dart';

// ---------------------------------------------------------------------------
// THE ONE FILE WHERE FEATURES MEET.
//
// Architectural rule #1 says features never import each other. Something still
// has to introduce them to the app, and this is that something: the
// composition root. It is the *only* file outside `core/` that a feature slice
// may edit, and each slice touches only the region marked with its own name.
//
// A slice registers at most three things:
//
//   1. routes         - added to the FeatureRoutes below
//   2. a Home card    - added to _homeCards, if the feature has something worth
//                       showing on the dashboard
//   3. provider overrides - only for a contract core declares and a feature
//                       implements, which today means AuthGate and nothing else
//
// Keep every edit inside your own marked region. Two slices adding to the same
// region is the one merge conflict this design cannot prevent, and it is a
// three-line conflict rather than a three-file one.
// ---------------------------------------------------------------------------

/// The app's router.
///
/// A provider rather than a field on the app widget so the redirect gets a
/// real [Ref] and can listen to the auth gate — the router has to re-evaluate
/// when the session changes, not only when the user navigates.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = buildRouter(ref, buildFeatureRoutes());
  ref.onDispose(router.dispose);
  return router;
});

/// Everything the five slices plug into the router.
///
/// Not `const`: a `GoRoute`'s `builder` closure and `GoRoute` itself are not
/// const-constructible, so the first slice to add a real route drops the
/// `const` here — expected, not a boundary violation.
FeatureRoutes buildFeatureRoutes() {
  return FeatureRoutes(
    topLevel: const <RouteBase>[
      // ── M1 auth ────────────────────────────────────────────────────────
      // splash, language picker, login, register, forgot-PIN
      //
      // ── M2 profile ─────────────────────────────────────────────────────
      // onboarding wizard, profile, profile edit, settings
    ],

    // ── M3 medications ───────────────────────────────────────────────────
    medications: const TabRoutes(),

    // ── M4 vitals ────────────────────────────────────────────────────────
    vitals: const TabRoutes(),

    // ── M5 symptoms & activity ───────────────────────────────────────────
    // Paths below are relative to `AppRoutes.checkInPath` and must stay in
    // sync with the full paths declared in `AppRoutes`.
    checkIn: TabRoutes(
      root: (BuildContext context) => const CheckInHubScreen(),
      children: <RouteBase>[
        GoRoute(
          path: 'symptoms',
          name: AppRoutes.symptomCheckIn,
          builder: (BuildContext context, GoRouterState state) =>
              const SymptomCheckInScreen(),
        ),
        GoRoute(
          path: 'symptoms/history',
          name: AppRoutes.symptomHistory,
          builder: (BuildContext context, GoRouterState state) =>
              const SymptomHistoryScreen(),
        ),
        GoRoute(
          path: 'activity',
          name: AppRoutes.activityLog,
          builder: (BuildContext context, GoRouterState state) =>
              const ActivityLogScreen(),
        ),
        GoRoute(
          path: 'activity/history',
          name: AppRoutes.activityHistory,
          builder: (BuildContext context, GoRouterState state) =>
              const ActivityHistoryScreen(),
        ),
      ],
    ),

    // ── M5 education & diet ──────────────────────────────────────────────
    // 'quiz' must be declared before ':topic' — go_router matches in
    // declaration order, and ':topic' would otherwise swallow /learn/quiz
    // as a topic id of "quiz".
    learn: TabRoutes(
      root: (BuildContext context) => const LearnScreen(),
      children: <RouteBase>[
        GoRoute(
          path: 'quiz',
          name: AppRoutes.quiz,
          builder: (BuildContext context, GoRouterState state) =>
              const QuizScreen(),
        ),
        GoRoute(
          path: ':topic',
          name: AppRoutes.learnTopic,
          builder: (BuildContext context, GoRouterState state) =>
              TopicScreen(topicId: state.pathParameters['topic']!),
        ),
      ],
    ),
  );
}

/// Cards on the Home dashboard, in whatever order; Home sorts them by
/// [HomeCard.order].
///
/// `HomeCard.builder` needs a constant expression to keep this list `const`
/// — a top-level function tear-off qualifies, a closure literal does not.
const List<HomeCard> _homeCards = <HomeCard>[
  // ── M3 medications ──── today's doses, order 100
  HomeCard(id: 'check-in-today', order: 110, builder: _buildCheckInHomeCard),
  // ── M4 vitals ───────── latest readings, order 200
  HomeCard(id: 'activity-today', order: 210, builder: _buildActivityHomeCard),
  // ── M2 profile ──────── goal progress, order 300
];

Widget _buildCheckInHomeCard(BuildContext context) => const CheckInHomeCard();

Widget _buildActivityHomeCard(BuildContext context) => const ActivityHomeCard();

/// Provider overrides that bind a `core/` contract to a feature's
/// implementation. Passed to `ProviderScope` in `main.dart`.
List<Override> featureOverrides() {
  return <Override>[
    // ── M1 auth ──────────────────────────────────────────────────────────
    // authGateProvider.overrideWith((ref) => ref.watch(realAuthGateProvider)),
    //
    // Until this is filled in, `OpenAuthGate` lets every route through so the
    // rest of the team can build and run against a working shell.

    homeCardsProvider.overrideWithValue(_homeCards),
  ];
}
