import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';

import '../../auth_providers.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/pin_repository.dart';
import '../../domain/security_question.dart';

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
    // Sending a PIN change queued offline may have found the PIN changed on
    // another device; tell the patient why their new PIN didn't work.
    if (repo case final PinRepository pins) {
      ref.read(signOutNoticeProvider.notifier).show(pins.takeSignOutReason());
    }
    // A failed attempt keeps the previous (signed-out) value alongside its
    // error, so check for an error too: only a real sign-in resets the
    // screens and starts the download.
    if (state.hasValue && !state.hasError) {
      ref.read(signOutNoticeProvider.notifier).clear();
      ref.read(sessionChangedHandlerProvider)();
      await ref.read(realAuthGateProvider.notifier).refresh();
      _restoreInBackground();
    }
  }

  Future<void> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
    List<SecurityAnswer>? securityAnswers,
    ({String question, String answer})? ownQuestion,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    final PinRepository pins = ref.read(pinRepositoryProvider);
    state = const AsyncValue<AuthState>.loading();
    state = await AsyncValue.guard(() async {
      final user = await repo.register(
        phone: phone,
        pin: pin,
        name: name,
        preferredLanguage: preferredLanguage,
        securityAnswers: securityAnswers,
      );
      return AuthState(user: user);
    });
    if (state.hasValue && !state.hasError) {
      // The patient's own question is kept on this phone only.
      if (ownQuestion != null) {
        try {
          await pins.setCustomQuestion(
            currentPin: pin,
            question: ownQuestion.question,
            answer: ownQuestion.answer,
          );
        } on Object {
          // The account exists either way; it can be added in Settings.
        }
      }
      ref.read(sessionChangedHandlerProvider)();
      await ref.read(realAuthGateProvider.notifier).refresh();
      _restoreInBackground();
    }
  }

  /// Fills the phone with the patient's server records without holding up
  /// the sign-in: the home screen shows, then updates when they arrive.
  void _restoreInBackground() {
    unawaited(ref.read(restoreFromServerProvider)().catchError((Object _) {}));
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    try {
      // While the token still works: anything unsent would otherwise be lost
      // if a different patient signs in next.
      await ref.read(beforeSignOutProvider)();
    } on Object {
      // Offline or failing: sign out anyway; the records stay queued.
    }
    await repo.logout();
    state = const AsyncData<AuthState>(AuthState());
    ref.read(sessionChangedHandlerProvider)();
    await ref.read(realAuthGateProvider.notifier).refresh();
  }
}

final AsyncNotifierProvider<AuthController, AuthState> authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);
