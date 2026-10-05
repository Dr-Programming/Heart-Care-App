import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/activity/presentation/screens/activity_form_screen.dart';
import 'package:libu_care/features/activity/presentation/screens/activity_screen.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  List<Override> overrides(AppDatabase db) => <Override>[
    appDatabaseProvider.overrideWithValue(db),
    onlineStatusProvider.overrideWith((ref) => Stream<bool>.value(true)),
  ];

  for (final AppLanguage language in AppLanguage.values) {
    testWidgets(
      'the activity screen shows the weekly goal (${language.code})',
      (tester) async {
        final AppDatabase db = testDatabase();
        addTearDown(db.close);

        await pumpApp(
          tester,
          const ActivityScreen(),
          overrides: overrides(db),
          language: language,
        );
        await tester.pumpAndSettle();

        expect(find.text('activity.emptyTitle'.tr()), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
      },
    );

    testWidgets(
      'the log form renders every type and intensity (${language.code})',
      (tester) async {
        final AppDatabase db = testDatabase();
        addTearDown(db.close);

        await pumpApp(
          tester,
          const ActivityFormScreen(),
          overrides: overrides(db),
          language: language,
        );
        await tester.pumpAndSettle();

        expect(find.text('activity.type.FARMING'.tr()), findsOneWidget);
        expect(find.text('activity.intensity.VIGOROUS'.tr()), findsOneWidget);
      },
    );
  }
}
