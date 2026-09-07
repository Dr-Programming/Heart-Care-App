import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../auth_providers.dart';
import 'auth_state.dart';

/// Owns the session: resolves it on boot, and carries out login, register and
/// sign-out. The real `AuthGate` reads this controller's [AsyncValue]
/// directly rather than re-deriving session state on its own.
///
/// `login`/`register` deliberately never assign a bare loading [state]:
/// riverpod's `AsyncValue.loading()` carries no value until it resolves, and
/// the real `AuthGate` derives `isSignedIn` from `state.value` — a loading
/// window with no value would read as "signed out" and, worse, would need
/// `copyWithPrevious` (package-internal to riverpod) to avoid it. A submit
/// button tracks its own local "submitting" flag instead; `state` only ever
/// moves directly from one resolved value to the next.
class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final authRepository = ref.watch(authRepositoryProvider);

    if (!await authRepository.hasValidSession()) {
      return const AuthUnauthenticated();
    }

    final cached = await authRepository.cachedUser();
    if (cached != null) return AuthAuthenticated(cached);

    // A valid token with nothing cached: rare (a fresh install that kept the
    // token but not the database), and only worth chasing while online — see
    // `AuthGate`'s doc comment for why this method must never gate on the
    // network itself, only refresh what it can.
    if (!await ref.read(isOnlineProvider)()) {
      return const AuthUnauthenticated();
    }
    try {
      final user = await ref.read(getMeUseCaseProvider)();
      return AuthAuthenticated(user);
    } on Object {
      return const AuthUnauthenticated();
    }
  }

  /// Deliberately does not set a loading [state] first — see the class doc.
  Future<void> login({required String phone, required String pin}) async {
    state = await AsyncValue.guard(() async {
      final user = await ref.read(loginUseCaseProvider)(phone: phone, pin: pin);
      return AuthAuthenticated(user);
    });
  }

  /// Deliberately does not set a loading [state] first — see the class doc.
  Future<void> register({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  }) async {
    state = await AsyncValue.guard(() async {
      final user = await ref.read(registerUseCaseProvider)(
        phone: phone,
        pin: pin,
        name: name,
        language: language,
      );
      return AuthAuthenticated(user);
    });
  }

  Future<void> signOut() async {
    await ref.read(logoutUseCaseProvider)();
    state = const AsyncValue<AuthState>.data(AuthUnauthenticated());
  }
}

final AsyncNotifierProvider<AuthController, AuthState> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
