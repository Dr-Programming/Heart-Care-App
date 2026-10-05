import '../entities/activity_entry.dart';

abstract interface class ActivityRepository {
  /// Saves on the phone and queues for the server; works offline.
  Future<ActivityEntry> log({
    required ActivityType type,
    required int durationMinutes,
    required Intensity intensity,
    int? steps,
    double? distanceMeters,
    String? note,
    DateTime? measuredAt,
  });

  /// Newest first.
  Future<List<ActivityEntry>> history();
}
