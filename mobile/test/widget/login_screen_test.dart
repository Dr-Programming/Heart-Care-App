import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/screens/login_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

Future<void> _tapSubmit(WidgetTester tester) async {
  final Finder submit = find.byKey(const Key('login_submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
}

void main() {
  setUpWidgetTests();
  setUpAll(() => registerFallbackValue(AppLanguage.en));

  const AuthUser user = AuthUser(
    id: 'u1',
    name: 'Abebe Girma',
    phone: '+251911234567',
    preferredLanguage: 'en',
    role: 'PATIENT',
  );

  late MockAuthRepository repository;
  late AppDatabase database;

  List<Override> overrides() {
    repository = MockAuthRepository();
    database = testDatabase();
    addTearDown(database.close);
    when(() => repository.hasValidSession()).thenAnswer((_) async => false);
    return <Override>[
      authRepositoryProvider.overrideWithValue(repository),
      isOnlineProvider.overrideWithValue(() async => true),
      appDatabaseProvider.overrideWithValue(database),
    ];
  }

  testWidgets(
    'rejects a local phone number and a short PIN without calling the repository',
    (tester) async {
      await pumpApp(tester, const LoginScreen(), overrides: overrides());

      await tester.enterText(
        find.byKey(const Key('login_phone')),
        '0911234567',
      );
      await tester.enterText(find.byKey(const Key('login_pin')), '12');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a phone number as +251 followed by 9 digits'),
        findsOneWidget,
      );
      expect(find.text('Your PIN must be exactly 4 digits'), findsOneWidget);
      verifyNever(
        () => repository.login(
          phone: any(named: 'phone'),
          pin: any(named: 'pin'),
        ),
      );
    },
  );

  testWidgets('submits valid credentials with the exact typed values', (
    tester,
  ) async {
    await pumpApp(tester, const LoginScreen(), overrides: overrides());
    when(
      () => repository.login(
        phone: any(named: 'phone'),
        pin: any(named: 'pin'),
      ),
    ).thenAnswer((_) async => user);

    await tester.enterText(
      find.byKey(const Key('login_phone')),
      '+251911234567',
    );
    await tester.enterText(find.byKey(const Key('login_pin')), '1234');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    verify(() => repository.login(phone: '+251911234567', pin: '1234'))
        .called(1);
  });

  testWidgets(
    'a lockout renders the parsed wait time, never the wrong-PIN message',
    (tester) async {
      await pumpApp(tester, const LoginScreen(), overrides: overrides());
      when(
        () => repository.login(
          phone: any(named: 'phone'),
          pin: any(named: 'pin'),
        ),
      ).thenThrow(
        const AccountLockedFailure(
          'Too many failed attempts. Try again in 12 minutes.',
          minutesRemaining: 12,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('login_phone')),
        '+251911234567',
      );
      await tester.enterText(find.byKey(const Key('login_pin')), '0000');
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(
        find.text('Too many attempts. Try again in 12 min.'),
        findsOneWidget,
      );
      expect(find.text('Invalid phone or PIN'), findsNothing);
    },
  );

  testWidgets('renders in Amharic', (tester) async {
    await pumpApp(
      tester,
      const LoginScreen(),
      overrides: overrides(),
      language: AppLanguage.am,
    );

    expect(find.text('እንኳን ደህና መጡ'), findsOneWidget);
    expect(find.text('ግባ'), findsOneWidget);
  });
}
