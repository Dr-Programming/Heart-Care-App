import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/network/server_reachability.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/screens/register_screen.dart';

import '../../../../helpers/pump_app.dart';

const AuthUser _user = AuthUser(
  id: 'u1',
  name: 'Abebe Girma',
  phone: '+251911234567',
  preferredLanguage: 'en',
  role: 'PATIENT',
);

class _RegisterArgs {
  const _RegisterArgs({
    required this.phone,
    required this.pin,
    required this.name,
    required this.preferredLanguage,
  });

  final String phone;
  final String pin;
  final String name;
  final String preferredLanguage;
}

class _FakeAuthRepository implements AuthRepository {
  int registerCalls = 0;
  Object? registerError;
  Future<AuthUser>? registerFuture;
  _RegisterArgs? registerArgs;

  @override
  Future<AuthUser> login({required String phone, required String pin}) async =>
      _user;

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
  }) async {
    registerCalls++;
    registerArgs = _RegisterArgs(
      phone: phone,
      pin: pin,
      name: name,
      preferredLanguage: preferredLanguage,
    );
    if (registerFuture != null) return registerFuture!;
    if (registerError != null) throw registerError!;
    return _user;
  }

  @override
  Future<AuthUser> getMe() async => _user;

  @override
  Future<bool> refreshSession() async => true;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser?> cachedUser() async => null;

  @override
  Future<bool> isSignedIn() async => false;

  @override
  Future<bool> needsOnboarding() async => false;
}

/// Stands in for the real probe, which would otherwise hit `connectivity_plus`
/// (no plugin under `flutter test`) and then a live socket.
class _FakeReachabilityNotifier extends ServerReachabilityNotifier {
  _FakeReachabilityNotifier(this.initial);

  final ServerReachability initial;
  int refreshCalls = 0;

  @override
  ServerReachability build() => initial;

  @override
  Future<void> refresh() async => refreshCalls++;
}

/// Every test needs the screen to know whether the server is there, so this is
/// passed alongside the repository override in all of them.
Override _reachability(
  ServerReachability value, {
  _FakeReachabilityNotifier? notifier,
}) => serverReachabilityProvider.overrideWith(
  () => notifier ?? _FakeReachabilityNotifier(value),
);

/// The overrides for a screen that can reach the server — the baseline every
/// test about the form itself, rather than about the connection, runs under.
List<Override> _online(_FakeAuthRepository repo) => <Override>[
  authRepositoryProvider.overrideWithValue(repo),
  _reachability(ServerReachability.online),
];

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 10),
);

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (var i = 0; i < pin.length; i++) {
    await tester.enterText(find.byType(TextField).at(i + 1), pin[i]);
    await tester.pump();
  }
}

