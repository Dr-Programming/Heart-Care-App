import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/core/widgets/offline_banner.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

void main() {
  setUpWidgetTests();

  testWidgets('a record the server refused is shown with its reason', (
    tester,
  ) async {
    final AppDatabase db = testDatabase();
    addTearDown(db.close);
    final SyncQueueDao queue = SyncQueueDao(db);
    await tester.runAsync(() async {
      await queue.enqueue(
        clientRecordId: 's1',
        entityType: SyncEntityType.symptom,
        payload: <String, dynamic>{},
        recordedAt: DateTime(2026, 9, 30),
      );
      final int id = (await queue.pending()).single.id;
      await queue.markSyncing(<int>[id]);
      await queue.markResult(
        id,
        status: LocalSyncStatus.rejected,
        error: 'A symptom check-in already exists for 2026-09-30',
      );
    });

    await pumpApp(
      tester,
      const Scaffold(body: OfflineBanner()),
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        onlineStatusProvider.overrideWith((ref) => Stream<bool>.value(true)),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('sync.rejected'.plural(1)), findsOneWidget);

    await tester.tap(find.text('sync.rejectedDetails'.tr()));
    await tester.pumpAndSettle();
    expect(
      find.text('A symptom check-in already exists for 2026-09-30'),
      findsOneWidget,
    );

    await tester.tap(find.text('sync.dismiss'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('sync.rejected'.plural(1)), findsNothing);
  });
}
