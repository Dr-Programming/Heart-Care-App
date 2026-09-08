import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/core/sync/sync_queue_dao.dart';
import 'package:libu_care/features/symptoms/data/datasources/symptom_local_datasource.dart';
import 'package:libu_care/features/symptoms/data/datasources/symptom_remote_datasource.dart';
import 'package:libu_care/features/symptoms/data/repositories/symptom_repository_impl.dart';
import 'package:libu_care/features/symptoms/presentation/providers/symptom_providers.dart';
import 'package:libu_care/features/symptoms/presentation/screens/symptom_check_in_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

class _MockSyncEnqueuer extends Mock implements SyncEnqueuer {}

class _MockSymptomRemoteDatasource extends Mock
    implements SymptomRemoteDatasource {}

class _MockSyncQueueDao extends Mock implements SyncQueueDao {}

void main() {
  setUpWidgetTests();

  late AppDatabase db;
  late _MockSyncEnqueuer sync;
  late SymptomRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(SyncEntityType.symptom);
    registerFallbackValue(DateTime(2000, 1, 1));
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    db = testDatabase();
    sync = _MockSyncEnqueuer();
    when(
      () => sync.enqueue(
        clientRecordId: any(named: 'clientRecordId'),
        entityType: any(named: 'entityType'),
        payload: any(named: 'payload'),
        recordedAt: any(named: 'recordedAt'),
      ),
    ).thenAnswer((_) async {});
    repository = SymptomRepositoryImpl(
      local: SymptomLocalDatasource(db),
      sync: sync,
      remote: _MockSymptomRemoteDatasource(),
      syncQueue: _MockSyncQueueDao(),
    );
  });

  tearDown(() => db.close());

  // AppScaffold pulls in OfflineBanner, which watches the real
  // appDatabaseProvider/onlineStatusProvider — every screen test needs
  // these overridden, same as core/shell/home_screen_test.dart.
  List<Override> overrides() => <Override>[
    symptomRepositoryProvider.overrideWithValue(repository),
    appDatabaseProvider.overrideWithValue(db),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  ];

  testWidgets(
    'the "fine today" defaults save in two taps and show the normal result',
    (WidgetTester tester) async {
      await pumpApp(
        tester,
        const SymptomCheckInScreen(),
        overrides: overrides(),
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('No action needed. Keep monitoring.'), findsOneWidget);
    },
  );

  testWidgets('reporting chest pain reveals the severity control', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const SymptomCheckInScreen(), overrides: overrides());

    expect(find.text('How severe?'), findsNothing);

    await tester.tap(find.text('Yes').first);
    await tester.pumpAndSettle();

    expect(find.text('How severe?'), findsOneWidget);
  });

  testWidgets('severe chest pain (severity >= 7) shows the emergency result', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const SymptomCheckInScreen(), overrides: overrides());

    await tester.tap(find.text('Yes').first);
    await tester.pumpAndSettle();

    final Slider severitySlider = tester.widget<Slider>(
      find.byType(Slider).first,
    );
    severitySlider.onChanged?.call(8);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('Call your emergency contact now.'), findsOneWidget);
  });

  testWidgets(
    'an out-of-range heart rate shows the inline error and does not save',
    (WidgetTester tester) async {
      await pumpApp(
        tester,
        const SymptomCheckInScreen(),
        overrides: overrides(),
      );

      // Heart rate is the first TextField when chest pain is untouched.
      await tester.enterText(find.byType(TextField).first, '999');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a heart rate between 20 and 300'),
        findsOneWidget,
      );
      verifyNever(
        () => sync.enqueue(
          clientRecordId: any(named: 'clientRecordId'),
          entityType: any(named: 'entityType'),
          payload: any(named: 'payload'),
          recordedAt: any(named: 'recordedAt'),
        ),
      );
      // Still on the form, not the result view.
      expect(find.text('Save'), findsOneWidget);
    },
  );

  testWidgets('renders in Amharic', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const SymptomCheckInScreen(),
      overrides: overrides(),
      language: AppLanguage.am,
    );

    expect(find.text('የምልክቶች ምዝገባ'), findsOneWidget);
    expect(find.text('የደረት ህመም?'), findsOneWidget);
  });
}
