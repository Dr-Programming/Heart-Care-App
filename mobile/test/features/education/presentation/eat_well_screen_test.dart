import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/education/domain/eat_well.dart';
import 'package:libu_care/features/education/presentation/screens/eat_well_screen.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

Object? _lookup(Map<String, dynamic> json, String key) {
  Object? node = json;
  for (final String part in key.split('.')) {
    if (node is! Map<String, dynamic>) return null;
    node = node[part];
  }
  return node;
}

void main() {
  setUpWidgetTests();

  for (final AppLanguage language in AppLanguage.values) {
    test('every Eat well text exists in ${language.code}', () {
      final Map<String, dynamic> json = jsonDecode(
        File('assets/translations/${language.code}.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final List<String> keys = <String>[
        for (final FoodGroup group in <FoodGroup>[
          ...recommendedFoods,
          ...limitFoods,
        ]) ...<String>[
          group.titleKey,
          group.bodyKey,
          for (final String item in group.items) group.itemKey(item),
        ],
        for (final String step in eatingPatternSteps)
          'education.eatWell.pattern.$step',
      ];

      for (final String key in keys) {
        expect(_lookup(json, key), isA<String>(), reason: key);
      }
    });

    testWidgets(
      'switching to Limit shows the foods to cut down on (${language.code})',
      (tester) async {
        final AppDatabase db = testDatabase();
        addTearDown(db.close);
        await pumpApp(
          tester,
          const EatWellScreen(),
          language: language,
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            onlineStatusProvider.overrideWith(
              (ref) => Stream<bool>.value(true),
            ),
          ],
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'education.eatWell.groups.wholeGrains.items.teffInjera'.tr(),
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('education.eatWell.limit'.tr()));
        await tester.pumpAndSettle();

        expect(
          find.text('education.eatWell.groups.salt.title'.tr()),
          findsOneWidget,
        );
        expect(
          find.text(
            'education.eatWell.groups.wholeGrains.items.teffInjera'.tr(),
          ),
          findsNothing,
        );
      },
    );
  }
}
