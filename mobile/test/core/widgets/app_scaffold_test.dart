import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/widgets/widgets.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  testWidgets('a screen with a title shows it in the cream header band', (
    tester,
  ) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      const AppScaffold(title: 'Settings', body: SizedBox()),
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.widgetWithText(BandHeader, 'Settings'), findsOneWidget);
  });

  testWidgets('header actions sit beside the title', (tester) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      AppScaffold(
        title: 'Medicines',
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.history), onPressed: () {}),
        ],
        body: const SizedBox(),
      ),
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(BandHeader),
        matching: find.byIcon(Icons.history),
      ),
      findsOneWidget,
    );
  });
}
