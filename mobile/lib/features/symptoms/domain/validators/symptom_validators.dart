import '../entities/symptom_answer.dart';
import '../entities/symptom_check_in.dart';

/// Local validation mirroring the server's rules (`backend/docs/API.md` §5),
/// checked before a check-in ever reaches the network. `shortnessOfBreath`
/// and the `worseThanYesterday` key space need no runtime check — both are
/// Dart enums/typed keys, so an invalid value is a compile error instead of
/// a validation error.
enum SymptomValidationError {
  chestPainSeverityRequired,
  chestPainSeverityOutOfRange,
  heartRateOutOfRange,
  bloodPressureOutOfRange,
  bloodPressureNotGreaterThanDiastolic,
  energyLevelOutOfRange,
}

Set<SymptomValidationError> validateSymptomCheckIn(SymptomCheckIn checkIn) {
  final Set<SymptomValidationError> errors = <SymptomValidationError>{};

  final ChestPain chestPain = checkIn.chestPain;
  if (chestPain.present) {
    final int? severity = chestPain.severity;
    if (severity == null) {
      errors.add(SymptomValidationError.chestPainSeverityRequired);
    } else if (severity < 0 || severity > 10) {
      errors.add(SymptomValidationError.chestPainSeverityOutOfRange);
    }
  }

  if (checkIn.heartRate < 20 || checkIn.heartRate > 300) {
    errors.add(SymptomValidationError.heartRateOutOfRange);
  }

  final BloodPressureReading bp = checkIn.bloodPressure;
  final bool systolicInRange = bp.systolic >= 40 && bp.systolic <= 300;
  final bool diastolicInRange = bp.diastolic >= 40 && bp.diastolic <= 300;
  if (!systolicInRange || !diastolicInRange) {
    errors.add(SymptomValidationError.bloodPressureOutOfRange);
  }
  if (bp.systolic <= bp.diastolic) {
    errors.add(SymptomValidationError.bloodPressureNotGreaterThanDiastolic);
  }

  if (checkIn.energyLevel < 0 || checkIn.energyLevel > 10) {
    errors.add(SymptomValidationError.energyLevelOutOfRange);
  }

  return errors;
}
