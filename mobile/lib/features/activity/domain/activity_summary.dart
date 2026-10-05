import '../../../core/utils/date_formatter.dart';
import 'entities/activity_entry.dart';

/// Today's and the last 7 days' activity, against the weekly goal.
class ActivitySummary {
  const ActivitySummary({
    required this.todayMinutes,
    required this.weekMinutes,
    required this.activeDaysThisWeek,
  });

  /// At least 150 minutes of moderate activity a week (30 minutes on most
  /// days), as in the app's heart-health education content.
  static const int weeklyGoalMinutes = 150;

  factory ActivitySummary.of(List<ActivityEntry> entries, {DateTime? now}) {
    final DateTime today = DateFormatter.startOfDay(now ?? DateTime.now());
    final DateTime weekStart = today.subtract(const Duration(days: 6));
    int todayMinutes = 0;
    int weekMinutes = 0;
    final Set<DateTime> activeDays = <DateTime>{};
    for (final ActivityEntry entry in entries) {
      final DateTime day = DateFormatter.startOfDay(entry.measuredAt.toLocal());
      if (day.isBefore(weekStart) || day.isAfter(today)) continue;
      weekMinutes += entry.durationMinutes;
      activeDays.add(day);
      if (day == today) todayMinutes += entry.durationMinutes;
    }
    return ActivitySummary(
      todayMinutes: todayMinutes,
      weekMinutes: weekMinutes,
      activeDaysThisWeek: activeDays.length,
    );
  }

  final int todayMinutes;
  final int weekMinutes;
  final int activeDaysThisWeek;

  double get weekProgress =>
      (weekMinutes / weeklyGoalMinutes).clamp(0, 1).toDouble();
}
