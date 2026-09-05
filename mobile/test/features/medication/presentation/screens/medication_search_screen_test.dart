import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_search_screen.dart';

import '../../../../helpers/pump_app.dart';

class _PopResult {
  bool popped = false;
  MedicationSearchOutcome? value;
}

Widget _harness(_PopResult box) {
  return Builder(
    builder: (BuildContext context) => Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final MedicationSearchOutcome? outcome = await Navigator.of(
              context,
            ).push<MedicationSearchOutcome>(
              MaterialPageRoute<MedicationSearchOutcome>(
                builder: (_) => const MedicationSearchScreen(),
              ),
            );
            box
              ..popped = true
              ..value = outcome;
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  setUpWidgetTests();

  testWidgets('typing a query shows matching suggestions', (tester) async {
    await pumpApp(tester, const MedicationSearchScreen());

    await tester.enterText(find.byType(TextField).first, 'Metop');
    await tester.pumpAndSettle();

    expect(find.textContaining('Metoprolol'), findsWidgets);
  });

  testWidgets(
    'shows the cantFind guidance on the initial empty-query state',
    (tester) async {
      await pumpApp(tester, const MedicationSearchScreen());

      expect(find.text('meds.search.libraryHint'.tr()), findsOneWidget);
      expect(find.text('meds.search.cantFind'.tr()), findsOneWidget);

      expect(find.text('meds.search.suggestions'.tr()), findsNothing);
    },
  );

  testWidgets(
    'shows the cantFind guidance when a search returns zero results',
    (tester) async {
      await pumpApp(tester, const MedicationSearchScreen());

      await tester.enterText(
        find.byType(TextField).first,
        'no medication matches this query',
      );
      await tester.pumpAndSettle();

      expect(find.text('meds.search.libraryHint'.tr()), findsOneWidget);
      expect(find.text('meds.search.cantFind'.tr()), findsOneWidget);
      expect(find.text('meds.search.suggestions'.tr()), findsNothing);
    },
  );

  testWidgets(
    'tapping a suggestion pops a populated MedicationSearchOutcome (proceed with that entry)',
    (tester) async {
      final _PopResult box = _PopResult();
      await pumpApp(tester, _harness(box));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Metoprolol');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Metoprolol 50 mg'));
      await tester.pumpAndSettle();

      expect(box.popped, isTrue);
      expect(box.value, isNotNull);
      expect(box.value!.entry, isNotNull);
      expect(box.value!.entry!.name, 'Metoprolol');
    },
  );

  testWidgets(
    'tapping Enter manually pops a MedicationSearchOutcome with a null entry '
    '(proceed with a blank form)',
    (tester) async {
      final _PopResult box = _PopResult();
      await pumpApp(tester, _harness(box));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('common.enterManually'.tr()));
      await tester.pumpAndSettle();

      expect(box.popped, isTrue);

      expect(box.value, isNotNull);
      expect(box.value!.entry, isNull);
    },
  );

  testWidgets(
    'pressing system back pops with no outcome at all — the caller must do '
    'nothing, not open a blank form',
    (tester) async {
      final _PopResult box = _PopResult();
      await pumpApp(tester, _harness(box));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(MedicationSearchScreen))).pop();
      await tester.pumpAndSettle();

      expect(box.popped, isTrue);
      expect(box.value, isNull);
    },
  );
}
