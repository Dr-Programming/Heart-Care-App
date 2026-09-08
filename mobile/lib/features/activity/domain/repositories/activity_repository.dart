import '../entities/activity_session.dart';

/// The activity feature's data boundary.
///
/// `data/repositories/activity_repository_impl.dart` (a later step) is the
/// only implementation; use cases, controllers and screens depend on this
/// interface and never reach into Drift or Dio directly.
abstract interface class ActivityRepository {
  /// Writes locally and enqueues for sync. Never awaits the network — see
  /// the implementation for why. Throws a `Failure` only for a local storage
  /// error; a sync failure stays queued for retry rather than throwing here.
  Future<void> log(ActivitySession session);

  /// Reverse-chronological, read from the device.
  ///
  /// [from]/[to] bound the window when given — the same shape as
  /// `GET /api/v1/activities?from=&to=` — so a caller asking for one week
  /// gets a single indexed query rather than filtering everything in memory.
  Stream<List<ActivitySession>> watchHistory({DateTime? from, DateTime? to});
}
