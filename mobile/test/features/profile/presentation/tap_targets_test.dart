import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/profile/presentation/settings/settings_screen.dart';
import 'package:libu_care/features/profile/presentation/widgets/selectable_chip.dart';

import '../../../helpers/fake_dio.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

/// FR-LOC-006: every interactive element is at least 44x44 dp. This slice
/// owns the accessibility pass for the whole app (M2 spec §2, Decision 7).
void main() {
  setUpWidgetTests();

  testWidgets('a SelectableChip is at least 44dp tall', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: SelectableChip(label: 'Diabetes', selected: false, onTap: () {}),
        ),
      ),
    );

    final size = tester.getSize(find.byType(SelectableChip));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('settings rows are at least 44dp tall', (
    WidgetTester tester,
  ) async {
    final db = testDatabase();
    addTearDown(db.close);
    await db.cachedUserDao.save(
      const CachedUsersCompanion(
        id: Value('u-1'),
        name: Value('Abebe Bekele'),
        phone: Value('+251911234567'),
        preferredLanguage: Value('en'),
        role: Value('PATIENT'),
      ),
    );

    final fakeDio = FakeDio();
    fakeDio.stubAll(FakeResponse.offline());
    final List<Override> overrides = <Override>[
      appDatabaseProvider.overrideWithValue(db),
      dioProvider.overrideWithValue(fakeDio.dio),
      connectivityStreamProvider.overrideWithValue(
        const Stream<bool>.empty(),
      ),
      pendingSyncCountProvider.overrideWith((ref) => Stream<int>.value(0)),
    ];

    await pumpApp(tester, const SettingsScreen(), overrides: overrides);

    for (final label in ['Language', 'Pending sync', 'Sign out']) {
      final size = tester.getSize(find.text(label));
      // The row itself, not just the label text, is what needs to be
      // 44dp — but a label taller than its row would be a bug too, and a
      // narrower check here would miss a shrunk row entirely, so walk up
      // to the row's own ListTile-sized ancestor instead of the text.
      final rowFinder = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SettingsRow'),
      );
      expect(rowFinder, findsOneWidget, reason: '$label has no row ancestor');
      final rowSize = tester.getSize(rowFinder);
      expect(
        rowSize.height,
        greaterThanOrEqualTo(44),
        reason: '$label row is only ${rowSize.height}dp tall',
      );
      // Keep the text-size check too as a sanity floor.
      expect(size.height, greaterThan(0));
    }
  });
}