void main() {
  setUpWidgetTests();

  testWidgets('a taken phone shows its error', (tester) async {
    final repo = _FakeAuthRepository()
      ..registerError = const PhoneAlreadyRegisteredFailure(
        'That phone number is already registered',
      );
    await pumpApp(tester, const RegisterScreen(), overrides: _online(repo));

    await tester.enterText(find.byType(TextField).at(0), '+251911234567');
    await _enterPin(tester, '1234');
    await tester.enterText(find.byType(TextField).at(5), 'Abebe Girma');
    final submitButton = find.byKey(const Key('registerSubmitButton'));
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await _settle(tester);

    expect(find.text('auth.errors.phoneTaken'.tr()), findsOneWidget);
    expect(repo.registerCalls, 1);
  });

  testWidgets('English is selected by default and Amharic can be chosen', (
    tester,
  ) async {
    final repo = _FakeAuthRepository();
    await pumpApp(tester, const RegisterScreen(), overrides: _online(repo));
    expect(find.text('English'), findsOneWidget);
    expect(find.text('አማርኛ'), findsOneWidget);
  });

  testWidgets(
    'a successful register calls the controller with the chosen language',
    (tester) async {
      final repo = _FakeAuthRepository();
      await pumpApp(tester, const RegisterScreen(), overrides: _online(repo));

      final amharicOption = find.text('አማርኛ');
      await tester.ensureVisible(amharicOption);
      await _settle(tester);
      await tester.tap(amharicOption);
      await _settle(tester);

      await tester.enterText(find.byType(TextField).at(0), '+251911234567');
      await _enterPin(tester, '1234');
      await tester.enterText(find.byType(TextField).at(5), 'Abebe Girma');
      final submitButton = find.byKey(const Key('registerSubmitButton'));
      await tester.ensureVisible(submitButton);
      await _settle(tester);
      await tester.tap(submitButton);
      await _settle(tester);

      expect(repo.registerCalls, 1);
      expect(repo.registerArgs?.phone, '+251911234567');
      expect(repo.registerArgs?.pin, '1234');
      expect(repo.registerArgs?.name, 'Abebe Girma');
      expect(repo.registerArgs?.preferredLanguage, 'am');
    },
  );

  testWidgets(
    'the submit button shows a loading state and cannot be double-tapped',
    (tester) async {
      final repo = _FakeAuthRepository();

      repo.registerFuture = Completer<AuthUser>().future;
      await pumpApp(tester, const RegisterScreen(), overrides: _online(repo));

      await tester.enterText(find.byType(TextField).at(0), '+251911234567');
      await _enterPin(tester, '1234');
      await tester.enterText(find.byType(TextField).at(5), 'Abebe Girma');

      final submitButton = find.byKey(const Key('registerSubmitButton'));
      await tester.ensureVisible(submitButton);

      await tester.tap(submitButton);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(submitButton, warnIfMissed: false);
      await tester.pump();

      expect(repo.registerCalls, 1);
    },
  );

  testWidgets(
    'submitting with no PIN entered shows pinRequired and never calls '
    'register',
    (tester) async {
      final repo = _FakeAuthRepository();
      await pumpApp(tester, const RegisterScreen(), overrides: _online(repo));

      await tester.enterText(find.byType(TextField).at(0), '+251911234567');
      await tester.enterText(find.byType(TextField).at(5), 'Abebe Girma');
      final submitButton = find.byKey(const Key('registerSubmitButton'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await _settle(tester);

      expect(find.text('auth.errors.pinRequired'.tr()), findsOneWidget);
      expect(repo.registerCalls, 0);
    },
  );

  testWidgets(
    'submitting with an incomplete PIN shows the format error and never '
    'calls register',
    (tester) async {
      final repo = _FakeAuthRepository();
      await pumpApp(tester, const RegisterScreen(), overrides: _online(repo));

      await tester.enterText(find.byType(TextField).at(0), '+251911234567');

      await _enterPin(tester, '123');
      await tester.enterText(find.byType(TextField).at(5), 'Abebe Girma');
      final submitButton = find.byKey(const Key('registerSubmitButton'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await _settle(tester);

      expect(find.text('auth.errors.pinRequired'.tr()), findsOneWidget);
      expect(repo.registerCalls, 0);
    },
  );

  testWidgets(
    'completing a PIN then deleting the last digit blocks submit with the '
    'stale value, without retyping a 4th digit',
    (tester) async {
      final repo = _FakeAuthRepository();
      await pumpApp(tester, const RegisterScreen(), overrides: _online(repo));

      await tester.enterText(find.byType(TextField).at(0), '+251911234567');

      await _enterPin(tester, '1234');

      await tester.enterText(find.byType(TextField).at(4), '');
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(5), 'Abebe Girma');

      final submitButton = find.byKey(const Key('registerSubmitButton'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await _settle(tester);

      expect(find.text('auth.errors.pinRequired'.tr()), findsOneWidget);
      expect(repo.registerCalls, 0);
    },
  );

  testWidgets('renders correctly in Amharic', (tester) async {
    final repo = _FakeAuthRepository();
    await pumpApp(
      tester,
      const RegisterScreen(),
      overrides: _online(repo),
      language: AppLanguage.am,
    );

    expect(find.text('auth.register.title'.tr()), findsWidgets);
  });

  // An account only exists once the server has written it, so a form that can
  // be filled in while nothing is listening only costs the patient their
  // typing. The group below covers the three ways that is prevented: the
  // fields refuse input, every touch says why, and submitting never reaches
  // the repository.
  group('when the server cannot be reached', () {
    for (final (ServerReachability state, String messageKey)
        in <(ServerReachability, String)>[
          (ServerReachability.noInternet, 'errors.noInternet'),
          (ServerReachability.noServer, 'errors.serverUnreachable'),
          (ServerReachability.checking, 'errors.checkingConnection'),
        ]) {
      testWidgets('$state disables every field', (tester) async {
        final repo = _FakeAuthRepository();
        await pumpApp(
          tester,
          const RegisterScreen(),
          overrides: <Override>[
            authRepositoryProvider.overrideWithValue(repo),
            _reachability(state),
          ],
        );

        // Phone, four PIN boxes, name — the whole form.
        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(6));
        for (var i = 0; i < 6; i++) {
          expect(
            tester.widget<TextField>(fields.at(i)).enabled,
            isFalse,
            reason: 'field $i should refuse focus while $state',
          );
        }
      });

      testWidgets('$state explains itself when a field is touched', (
        tester,
      ) async {
        final repo = _FakeAuthRepository();
        await pumpApp(
          tester,
          const RegisterScreen(),
          overrides: <Override>[
            authRepositoryProvider.overrideWithValue(repo),
            _reachability(state),
          ],
        );

        // Aimed at the phone field, which is where someone would start
        // typing; `warnIfMissed` is off because the whole point is that the
        // overlay takes the press instead of the field.
        await tester.tap(find.byType(TextField).first, warnIfMissed: false);
        await tester.pump();

        // Once in the toast, once in the standing notice above the form.
        expect(find.text(messageKey.tr()), findsNWidgets(2));
      });
    }

    testWidgets('tapping submit toasts instead of calling register', (
      tester,
    ) async {
      final repo = _FakeAuthRepository();
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repo),
          _reachability(ServerReachability.noInternet),
        ],
      );

      final submitButton = find.byKey(const Key('registerSubmitButton'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pump();

      expect(find.text('errors.noInternet'.tr()), findsNWidgets(2));
      expect(repo.registerCalls, 0);
    });

    testWidgets('a blocked touch re-probes, so the form can unlock itself', (
      tester,
    ) async {
      final repo = _FakeAuthRepository();
      final notifier = _FakeReachabilityNotifier(ServerReachability.noServer);
      await pumpApp(
        tester,
        const RegisterScreen(),
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repo),
          _reachability(ServerReachability.noServer, notifier: notifier),
        ],
      );
      // The screen re-checks on open too; only the taps below are asserted on.
      final baseline = notifier.refreshCalls;

      await tester.tap(find.byType(TextField).first, warnIfMissed: false);
      await tester.pump();

      final retry = find.byKey(const Key('registerRetryConnectionButton'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();

      expect(notifier.refreshCalls - baseline, 2);
    });

    testWidgets(
      '"checking" shows no retry button, since one is already running',
      (tester) async {
        final repo = _FakeAuthRepository();
        await pumpApp(
          tester,
          const RegisterScreen(),
          overrides: <Override>[
            authRepositoryProvider.overrideWithValue(repo),
            _reachability(ServerReachability.checking),
          ],
        );

        expect(
          find.byKey(const Key('registerConnectionNotice')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('registerRetryConnectionButton')),
          findsNothing,
        );
      },
    );
  });

  testWidgets('a reachable server leaves the form open and unmarked', (
    tester,
  ) async {
    final repo = _FakeAuthRepository();
    await pumpApp(tester, const RegisterScreen(), overrides: _online(repo));

    expect(find.byKey(const Key('registerConnectionNotice')), findsNothing);
    expect(find.byKey(const Key('registerBlockedOverlay')), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      isTrue,
    );
  });
}
