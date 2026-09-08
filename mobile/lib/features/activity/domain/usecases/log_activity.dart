import '../entities/activity_session.dart';
import '../repositories/activity_repository.dart';

/// Thin by design — the offline-first write path (Drift first, then enqueue,
/// never awaiting the network) lives in the repository implementation, not
/// here.
class LogActivity {
  const LogActivity(this._repository);

  final ActivityRepository _repository;

  Future<void> call(ActivitySession session) => _repository.log(session);
}
