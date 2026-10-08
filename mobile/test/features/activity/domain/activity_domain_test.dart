import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/activity/domain/activity_summary.dart';
import 'package:libu_care/features/activity/domain/entities/activity_entry.dart';
import 'package:libu_care/features/activity/domain/validators.dart';

ActivityEntry _entry(DateTime at, int minutes) => ActivityEntry(
  clientRecordId: '$at',
  type: ActivityType.walking,
  durationMinutes: minutes,
  intensity: Intensity.moderate,
  measuredAt: at,
);

void main() {
  group('wire values match the server enums', () {
    test('activity types', () {
      expect(ActivityType.values.map((ActivityType t) => t.wire), <String>[
        'WALKING',
        'JOGGING',
        'CYCLING',
        'HOUSEHOLD',
        'FARMING',
        'STRETCHING',
        'OTHER',
      ]);
    });
    test('intensities', () {
      expect(Intensity.values.map((Intensity i) => i.wire), <String>[
        'LIGHT',
        'MODERATE',
        'VIGOROUS',
      ]);
    });
  });

  group('validators', () {
    test('duration must be 1 to 1440 minutes', () {
      expect(validateDurationMinutes(''), 'activity.errors.durationRequired');
      expect(validateDurationMinutes('0'), 'activity.errors.durationRange');
      expect(validateDurationMinutes('1441'), 'activity.errors.durationRange');
      expect(validateDurationMinutes('30'), isNull);
    });
    test('steps are optional, 0 to 100000', () {
      expect(validateSteps(''), isNull);
      expect(validateSteps('100001'), 'activity.errors.stepsRange');
      expect(validateSteps('8000'), isNull);
    });
  });

  group('summary', () {
    final DateTime now = DateTime(2026, 9, 30, 18);

    test('counts today and the last 7 days', () {
      final ActivitySummary summary = ActivitySummary.of(<ActivityEntry>[
        _entry(DateTime(2026, 9, 30, 7), 30),
        _entry(DateTime(2026, 9, 29, 7), 20),
        _entry(DateTime(2026, 9, 24, 7), 15),
        _entry(DateTime(2026, 9, 23, 7), 60),
      ], now: now);

      expect(summary.todayMinutes, 30);
      expect(summary.weekMinutes, 65);
      expect(summary.activeDaysThisWeek, 3);
    });

    test('the weekly goal is 150 minutes', () {
      final ActivitySummary summary = ActivitySummary.of(<ActivityEntry>[
        _entry(DateTime(2026, 9, 30, 7), 75),
      ], now: now);

      expect(ActivitySummary.weeklyGoalMinutes, 150);
      expect(summary.weekProgress, 0.5);
    });
  });
}
