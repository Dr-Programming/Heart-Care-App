import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/app/visit_summary/visit_summary_screen.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';

import '../../helpers/fake_dio.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  for (final AppLanguage language in AppLanguage.values) {
    testWidgets('a phone with nothing recorded says so (${language.code})', (
      tester,
    ) async {
      final AppDatabase db = testDatabase();
      addTearDown(db.close);

      await pumpApp(
        tester,
        const VisitSummaryScreen(),
        language: language,
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          dioProvider.overrideWithValue(FakeDio().dio),
          isOnlineProvider.overrideWithValue(() async => false),
          onlineStatusProvider.overrideWith((ref) => Stream<bool>.value(true)),
        ],
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      expect(find.text('visitSummary.status.noData'.tr()), findsOneWidget);
      expect(find.text('visitSummary.savePdf'.tr()), findsOneWidget);
    });
  }
}
