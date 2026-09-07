import '../entities/vital_reading.dart';
import '../entities/vital_type.dart';

/// The subset of `PatientProfiles.goalsJson` this feature reads —
/// BP and weight targets for trend reference lines (Decision 5,
/// FR-GRAPH-008). Glucose has no goal field in the schema, so it never
/// appears here; that is correct, not a gap.
class VitalGoals {
  const VitalGoals({this.bpSystolic, this.bpDiastolic, this.targetWeightKg});

  final double? bpSystolic;
  final double? bpDiastolic;
  final double? targetWeightKg;
}

/// Returns a value or throws a [Failure] (`core/error/failure.dart`). Never
/// returns null for an error — see `CONTRIBUTING.md` §8.
abstract interface class VitalsRepository {
  /// Writes [reading] to Drift, then enqueues it for sync. Never awaits the
  /// network.
  Future<void> log(VitalReading reading);

  /// Newest-first (FR-VIT-006). Drift only, live-updating — never the API.
  Stream<List<VitalReading>> watchHistory({
    VitalType? type,
    DateTime? from,
    DateTime? to,
  });

  /// The most recent reading of [type], or null if none exists yet. Powers
  /// the Home card and the form's "last value as a hint" (Decision 7).
  Future<VitalReading?> latestByType(VitalType type);

  /// `PatientProfiles.heightCm`, or null with no profile row yet (M2 may not
  /// have landed) or no height set (Decision 3).
  Future<double?> patientHeightCm();

  /// `PatientProfiles.goalsJson`, parsed. Null under the same conditions as
  /// [patientHeightCm].
  Future<VitalGoals?> patientGoals();
}
