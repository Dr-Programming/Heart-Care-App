import '../entities/activity_session.dart';

/// The numbers the activity history screen's "this week" total shows.
class ActivityWeekTotals {
  const ActivityWeekTotals({
    required this.sessionCount,
    required this.totalMinutes,
    required this.totalSteps,
    required this.totalDistanceMeters,
  });

  final int sessionCount;
  final int totalMinutes;
  final int totalSteps;
  final double totalDistanceMeters;
}

/// Sums a window of activity history.
///
/// Pure aggregation only — narrowing to the right week is the caller's job,
/// done by passing `from`/`to` to [WatchActivityHistory]. Keeping the two
/// separate means this function needs no database to test.
ActivityWeekTotals weeklyActivityTotals(
  List<ActivitySession> sessionsInWindow,
) {
  int totalMinutes = 0;
  int totalSteps = 0;
  double totalDistanceMeters = 0;
  for (final ActivitySession session in sessionsInWindow) {
    totalMinutes += session.durationMinutes;
    totalSteps += session.steps ?? 0;
    totalDistanceMeters += session.distanceMeters ?? 0;
  }
  return ActivityWeekTotals(
    sessionCount: sessionsInWindow.length,
    totalMinutes: totalMinutes,
    totalSteps: totalSteps,
    totalDistanceMeters: totalDistanceMeters,
  );
}
