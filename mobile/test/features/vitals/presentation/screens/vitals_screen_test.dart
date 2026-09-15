import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/vitals/presentation/screens/vitals_screen.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  testWidgets('the vitals tab root renders without throwing', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);

    await pumpApp(
      tester,
      const VitalsScreen(),
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    await tester.pumpAndSettle();

    expect(find.byType(VitalsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
