import '../entities/vital_reading.dart';
import '../repositories/vitals_repository.dart';

/// FR-VIT-001..003/009, FR-OFF-001. Thin — the offline-first behaviour lives
/// in [VitalsRepository]'s implementation, not here.
class LogVital {
  const LogVital(this._repository);

  final VitalsRepository _repository;

  Future<void> call(VitalReading reading) => _repository.log(reading);
}
