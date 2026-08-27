import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/medication/domain/medication_library.dart';
import 'package:libu_care/features/medication/presentation/screens/medication_search_screen.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  setUpWidgetTests();

  testWidgets('typing a query shows matching suggestions', (tester) async {
    MedicationLibraryEntry? selected;
    await pumpApp(
      tester,
      MedicationSearchScreen(onSelected: (e) => selected = e),
    );

    await tester.enterText(find.byType(TextField).first, 'Metop');
    await tester.pumpAndSettle();

    expect(find.textContaining('Metoprolol'), findsWidgets);
    expect(selected, isNull);
  });

  testWidgets('tapping a suggestion calls onSelected with that entry', (
    tester,
  ) async {
    MedicationLibraryEntry? selected;
    await pumpApp(
      tester,
      MedicationSearchScreen(onSelected: (e) => selected = e),
    );

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

    expect(selected, isNotNull);
    expect(selected!.name, 'Metoprolol');
  });

  testWidgets('tapping Enter manually calls onSelected with null', (
    tester,
  ) async {
    MedicationLibraryEntry? selected = const MedicationLibraryEntry(
      name: 'placeholder',
      doseMg: 1,
      drugClass: 'x',
    );
    await pumpApp(
      tester,
      MedicationSearchScreen(onSelected: (e) => selected = e),
    );

    await tester.tap(find.text('common.enterManually'.tr()));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });
}
