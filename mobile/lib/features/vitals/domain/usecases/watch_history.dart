import '../entities/vital_reading.dart';
import '../entities/vital_type.dart';
import '../repositories/vitals_repository.dart';

class WatchHistory {
  const WatchHistory(this._repository);

  final VitalsRepository _repository;

  Future<List<VitalReading>> call({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  }) => _repository.history(type: type, from: from, to: to);
}
