import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/localization/language.dart';
import '../../../../core/providers/core_providers.dart';
import '../../auth_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Sealed so the router and the screens cannot forget a case.
sealed class AuthState {
  const AuthState();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AuthUser user;
}

class AuthController extends AsyncNotifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Restores the session on start.
  ///
  /// The happy path is disk-only: a valid token plus a cached user means we
  /// land on Home with **no** network call — the offline cold-start the app is
  /// built for. `GET /auth/me` is never reached when the cache is populated.
  ///
  /// The one exception is a valid token with **no** cached user. That should
  /// not happen on mobile, but on web a browser refresh can drop the
  /// Drift/IndexedDB write that `saveSession()` made (the WASM database has no
  /// durability guarantee and the app never closes it) while the JWT in
  /// `localStorage` survives. Rather than force a needless re-login, repopulate
  /// the cache from the server when online; when offline there is nothing to
  /// do but fall back to unauthenticated.
  @override
  Future<AuthState> build() async {
    if (!await _repository.hasValidSession()) {
      return const AuthUnauthenticated();
    }
    final AuthUser? cached = await _repository.cachedUser();
    if (cached != null) return AuthAuthenticated(cached);

    final Future<bool> Function() isOnline = ref.read(isOnlineProvider);
    if (!await isOnline()) return const AuthUnauthenticated();
    try {
      return AuthAuthenticated(await _repository.getMe());
    } on Failure {
      return const AuthUnauthenticated();
    }
  }

  Future<void> login({required String phone, required String pin}) async {
    state = const AsyncValue<AuthState>.loading();
    state = await AsyncValue.guard(() async {
      final AuthUser user = await _repository.login(phone: phone, pin: pin);
      return AuthAuthenticated(user);
    });
  }

  Future<void> register({
    required String phone,
    required String pin,
    required String name,
    required AppLanguage language,
  }) async {
    state = const AsyncValue<AuthState>.loading();
    state = await AsyncValue.guard(() async {
      final AuthUser user = await _repository.register(
        phone: phone, pin: pin, name: name, language: language,
      );
      return AuthAuthenticated(user);
    });
  }

  Future<void> signOut() async {
    await _repository.logout();
    state = const AsyncValue<AuthState>.data(AuthUnauthenticated());
  }
}

final AsyncNotifierProvider<AuthController, AuthState> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
