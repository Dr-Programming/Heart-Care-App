import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_providers.dart';
import '../../domain/entities/auth_user.dart';

class AuthState {
  const AuthState({this.user});
  final AuthUser? user;

  bool get isAuthenticated => user != null;
}

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final repo = ref.watch(authRepositoryProvider);
    final user = await repo.cachedUser();
    return AuthState(user: user);
  }

  Future<void> login({required String phone, required String pin}) async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncValue<AuthState>.loading();
    state = await AsyncValue.guard(() async {
      final user = await repo.login(phone: phone, pin: pin);
      return AuthState(user: user);
    });
    if (state.hasValue) {
      await ref.read(realAuthGateProvider.notifier).refresh();
    }
  }

  Future<void> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncValue<AuthState>.loading();
    state = await AsyncValue.guard(() async {
      final user = await repo.register(
        phone: phone,
        pin: pin,
        name: name,
        preferredLanguage: preferredLanguage,
      );
      return AuthState(user: user);
    });
    if (state.hasValue) {
      await ref.read(realAuthGateProvider.notifier).refresh();
    }
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData<AuthState>(AuthState());
    await ref.read(realAuthGateProvider.notifier).refresh();
  }
}

final AsyncNotifierProvider<AuthController, AuthState> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
