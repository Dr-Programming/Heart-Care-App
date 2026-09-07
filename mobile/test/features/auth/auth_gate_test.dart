import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/router/auth_gate.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/presentation/controllers/auth_state.dart';

/// Resolves a [FutureProvider] once, then invalidates it and captures the
/// [AsyncValue] mid-refresh — i.e. exactly the transitional state Riverpod
/// produces when `LanguageScreen` invalidates `languageChosenProvider` after
/// writing a choice. There is no public constructor for a loading
/// [AsyncValue] carrying a previous value (`copyWithPrevious` is
/// `@internal`), so the only faithful way to produce one is to make Riverpod
/// do it for real.
Future<AsyncValue<T>> _midRefreshSnapshot<T>(T value) async {
  final List<Completer<T>> completers = <Completer<T>>[
    Completer<T>()..complete(value),
  ];
  final FutureProvider<T> provider = FutureProvider<T>(
    (Ref ref) => completers.last.future,
  );
  final ProviderContainer container = ProviderContainer();
  final ProviderSubscription<AsyncValue<T>> subscription = container.listen(
    provider,
    (AsyncValue<T>? previous, AsyncValue<T> next) {},
  );
  await container.read(provider.future);

  completers.add(Completer<T>());
  container.invalidate(provider);
  final AsyncValue<T> snapshot = container.read(provider);

  completers.last.complete(value);
  await container.read(provider.future);
  subscription.close();
  container.dispose();

  return snapshot;
}

void main() {
  const AuthUser user = AuthUser(
    id: 'u1',
    name: 'Abebe Girma',
    phone: '+251911234567',
    preferredLanguage: 'en',
    role: 'PATIENT',
  );

  test('not resolved while the initial session check is still loading', () {
    const AuthGate gate = RealAuthGate(
      authState: AsyncValue<AuthState>.loading(),
      languageChosen: AsyncValue<bool>.data(true),
    );

    expect(gate.isResolved, isFalse);
  });

  test('not resolved while the language check is still loading', () {
    const AuthGate gate = RealAuthGate(
      authState: AsyncValue<AuthState>.data(AuthUnauthenticated()),
      languageChosen: AsyncValue<bool>.loading(),
    );

    expect(gate.isResolved, isFalse);
  });

  test('signed in once the session resolves to an authenticated user', () {
    const AuthGate gate = RealAuthGate(
      authState: AsyncValue<AuthState>.data(AuthAuthenticated(user)),
      languageChosen: AsyncValue<bool>.data(true),
    );

    expect(gate.isResolved, isTrue);
    expect(gate.isSignedIn, isTrue);
  });

  test('not signed in once the session resolves to unauthenticated', () {
    const AuthGate gate = RealAuthGate(
      authState: AsyncValue<AuthState>.data(AuthUnauthenticated()),
      languageChosen: AsyncValue<bool>.data(true),
    );

    expect(gate.isSignedIn, isFalse);
  });

  test('a failed login stays resolved and signed out, rather than bouncing '
      'back to unresolved', () {
    final AuthGate gate = RealAuthGate(
      authState: AsyncValue<AuthState>.error(
        Exception('invalid credentials'),
        StackTrace.empty,
      ),
      languageChosen: const AsyncValue<bool>.data(true),
    );

    expect(gate.isResolved, isTrue);
    expect(gate.isSignedIn, isFalse);
  });

  test('needsOnboarding is always false in this slice', () {
    const AuthGate gate = RealAuthGate(
      authState: AsyncValue<AuthState>.data(AuthAuthenticated(user)),
      languageChosen: AsyncValue<bool>.data(true),
    );

    expect(gate.needsOnboarding, isFalse);
  });

  test('hasChosenLanguage reflects the resolved language check', () {
    const AuthGate signed = RealAuthGate(
      authState: AsyncValue<AuthState>.data(AuthUnauthenticated()),
      languageChosen: AsyncValue<bool>.data(false),
    );

    expect(signed.hasChosenLanguage, isFalse);
  });

  test(
    'stays resolved while languageChosen refreshes with a cached value '
    '(LanguageScreen invalidating after a write must not bounce to splash)',
    () async {
      final AsyncValue<bool> refreshing = await _midRefreshSnapshot<bool>(true);
      // Confirms this test actually captured a refresh, not a settled value
      // — otherwise the assertion below would pass for the wrong reason.
      expect(refreshing.isLoading, isTrue);
      expect(refreshing.hasValue, isTrue);

      final AuthGate gate = RealAuthGate(
        authState: const AsyncValue<AuthState>.data(AuthUnauthenticated()),
        languageChosen: refreshing,
      );

      expect(gate.isResolved, isTrue);
    },
  );

  test(
    'stays resolved while the session refreshes with a cached value',
    () async {
      final AsyncValue<AuthState> refreshing =
          await _midRefreshSnapshot<AuthState>(const AuthAuthenticated(user));
      expect(refreshing.isLoading, isTrue);
      expect(refreshing.hasValue, isTrue);

      final AuthGate gate = RealAuthGate(
        authState: refreshing,
        languageChosen: const AsyncValue<bool>.data(true),
      );

      expect(gate.isResolved, isTrue);
    },
  );
}
