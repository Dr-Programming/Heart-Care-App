import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/activity/domain/entities/activity_session.dart';
import 'package:libu_care/features/activity/domain/usecases/weekly_activity_totals.dart';

ActivitySession _session({
  required int durationMinutes,
  int? steps,
  double? distanceMeters,
}) {
  return ActivitySession(
    clientRecordId: 'id-$durationMinutes-$steps-$distanceMeters',
    type: ActivityType.walking,
    durationMinutes: durationMinutes,
    intensity: Intensity.moderate,
    measuredAt: DateTime(2026, 9, 1),
    steps: steps,
    distanceMeters: distanceMeters,
  );
}

void main() {
  group('weeklyActivityTotals', () {
    test('sums duration, steps and distance across the given sessions', () {
      final ActivityWeekTotals totals = weeklyActivityTotals(<ActivitySession>[
        _session(durationMinutes: 30, steps: 3000, distanceMeters: 2000),
        _session(durationMinutes: 20, steps: 1500, distanceMeters: 1200),
      ]);

      expect(totals.sessionCount, 2);
      expect(totals.totalMinutes, 50);
      expect(totals.totalSteps, 4500);
      expect(totals.totalDistanceMeters, 3200);
    });

    test('treats missing steps and distance as zero, not an error', () {
      final ActivityWeekTotals totals = weeklyActivityTotals(<ActivitySession>[
        _session(durationMinutes: 15),
      ]);

      expect(totals.sessionCount, 1);
      expect(totals.totalMinutes, 15);
      expect(totals.totalSteps, 0);
      expect(totals.totalDistanceMeters, 0);
    });

    test('an empty window sums to zero, not an error', () {
      final ActivityWeekTotals totals = weeklyActivityTotals(
        <ActivitySession>[],
      );

      expect(totals.sessionCount, 0);
      expect(totals.totalMinutes, 0);
      expect(totals.totalSteps, 0);
      expect(totals.totalDistanceMeters, 0);
    });
  });
}
