import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/providers/core_providers.dart';
import 'package:libu_care/features/activity/domain/entities/activity_session.dart';
import 'package:libu_care/features/activity/domain/repositories/activity_repository.dart';
import 'package:libu_care/features/activity/presentation/providers/activity_providers.dart';
import 'package:libu_care/features/activity/presentation/screens/activity_history_screen.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/test_database.dart';

/// A hand-written fake rather than mocktail: every widget test here just
/// needs `watchHistory` to answer with a fixed list regardless of the
/// from/to window, which the data-layer tests already cover precisely.
class _FakeActivityRepository implements ActivityRepository {
  _FakeActivityRepository(this._sessions);

  final List<ActivitySession> _sessions;

  @override
  Future<void> log(ActivitySession session) async {}

  @override
  Stream<List<ActivitySession>> watchHistory({DateTime? from, DateTime? to}) =>
      Stream<List<ActivitySession>>.value(_sessions);
}

void main() {
  setUpWidgetTests();

  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  List<Override> overrides(ActivityRepository repository) => <Override>[
    activityRepositoryProvider.overrideWithValue(repository),
    appDatabaseProvider.overrideWithValue(db),
    onlineStatusProvider.overrideWith((Ref ref) => Stream<bool>.value(true)),
  ];

  testWidgets('shows an empty state with no sessions logged yet', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const ActivityHistoryScreen(),
      overrides: overrides(_FakeActivityRepository(const <ActivitySession>[])),
    );

    expect(find.text('No activity logged yet'), findsOneWidget);
  });

  testWidgets('shows the weekly total and each session', (
    WidgetTester tester,
  ) async {
    final List<ActivitySession> sessions = <ActivitySession>[
      ActivitySession(
        clientRecordId: 'a',
        type: ActivityType.walking,
        durationMinutes: 30,
        intensity: Intensity.moderate,
        measuredAt: DateTime.now(),
      ),
      ActivitySession(
        clientRecordId: 'b',
        type: ActivityType.farming,
        durationMinutes: 60,
        intensity: Intensity.vigorous,
        measuredAt: DateTime.now(),
      ),
    ];

    await pumpApp(
      tester,
      const ActivityHistoryScreen(),
      overrides: overrides(_FakeActivityRepository(sessions)),
    );

    expect(find.text('2 sessions · 90 min'), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Farming'), findsOneWidget);
  });
}
