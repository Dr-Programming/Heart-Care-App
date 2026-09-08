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
import 'package:libu_care/features/auth/presentation/screens/register_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_database.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

Future<void> _tapSubmit(WidgetTester tester) async {
  final Finder submit = find.byKey(const Key('register_submit'));
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

  testWidgets('does not submit when the confirm PIN differs from the PIN', (
    tester,
  ) async {
    await pumpApp(tester, const RegisterScreen(), overrides: overrides());

    await tester.enterText(
      find.byKey(const Key('register_name')),
      'Abebe Girma',
    );
    await tester.enterText(
      find.byKey(const Key('register_phone')),
      '+251911234567',
    );
    await tester.enterText(find.byKey(const Key('register_pin')), '1234');
    await tester.enterText(
      find.byKey(const Key('register_confirm_pin')),
      '5678',
    );
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('The two PINs do not match'), findsOneWidget);
    verifyNever(
      () => repository.register(
        phone: any(named: 'phone'),
        pin: any(named: 'pin'),
        name: any(named: 'name'),
        language: any(named: 'language'),
      ),
    );
  });

  testWidgets('submits with the exact typed values once the PINs match', (
    tester,
  ) async {
    await pumpApp(tester, const RegisterScreen(), overrides: overrides());
    when(
      () => repository.register(
        phone: any(named: 'phone'),
        pin: any(named: 'pin'),
        name: any(named: 'name'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((_) async => user);

    await tester.enterText(
      find.byKey(const Key('register_name')),
      'Abebe Girma',
    );
    await tester.enterText(
      find.byKey(const Key('register_phone')),
      '+251911234567',
    );
    await tester.enterText(find.byKey(const Key('register_pin')), '1234');
    await tester.enterText(
      find.byKey(const Key('register_confirm_pin')),
      '1234',
    );
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    verify(
      () => repository.register(
        phone: '+251911234567',
        pin: '1234',
        name: 'Abebe Girma',
        language: AppLanguage.en,
      ),
    ).called(1);
  });

  testWidgets('a taken phone number renders the phone-taken message', (
    tester,
  ) async {
    await pumpApp(tester, const RegisterScreen(), overrides: overrides());
    when(
      () => repository.register(
        phone: any(named: 'phone'),
        pin: any(named: 'pin'),
        name: any(named: 'name'),
        language: any(named: 'language'),
      ),
    ).thenThrow(
      const PhoneAlreadyRegisteredFailure('Phone already registered'),
    );

    await tester.enterText(
      find.byKey(const Key('register_name')),
      'Abebe Girma',
    );
    await tester.enterText(
      find.byKey(const Key('register_phone')),
      '+251911234567',
    );
    await tester.enterText(find.byKey(const Key('register_pin')), '1234');
    await tester.enterText(
      find.byKey(const Key('register_confirm_pin')),
      '1234',
    );
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('That phone number is already registered'),
      findsOneWidget,
    );
  });

  testWidgets('renders in Amharic', (tester) async {
    await pumpApp(
      tester,
      const RegisterScreen(),
      overrides: overrides(),
      language: AppLanguage.am,
    );

    expect(find.text('መለያ ይክፈቱ'), findsWidgets);
  });
}
