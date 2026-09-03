import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/screens/register_screen.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Keeps `RegisterScreen.initState` off the real Drift/`path_provider` stack —
/// it reads the stored language on open.
class _FakeLanguageStore implements LanguageStore {
  @override
  Future<AppLanguage?> read() async => null;

  @override
  Future<bool> hasChosen() async => false;

  @override
  Future<void> write(AppLanguage language) async {}
}

void main() {
  late MockAuthRepository repo;

  // mocktail needs a concrete fallback for `any(named: 'language')` because
  // AppLanguage is a non-nullable custom type.
  setUpAll(() => registerFallbackValue(AppLanguage.en));
  setUpAll(initLocalization);

  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.hasValidSession()).thenAnswer((_) async => false);
    when(() => repo.cachedUser()).thenAnswer((_) async => null);
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
        tester,
        const RegisterScreen(),
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(repo),
          languageStoreProvider.overrideWithValue(_FakeLanguageStore()),
        ],
      );

  testWidgets('will not submit when the two PINs differ', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('register_phone')), '+251911234567');
    await tester.enterText(find.byKey(const Key('register_name')), 'Abebe Bekele');
    await tester.enterText(find.byKey(const Key('register_pin')), '1234');
    await tester.enterText(find.byKey(const Key('register_confirm_pin')), '4321');
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();
    verifyNever(() => repo.register(
          phone: any(named: 'phone'), pin: any(named: 'pin'),
          name: any(named: 'name'), language: any(named: 'language'),
        ));
  });

  testWidgets('submits when every field is valid', (tester) async {
    when(() => repo.register(
          phone: any(named: 'phone'), pin: any(named: 'pin'),
          name: any(named: 'name'), language: any(named: 'language'),
        )).thenThrow(Exception('stop here'));
    await pump(tester);
    await tester.enterText(find.byKey(const Key('register_phone')), '+251911234567');
    await tester.enterText(find.byKey(const Key('register_name')), 'Abebe Bekele');
    await tester.enterText(find.byKey(const Key('register_pin')), '1234');
    await tester.enterText(find.byKey(const Key('register_confirm_pin')), '1234');
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pumpAndSettle();
    verify(() => repo.register(
          phone: '+251911234567', pin: '1234', name: 'Abebe Bekele',
          language: any(named: 'language'),
        )).called(1);
  });
}
