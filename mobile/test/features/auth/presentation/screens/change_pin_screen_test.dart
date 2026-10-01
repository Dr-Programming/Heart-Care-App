import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/error/failure.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/auth/auth_providers.dart';
import 'package:libu_care/features/auth/domain/repositories/pin_repository.dart';
import 'package:libu_care/features/auth/presentation/screens/change_pin_screen.dart';

import '../../../../helpers/fake_pin_repository.dart';
import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  late FakePinRepository repo;

  Future<void> pump(WidgetTester tester) async {
    repo = FakePinRepository();
    final db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      const ChangePinScreen(),
      overrides: <Override>[
        pinRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(StubAuthRepository()),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
  }

  Future<void> fill(WidgetTester tester, String current, String next, String confirm) async {
    await tester.enterText(find.byType(TextField).at(0), current);
    await tester.enterText(find.byType(TextField).at(1), next);
    await tester.enterText(find.byType(TextField).at(2), confirm);
    await tester.tap(find.byKey(const Key('changePinSubmit')));
    await tester.pumpAndSettle();
  }

  testWidgets('sends the current and new PIN', (tester) async {
    await pump(tester);
    await fill(tester, '1234', '5678', '5678');

    expect(repo.changes.single, (currentPin: '1234', newPin: '5678'));
  });

  testWidgets('a queued change tells the patient it reaches the server later', (tester) async {
    await pump(tester);
    repo.outcome = PinChangeOutcome.queued;
    await fill(tester, '1234', '5678', '5678');

    expect(find.text('auth.changePin.queued'.tr()), findsOneWidget);
  });

  testWidgets('a mismatched confirmation is caught before sending', (tester) async {
    await pump(tester);
    await fill(tester, '1234', '5678', '5679');

    expect(find.text('auth.errors.pinMismatch'.tr()), findsOneWidget);
    expect(repo.changes, isEmpty);
  });

  testWidgets('the new PIN must differ from the current one', (tester) async {
    await pump(tester);
    await fill(tester, '1234', '1234', '1234');

    expect(find.text('auth.changePin.sameAsCurrent'.tr()), findsOneWidget);
    expect(repo.changes, isEmpty);
  });

  testWidgets('a wrong current PIN shows its error', (tester) async {
    await pump(tester);
    repo.error = const InvalidCredentialsFailure('Current PIN is incorrect');
    await fill(tester, '9999', '5678', '5678');

    expect(find.text('auth.changePin.wrongCurrent'.tr()), findsOneWidget);
  });
}
