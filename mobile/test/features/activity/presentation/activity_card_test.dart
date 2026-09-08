import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/activity/domain/entities/activity_session.dart';
import 'package:libu_care/features/activity/domain/repositories/activity_repository.dart';
import 'package:libu_care/features/activity/presentation/home/activity_card.dart';
import 'package:libu_care/features/activity/presentation/providers/activity_providers.dart';

import '../../../helpers/pump_app.dart';

class _FakeActivityRepository implements ActivityRepository {
  _FakeActivityRepository(this._sessions);

  final List<ActivitySession> _sessions;

  @override
  Future<void> log(ActivitySession session) async {}

  @override
  Stream<List<ActivitySession>> watchHistory({DateTime? from, DateTime? to}) =>
      Stream<List<ActivitySession>>.value(_sessions);
}

class _ThrowingActivityRepository implements ActivityRepository {
  @override
  Future<void> log(ActivitySession session) async {}

  @override
  Stream<List<ActivitySession>> watchHistory({DateTime? from, DateTime? to}) =>
      Stream<List<ActivitySession>>.error(StateError('boom'));
}

void main() {
  setUpWidgetTests();

  testWidgets('shows "—" when nothing has been logged today', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: ActivityHomeCard()),
      overrides: <Override>[
        activityRepositoryProvider.overrideWithValue(
          _FakeActivityRepository(const <ActivitySession>[]),
        ),
      ],
    );

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets("shows today's total minutes and session count", (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: ActivityHomeCard()),
      overrides: <Override>[
        activityRepositoryProvider.overrideWithValue(
          _FakeActivityRepository(<ActivitySession>[
            ActivitySession(
              clientRecordId: 'a',
              type: ActivityType.walking,
              durationMinutes: 20,
              intensity: Intensity.light,
              measuredAt: DateTime.now(),
            ),
          ]),
        ),
      ],
    );

    expect(find.text('20'), findsOneWidget);
    expect(find.text('1 sessions'), findsOneWidget);
  });

  testWidgets('never throws — a stream error degrades to "—"', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: ActivityHomeCard()),
      overrides: <Override>[
        activityRepositoryProvider.overrideWithValue(
          _ThrowingActivityRepository(),
        ),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('—'), findsOneWidget);
  });
}
