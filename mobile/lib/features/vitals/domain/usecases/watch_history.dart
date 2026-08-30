import '../entities/vital_reading.dart';
import '../entities/vital_type.dart';
import '../repositories/vitals_repository.dart';

/// FR-VIT-006.
class WatchHistory {
  const WatchHistory(this._repository);

  final VitalsRepository _repository;

  Stream<List<VitalReading>> call({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => _repository.watchHistory(type: type, from: from, to: to);
}
