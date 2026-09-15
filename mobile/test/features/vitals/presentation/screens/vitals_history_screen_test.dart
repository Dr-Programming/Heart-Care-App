import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/vitals/presentation/screens/vitals_history_screen.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  testWidgets('the history list shows the empty state with no readings', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);

    await pumpApp(
      tester,
      const VitalsHistoryScreen(),
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );

    expect(find.text('No readings yet'), findsOneWidget);
  });
}
