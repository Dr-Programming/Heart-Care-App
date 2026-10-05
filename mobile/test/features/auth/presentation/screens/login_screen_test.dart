import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/screens/login_screen.dart';
import 'package:libu_care/features/auth/presentation/widgets/pin_box_input.dart';

import '../../../../helpers/pump_app.dart';

import 'package:libu_care/features/auth/domain/security_question.dart';

const AuthUser _user = AuthUser(
  id: 'u1',
  name: 'Abebe Girma',
  phone: '+251911234567',
  preferredLanguage: 'en',
  role: 'PATIENT',
);

class _FakeAuthRepository implements AuthRepository {
  int loginCalls = 0;
  Object? loginError;
  Future<AuthUser>? loginFuture;

  @override
  Future<AuthUser> login({required String phone, required String pin}) async {
    loginCalls++;
    if (loginFuture != null) return loginFuture!;
    if (loginError != null) throw loginError!;
    return _user;
  }

  @override
  Future<AuthUser> register({
    required String phone,
    required String pin,
    required String name,
    required String preferredLanguage,
    List<SecurityAnswer>? securityAnswers,
  }) async => _user;

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

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 10),
);

void main() {
  setUpWidgetTests();

  testWidgets('the PIN is entered in four boxes, like at sign-up', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ],
    );
    expect(find.byType(PinBoxInput), findsOneWidget);
  });

  testWidgets('an invalid phone shows an inline error and does not submit', (
    tester,
  ) async {
    final repo = _FakeAuthRepository();
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byType(TextField).at(0), '0911234567');
    await tester.tap(find.text('auth.login.submit'.tr()));
    await tester.pump();

    expect(find.text('auth.errors.phoneFormat'.tr()), findsOneWidget);
    expect(repo.loginCalls, 0);
  });

  testWidgets('a wrong PIN shows the credentials error', (tester) async {
    final repo = _FakeAuthRepository()
      ..loginError = const InvalidCredentialsFailure('Invalid phone or PIN');
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byType(TextField).at(0), '+251911234567');
    await _enterPin(tester, '0000');
    await tester.tap(find.text('auth.login.submit'.tr()));
    await _settle(tester);

    expect(find.text('auth.errors.invalidCredentials'.tr()), findsOneWidget);
    expect(repo.loginCalls, 1);
  });

  testWidgets('423 shows the wait message with the minutes remaining', (
    tester,
  ) async {
    final repo = _FakeAuthRepository()
      ..loginError = const AccountLockedFailure(
        'Too many attempts. Try again in 15 minutes.',
        minutesRemaining: 15,
      );
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byType(TextField).at(0), '+251911234567');
    await _enterPin(tester, '1234');
    await tester.tap(find.text('auth.login.submit'.tr()));
    await _settle(tester);

    expect(
      find.text('auth.errors.locked'.tr(namedArgs: {'minutes': '15'})),
      findsOneWidget,
    );
    expect(repo.loginCalls, 1);
  });

  testWidgets('offline shows the offline message and never submits', (
    tester,
  ) async {
    final repo = _FakeAuthRepository()
      ..loginError = const NetworkFailure(
        'You need a connection to sign in the first time',
      );
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byType(TextField).at(0), '+251911234567');
    await _enterPin(tester, '1234');
    await tester.tap(find.text('auth.login.submit'.tr()));
    await _settle(tester);

    expect(find.text('errors.offline'.tr()), findsOneWidget);
    expect(repo.loginCalls, 1);

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'the submit button shows a loading state and cannot be double-tapped',
    (tester) async {
      final repo = _FakeAuthRepository();

      repo.loginFuture = Completer<AuthUser>().future;
      await pumpApp(
        tester,
        const LoginScreen(),
        overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
      );

      await tester.enterText(find.byType(TextField).at(0), '+251911234567');
      await _enterPin(tester, '1234');

      final submitButton = find.byKey(const Key('loginSubmitButton'));

      await tester.tap(submitButton);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(submitButton, warnIfMissed: false);
      await tester.pump();

      expect(repo.loginCalls, 1);
    },
  );

  testWidgets('renders correctly in Amharic', (tester) async {
    final repo = _FakeAuthRepository();
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
      language: AppLanguage.am,
    );
    expect(find.text('auth.login.title'.tr()), findsOneWidget);
  });

  testWidgets('offline, a different patient is told to connect first', (
    tester,
  ) async {
    final repo = _FakeAuthRepository()
      ..loginError = const PatientSwitchFailure(
        'switch',
        needsConnection: true,
        previousPatient: 'Hana',
      );
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
    );

    await tester.enterText(find.byType(TextField).at(0), '+251911234567');
    await _enterPin(tester, '1234');
    await tester.tap(find.text('auth.login.submit'.tr()));
    await _settle(tester);

    expect(
      find.text(
        'auth.switch.needsConnection'.tr(
          namedArgs: <String, String>{'name': 'Hana'},
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('auth.switch.discardTitle'.tr()), findsNothing);
  });

  testWidgets(
    'with unsent records, deleting them on request lets the new patient in',
    (tester) async {
      int discarded = 0;
      final repo = _FakeAuthRepository()
        ..loginError = const PatientSwitchFailure(
          'switch',
          needsConnection: false,
          previousPatient: 'Hana',
          unsentRecords: 2,
        );
      await pumpApp(
        tester,
        const LoginScreen(),
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repo),
          discardUnsentRecordsProvider.overrideWithValue(() async {
            discarded++;
            repo.loginError = null;
          }),
        ],
      );

      await tester.enterText(find.byType(TextField).at(0), '+251911234567');
      await _enterPin(tester, '1234');
      await tester.tap(find.text('auth.login.submit'.tr()));
      await _settle(tester);

      expect(find.text('auth.switch.discardTitle'.tr()), findsOneWidget);
      await tester.tap(find.text('auth.switch.discardConfirm'.tr()));
      await _settle(tester);

      expect(discarded, 1);
      expect(repo.loginCalls, 2);
    },
  );

  testWidgets('keeping the unsent records leaves them and does not sign in', (
    tester,
  ) async {
    int discarded = 0;
    final repo = _FakeAuthRepository()
      ..loginError = const PatientSwitchFailure(
        'switch',
        needsConnection: false,
        previousPatient: 'Hana',
        unsentRecords: 2,
      );
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repo),
        discardUnsentRecordsProvider.overrideWithValue(() async => discarded++),
      ],
    );

    await tester.enterText(find.byType(TextField).at(0), '+251911234567');
    await _enterPin(tester, '1234');
    await tester.tap(find.text('auth.login.submit'.tr()));
    await _settle(tester);
    await tester.tap(find.text('auth.switch.keep'.tr()));
    await _settle(tester);

    expect(discarded, 0);
    expect(repo.loginCalls, 1);
  });
}

/// The PIN is four boxes, after the phone field.
Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (int i = 0; i < pin.length; i++) {
    await tester.enterText(find.byType(TextField).at(1 + i), pin[i]);
    await tester.pump();
  }
}
