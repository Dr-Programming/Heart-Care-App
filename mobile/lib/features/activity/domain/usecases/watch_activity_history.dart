import '../entities/activity_session.dart';
import '../repositories/activity_repository.dart';

/// Thin by design — reads come from Drift via the repository, never the API.
class WatchActivityHistory {
  const WatchActivityHistory(this._repository);

  final ActivityRepository _repository;

  Stream<List<ActivitySession>> call({DateTime? from, DateTime? to}) =>
      _repository.watchHistory(from: from, to: to);
}
