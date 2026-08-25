import '../entities/scheduled_dose.dart';
import '../repositories/medication_repository.dart';

class TodaysDoses {
  const TodaysDoses(this._repository);
  final MedicationRepository _repository;

  Future<List<ScheduledDose>> call({DateTime? now}) =>
      _repository.todaysDoses(now: now);
}
