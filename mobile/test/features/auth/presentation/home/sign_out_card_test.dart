import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/repositories/auth_repository.dart';
import 'package:libu_care/features/auth/presentation/home/sign_out_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  setUpWidgetTests();
  setUpAll(() => registerFallbackValue(AppLanguage.en));

  late MockAuthRepository repository;
  late AppDatabase database;

  List<Override> overrides() {
    repository = MockAuthRepository();
    database = testDatabase();
    addTearDown(database.close);
    when(() => repository.hasValidSession()).thenAnswer((_) async => false);
    when(() => repository.logout()).thenAnswer((_) async {});
    return <Override>[
      authRepositoryProvider.overrideWithValue(repository),
      appDatabaseProvider.overrideWithValue(database),
    ];
  }

  testWidgets('confirming the sheet clears the session', (tester) async {
    await pumpApp(tester, const SignOutCard(), overrides: overrides());

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    // The sheet is up: its title, plus a second "Sign out" as the confirm.
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    verify(() => repository.logout()).called(1);
  });

  testWidgets('dismissing the sheet leaves the session alone', (tester) async {
    await pumpApp(tester, const SignOutCard(), overrides: overrides());

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);

    // Tapping the cancel action is a no, and so is dismissing the sheet.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.logout());
  });

  testWidgets('renders in Amharic', (tester) async {
    await pumpApp(
      tester,
      const SignOutCard(),
      overrides: overrides(),
      language: AppLanguage.am,
    );

    expect(find.text('ውጣ'), findsOneWidget);
  });
}
