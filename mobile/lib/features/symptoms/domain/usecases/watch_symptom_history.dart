import '../entities/symptom_history_entry.dart';
import '../repositories/symptom_repository.dart';

/// Thin by design — reads come from Drift via the repository, never the API.
class WatchSymptomHistory {
  const WatchSymptomHistory(this._repository);

  final SymptomRepository _repository;

  Stream<List<SymptomHistoryEntry>> call({DateTime? from, DateTime? to}) =>
      _repository.watchHistory(from: from, to: to);
}
