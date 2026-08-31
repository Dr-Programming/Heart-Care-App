import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_search_screen.dart';

import '../../../../helpers/pump_app.dart';

/// Mutable holder for what a pushed [MedicationSearchScreen] popped with —
/// simpler than reaching back into a `State` subclass from the tests below.
class _PopResult {
  bool popped = false;
  MedicationSearchOutcome? value;
}

/// A single-button screen that pushes [MedicationSearchScreen] and records
/// what it pops with into [box] — the same push a real caller
/// (`MedicationsScreen`) performs, so these tests exercise the screen's
/// actual self-popping contract rather than a stubbed callback.
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

  // The "can't find your
  // medication?" guidance must show regardless of whether `_results` is
  // empty — it was previously gated behind `if (_results.isNotEmpty)`,
  // hiding it exactly when it is most needed.
  testWidgets(
    'shows the cantFind guidance on the initial empty-query state',
    (tester) async {
      await pumpApp(tester, const MedicationSearchScreen());

      expect(find.text('meds.search.libraryHint'.tr()), findsOneWidget);
      expect(find.text('meds.search.cantFind'.tr()), findsOneWidget);
      // The SUGGESTIONS label and suggestion cards stay conditional on
      // having results.
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

      // searchMedicationLibrary matches on name only (a case-insensitive
      // substring of MedicationLibraryEntry.name) — it has no dose-aware
      // matching, so a query embedding a dose like 'Metoprolol 50' would
      // never match any entry. 'Metoprolol' alone matches all three
      // strengths, with the most-common (50mg) entry sorted first.
      await tester.enterText(find.byType(TextField).first, 'Metoprolol');
      await tester.pumpAndSettle();
      // Tap the exact suggestion label rather than
      // find.textContaining('Metoprolol').first: the search field's own
      // EditableText also contains the typed text 'Metoprolol' and sits
      // earlier in the tree than the suggestion list, so a substring match
      // would hit the input field itself, not a suggestion card.
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
      // A non-null MedicationSearchOutcome whose entry happens to be null —
      // "proceed, but with nothing picked" — is not the same value a system
      // back press produces (see the next test), which is exactly the
      // ambiguity MedicationSearchOutcome exists to remove.
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

      // Not `tester.pageBack()`: that helper specifically looks for an
      // AppBar's back-chevron widget, which this screen no longer has —
      // its back arrow now lives inside the cream band (see the screen's
      // own `AppScaffold.banded(showBack: false, ...)` and doc comment).
      // Both that in-band icon and a genuine OS back gesture call the exact
      // same `Navigator.of(context).pop()` with no argument in this app (no
      // custom `PopScope`/`WillPopScope` intercepts either), so popping the
      // Navigator directly is a faithful simulation of "system back" here,
      // not a weaker substitute for it.
      Navigator.of(tester.element(find.byType(MedicationSearchScreen))).pop();
      await tester.pumpAndSettle();

      expect(box.popped, isTrue);
      expect(box.value, isNull);
    },
  );
}
