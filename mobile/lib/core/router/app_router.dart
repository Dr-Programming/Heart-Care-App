import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../shell/home_screen.dart';
import 'auth_gate.dart';
import 'routes.dart';

/// One bottom-nav tab's contribution: what its root screen is, and what sits
/// underneath it.
class TabRoutes {
  const TabRoutes({this.root, this.children = const <RouteBase>[]});

  /// The tab's landing screen. Null until the owning slice supplies one, in
  /// which case the tab shows a "not built yet" placeholder — which keeps the
  /// app runnable while five slices land at different times.
  final WidgetBuilder? root;

  /// Everything reachable from the tab root, as go_router sub-routes.
  final List<RouteBase> children;
}

/// Everything the feature slices plug into the router.
///
/// A slice fills in exactly the field it owns, in `lib/app/app_wiring.dart`.
/// The tab order, the redirect and the shell are fixed by the foundation and
/// are not a feature's business.
class FeatureRoutes {
  const FeatureRoutes({
    this.topLevel = const <RouteBase>[],
    this.home = const TabRoutes(),
    this.medications = const TabRoutes(),
    this.vitals = const TabRoutes(),
    this.checkIn = const TabRoutes(),
    this.learn = const TabRoutes(),
  });

  /// Full-screen routes outside the bottom nav: auth, the onboarding wizard,
  /// profile and settings.
  final List<RouteBase> topLevel;

  final TabRoutes home;
  final TabRoutes medications;
  final TabRoutes vitals;
  final TabRoutes checkIn;
  final TabRoutes learn;
}

/// Stands in for a tab whose slice has not landed yet.
class NotBuiltYet extends StatelessWidget {
  const NotBuiltYet({required this.slice, super.key});

  final String slice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '$slice has not been built yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Builds the app's router.
///
/// The redirect is the auth gate (FR-AUTH-006). It is deliberately synchronous
/// and local — see [AuthGate] for why it must never make a request.
GoRouter buildRouter(Ref ref, FeatureRoutes features) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splashPath,
    refreshListenable: ProviderRefresh<AuthGate>(ref, authGateProvider),
    redirect: (BuildContext context, GoRouterState state) =>
        _redirect(ref.read(authGateProvider), state.matchedLocation),
    routes: <RouteBase>[
      ...features.topLevel,
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) => AppShell(navigationShell: navigationShell),
        // Branch order must match AppShell.tabs. Changing one without the
        // other silently sends users to the wrong tab.
        branches: <StatefulShellBranch>[
          _branch(
            path: AppRoutes.homePath,
            name: AppRoutes.home,
            slice: 'Home',
            // Home's frame belongs to the foundation; its content is
            // contributed as HomeCards by every feature.
            tab: TabRoutes(
              root: (BuildContext context) => const HomeScreen(),
              children: features.home.children,
            ),
          ),
          _branch(
            path: AppRoutes.medicationsPath,
            name: AppRoutes.medications,
            slice: 'Medications (M3)',
            tab: features.medications,
          ),
          _branch(
            path: AppRoutes.vitalsPath,
            name: AppRoutes.vitals,
            slice: 'Vitals (M4)',
            tab: features.vitals,
          ),
          _branch(
            path: AppRoutes.checkInPath,
            name: AppRoutes.checkIn,
            slice: 'Symptoms and activity (M5)',
            tab: features.checkIn,
          ),
          _branch(
            path: AppRoutes.learnPath,
            name: AppRoutes.learn,
            slice: 'Education and diet (M5)',
            tab: features.learn,
          ),
        ],
      ),
    ],
  );
}

/// The gate itself, extracted so it can be unit-tested without a widget tree.
///
/// Returns the path to redirect to, or null to allow the navigation.
String? _redirect(AuthGate gate, String location) {
  // Hold on splash until the token check has finished, so a signed-in user
  // never sees Login flash past on a cold start.
  if (!gate.isResolved) {
    return location == AppRoutes.splashPath ? null : AppRoutes.splashPath;
  }

  // First run: pick a language before anything else (FR-LOC-003).
  if (!gate.hasChosenLanguage) {
    return location == AppRoutes.languagePath ? null : AppRoutes.languagePath;
  }

  final bool isPublic = AppRoutes.publicPaths.contains(location);

  if (!gate.isSignedIn) {
    return isPublic ? null : AppRoutes.loginPath;
  }

  // Signed in: the profile wizard is the only thing allowed before the app.
  if (gate.needsOnboarding && location != AppRoutes.onboardingPath) {
    return AppRoutes.onboardingPath;
  }

  // Signed in and sitting on splash or an auth screen - go to the app.
  if (isPublic) return AppRoutes.homePath;

  return null;
}

@visibleForTesting
String? redirectFor(AuthGate gate, String location) =>
    _redirect(gate, location);

StatefulShellBranch _branch({
  required String path,
  required String name,
  required String slice,
  required TabRoutes tab,
}) {
  final WidgetBuilder root =
      tab.root ?? (BuildContext context) => NotBuiltYet(slice: slice);

  return StatefulShellBranch(
    routes: <RouteBase>[
      GoRoute(
        path: path,
        name: name,
        builder: (BuildContext context, GoRouterState state) => root(context),
        routes: tab.children,
      ),
    ],
  );
}

/// Bridges a Riverpod provider to go_router's `refreshListenable`.
///
/// Without this the redirect would only re-run on an explicit navigation, so
/// signing out would leave the user looking at a screen they are no longer
/// entitled to until they tapped something.
class ProviderRefresh<T> extends ChangeNotifier {
  ProviderRefresh(Ref ref, Provider<T> provider) {
    _subscription = ref.listen<T>(provider, (_, _) => notifyListeners());
  }

  late final ProviderSubscription<T> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
