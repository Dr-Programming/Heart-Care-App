import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/screens/login_screen.dart';
import 'package:libu_care/features/auth/presentation/widgets/failure_message.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

Future<void> pumpLogin(WidgetTester tester, AuthRepository repo) => pumpScreen(
      tester,
      const LoginScreen(),
      overrides: <Override>[authRepositoryProvider.overrideWithValue(repo)],
    );

void main() {
  late MockAuthRepository repo;

  setUpAll(initLocalization);

  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.hasValidSession()).thenAnswer((_) async => false);
    when(() => repo.cachedUser()).thenAnswer((_) async => null);
  });

  testWidgets('rejects a local 0-prefixed phone without calling the API', (tester) async {
    await pumpLogin(tester, repo);
    await tester.enterText(find.byKey(const Key('login_phone')), '0911234567');
    await tester.enterText(find.byKey(const Key('login_pin')), '1234');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    verifyNever(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')));
  });

  testWidgets('rejects a 3-digit PIN', (tester) async {
    await pumpLogin(tester, repo);
    await tester.enterText(find.byKey(const Key('login_phone')), '+251911234567');
    await tester.enterText(find.byKey(const Key('login_pin')), '123');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    verifyNever(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')));
  });

  testWidgets('submits valid credentials to the repository', (tester) async {
    when(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
        .thenThrow(const InvalidCredentialsFailure('Invalid phone or PIN'));
    await pumpLogin(tester, repo);
    await tester.enterText(find.byKey(const Key('login_phone')), '+251911234567');
    await tester.enterText(find.byKey(const Key('login_pin')), '1234');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    verify(() => repo.login(phone: '+251911234567', pin: '1234')).called(1);
  });

  testWidgets('a lockout is shown as a wait, not a wrong PIN', (tester) async {
    when(() => repo.login(phone: any(named: 'phone'), pin: any(named: 'pin')))
        .thenThrow(const AccountLockedFailure(
            'Too many failed attempts. Try again in 12 minutes.',
            minutesRemaining: 12));
    await pumpLogin(tester, repo);
    await tester.enterText(find.byKey(const Key('login_phone')), '+251911234567');
    await tester.enterText(find.byKey(const Key('login_pin')), '9999');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pumpAndSettle();
    expect(find.byType(FailureMessage), findsOneWidget);
    expect(find.text('Too many attempts. Try again in 12 min.'), findsOneWidget);
    expect(find.text('Invalid phone or PIN'), findsNothing);
  });
}
