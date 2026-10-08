import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/theme/app_colors.dart';
import 'package:libu_care/core/widgets/widgets.dart';
import 'package:libu_care/features/education/presentation/screens/eat_well_screen.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  /// Height of the cream header band of [screen], opened on a phone-sized
  /// display the way the app opens it (pushed, with a back arrow).
  Future<double> bandHeight(
    WidgetTester tester,
    Widget screen,
    AppLanguage language,
  ) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    await pumpApp(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => screen)),
          child: const Text('open'),
        ),
      ),
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      language: language,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return tester
        .getSize(
          find
              .byWidgetPredicate(
                (Widget w) => w is Container && w.color == AppColors.headerBand,
              )
              .first,
        )
        .height;
  }

  for (final AppLanguage language in AppLanguage.values) {
    // A typical pushed screen: title and a one-line subtitle.
    late double standard;

    testWidgets('measures a standard header (${language.name})', (
      tester,
    ) async {
      standard = await bandHeight(
        tester,
        const AppScaffold.banded(
          showBack: false,
          bandChild: BandHeader(title: 'Activity', subtitle: 'This week'),
          body: SizedBox(),
        ),
        language,
      );
    });

    testWidgets(
      'the header is no taller than other screens (${language.name})',
      (tester) async {
        final double eatWell = await bandHeight(
          tester,
          const EatWellScreen(),
          language,
        );

        expect(eatWell, lessThanOrEqualTo(standard));
      },
    );
  }
}
