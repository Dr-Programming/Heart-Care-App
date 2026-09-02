import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` lives in flutter_riverpod's `misc.dart`, not its main barrel.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import '../core/router/app_router.dart';
import '../core/router/routes.dart';
import '../core/shell/home_card.dart';
import '../features/profile/presentation/onboarding/onboarding_step1_screen.dart';
import '../features/profile/presentation/onboarding/onboarding_step2_screen.dart';
import '../features/profile/presentation/onboarding/onboarding_step3_screen.dart';

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
FeatureRoutes buildFeatureRoutes() {
  return FeatureRoutes(
    topLevel: <RouteBase>[
      // ── M1 auth ────────────────────────────────────────────────────────
      // splash, language picker, login, register, forgot-PIN
      //
      // ── M2 profile ─────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboardingPath,
        name: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingStep1Screen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'step-2',
            builder: (BuildContext context, GoRouterState state) =>
                const OnboardingStep2Screen(),
          ),
          GoRoute(
            path: 'step-3',
            builder: (BuildContext context, GoRouterState state) =>
                const OnboardingStep3Screen(),
          ),
        ],
      ),
    ],

    // ── M3 medications ───────────────────────────────────────────────────
    medications: const TabRoutes(),

    // ── M4 vitals ────────────────────────────────────────────────────────
    vitals: const TabRoutes(),

    // ── M5 symptoms & activity ───────────────────────────────────────────
    checkIn: const TabRoutes(),

    // ── M5 education & diet ──────────────────────────────────────────────
    learn: const TabRoutes(),
  );
}

/// Cards on the Home dashboard, in whatever order; Home sorts them by
/// [HomeCard.order].
const List<HomeCard> _homeCards = <HomeCard>[
  // ── M3 medications ──── today's doses, order 100
  // ── M5 check-in ─────── today's check-in prompt, order 110
  // ── M4 vitals ───────── latest readings, order 200
  // ── M5 activity ─────── today's activity, order 210
  // ── M2 profile ──────── goal progress, order 300
];

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