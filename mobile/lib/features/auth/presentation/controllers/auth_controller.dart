import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/language.dart';
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

  /// Restores the session from disk only.
  ///
  /// Deliberately does **not** call `GET /auth/me` — that would make a cold
  /// start fail without a network, the exact scenario the app is built for.
  /// The token's `exp` is checked locally; if the server has since rejected
  /// it, the first authenticated request surfaces that.
  @override
  Future<AuthState> build() async {
    if (!await _repository.hasValidSession()) {
      return const AuthUnauthenticated();
    }
    final AuthUser? cached = await _repository.cachedUser();
    return cached == null
        ? const AuthUnauthenticated()
        : AuthAuthenticated(cached);
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
