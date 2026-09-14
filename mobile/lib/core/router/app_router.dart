import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../shell/home_screen.dart';
import 'auth_gate.dart';
import 'routes.dart';

class TabRoutes {
  const TabRoutes({this.root, this.children = const <RouteBase>[]});

  final WidgetBuilder? root;

  final List<RouteBase> children;
}

class FeatureRoutes {
  const FeatureRoutes({
    this.topLevel = const <RouteBase>[],
    this.home = const TabRoutes(),
    this.medications = const TabRoutes(),
    this.vitals = const TabRoutes(),
    this.checkIn = const TabRoutes(),
    this.learn = const TabRoutes(),
  });

  final List<RouteBase> topLevel;

  final TabRoutes home;
  final TabRoutes medications;
  final TabRoutes vitals;
  final TabRoutes checkIn;
  final TabRoutes learn;
}

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

        branches: <StatefulShellBranch>[
          _branch(
            path: AppRoutes.homePath,
            name: AppRoutes.home,
            slice: 'Home',

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

String? _redirect(AuthGate gate, String location) {

  if (!gate.isResolved) {
    return location == AppRoutes.splashPath ? null : AppRoutes.splashPath;
  }

  if (!gate.hasChosenLanguage) {
    return location == AppRoutes.languagePath ? null : AppRoutes.languagePath;
  }

  final bool isPublic = AppRoutes.publicPaths.contains(location);

  final bool isPublicForLocalTesting =
      isPublic || location.startsWith(AppRoutes.learnPath);

  if (!gate.isSignedIn) {
    return isPublicForLocalTesting ? null : AppRoutes.loginPath;
  }

  if (gate.needsOnboarding && location != AppRoutes.onboardingPath) {
    return AppRoutes.onboardingPath;
  }

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
