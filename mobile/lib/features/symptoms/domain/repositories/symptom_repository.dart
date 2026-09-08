import '../entities/symptom_check_in.dart';
import '../entities/symptom_history_entry.dart';

/// The symptoms feature's data boundary.
///
/// `data/repositories/symptom_repository_impl.dart` (a later step) is the
/// only implementation; use cases, controllers and screens depend on this
/// interface and never reach into Drift or Dio directly.
abstract interface class SymptomRepository {
  /// Writes locally with the locally-computed assessment and enqueues for
  /// sync. Never awaits the network — see the implementation for why.
  Future<void> log(SymptomCheckIn checkIn);

  /// Reverse-chronological, read from the device.
  ///
  /// [from]/[to] bound the window when given — the same shape as
  /// `GET /api/v1/symptoms?from=&to=`.
  Stream<List<SymptomHistoryEntry>> watchHistory({
    DateTime? from,
    DateTime? to,
  });

  /// Best-effort: replaces the locally computed assessment with the
  /// server's for any row that has synced but not yet been confirmed.
  ///
  /// Never throws — offline or a transport error just means "nothing to do
  /// this time, try again on the next call." Never awaited as part of a
  /// user action; a controller fires it in the background on screen load.
  Future<void> reconcileServerAssessments();
}
