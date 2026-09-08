import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/localization/language.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/activity/domain/entities/activity_session.dart';
import 'package:libu_care/features/activity/domain/repositories/activity_repository.dart';
import 'package:libu_care/features/activity/presentation/providers/activity_providers.dart';
import 'package:libu_care/features/activity/presentation/screens/activity_log_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  setUpWidgetTests();

  late _MockActivityRepository repository;
  late AppDatabase db;

  setUpAll(() {
    registerFallbackValue(
      ActivitySession(
        clientRecordId: 'fallback',
        type: ActivityType.walking,
        durationMinutes: 1,
        intensity: Intensity.light,
        measuredAt: DateTime(2000),
      ),
    );
  });

  setUp(() {
    repository = _MockActivityRepository();
    when(() => repository.log(any())).thenAnswer((_) async {});
    db = testDatabase();
  });

  tearDown(() => db.close());

  // AppScaffold pulls in OfflineBanner, which watches the real
  // appDatabaseProvider/onlineStatusProvider through core/sync — every
  // screen test needs these overridden or it opens a real database
  // connection (see the "multiple database instances" drift warning).
  List<Override> overrides() => <Override>[
    activityRepositoryProvider.overrideWithValue(repository),
    appDatabaseProvider.overrideWithValue(db),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  ];

  testWidgets(
    'shows the termination indications above the form, with no scrolling',
    (WidgetTester tester) async {
      await pumpApp(tester, const ActivityLogScreen(), overrides: overrides());

      expect(find.text('Stop and rest if you notice:'), findsOneWidget);
      expect(find.text('Log activity'), findsOneWidget);
    },
  );

  testWidgets('entering a duration and saving logs the session', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, const ActivityLogScreen(), overrides: overrides());

    // The duration field is the first TextField in the form.
    await tester.enterText(find.byType(TextField).first, '30');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final List<dynamic> captured = verify(() => repository.log(captureAny()))
        .captured;
    final ActivitySession logged = captured.single as ActivitySession;
    expect(logged.durationMinutes, 30);
    expect(logged.type, ActivityType.walking);
    expect(logged.intensity, Intensity.moderate);
  });

  testWidgets(
    'an out-of-range duration shows the inline error and never saves',
    (WidgetTester tester) async {
      await pumpApp(tester, const ActivityLogScreen(), overrides: overrides());

      await tester.enterText(find.byType(TextField).first, '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a duration between 1 and 1440 minutes'),
        findsOneWidget,
      );
      verifyNever(() => repository.log(any()));
    },
  );

  testWidgets('renders in Amharic', (WidgetTester tester) async {
    await pumpApp(
      tester,
      const ActivityLogScreen(),
      overrides: overrides(),
      language: AppLanguage.am,
    );

    expect(find.text('እንቅስቃሴ መዝግብ'), findsOneWidget);
    expect(find.text('ካስተዋሉ ያቁሙና ያርፉ:'), findsOneWidget);
  });
}
