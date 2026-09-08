import 'symptom_answer.dart';

/// One daily symptom check-in (FR-SYM-001…011).
///
/// Pure Dart — no JSON, no Drift, no Flutter import — so severity can be
/// computed and validated with no test harness at all.
class SymptomCheckIn {
  const SymptomCheckIn({
    required this.clientRecordId,
    required this.chestPain,
    required this.shortnessOfBreath,
    required this.heartRate,
    required this.bloodPressure,
    required this.swelling,
    required this.energyLevel,
    required this.measuredAt,
    this.worseThanYesterday = const <SymptomKey, bool>{},
    this.note,
  });

  final String clientRecordId;
  final ChestPain chestPain;
  final ShortnessOfBreath shortnessOfBreath;

  /// 20-300 bpm.
  final int heartRate;
  final BloodPressureReading bloodPressure;
  final bool swelling;

  /// 0-10.
  final int energyLevel;

  /// FR-SYM-008 — "worse than yesterday?" per symptom. An absent key means
  /// the patient was not asked, or did not say — never inferred as false.
  final Map<SymptomKey, bool> worseThanYesterday;

  final DateTime measuredAt;
  final String? note;
}
