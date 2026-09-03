import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_pin_screen.dart';
import '../../features/auth/presentation/screens/home_placeholder_screen.dart';
import '../../features/auth/presentation/screens/language_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../providers/core_providers.dart';
import 'redirect.dart';
import 'routes.dart';

/// Whether the first-run language choice has been made. Invalidated by the
/// language screen once the user commits.
final FutureProvider<bool> languageChosenProvider =
    FutureProvider<bool>((ref) => ref.watch(languageStoreProvider).hasChosen());

final Provider<GoRouter> goRouterProvider = Provider<GoRouter>((ref) {
  final GoRouter router = GoRouter(
    initialLocation: Routes.splash,
    redirect: (BuildContext context, GoRouterState state) {
      final AsyncValue<AuthState> auth = ref.read(authControllerProvider);
      final AsyncValue<bool> chosen = ref.read(languageChosenProvider);

      return resolveRedirect(
        location: state.matchedLocation,
        sessionResolved: !auth.isLoading && !chosen.isLoading,
        languageChosen: chosen.valueOrNull ?? false,
        authenticated: auth.valueOrNull is AuthAuthenticated,
      );
    },
    routes: <RouteBase>[
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.language, builder: (_, _) => const LanguageScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.forgotPin, builder: (_, _) => const ForgotPinScreen()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomePlaceholderScreen()),
    ],
  );

  // Re-run the redirect whenever the session or the language choice resolves.
  // The auth-gate *rule* itself is proven by `resolveRedirect`'s unit tests —
  // this only re-triggers it.
  ref
    ..listen<AsyncValue<AuthState>>(
        authControllerProvider, (_, _) => router.refresh())
    ..listen<AsyncValue<bool>>(
        languageChosenProvider, (_, _) => router.refresh());

  ref.onDispose(router.dispose);
  return router;
});
