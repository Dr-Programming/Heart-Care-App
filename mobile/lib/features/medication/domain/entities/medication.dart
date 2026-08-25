/// A medication the patient is taking. Mutable — can be renamed, re-dosed,
/// rescheduled and soft-deactivated. Never hard-deleted (Decision 1).
class Medication {
  const Medication({
    required this.clientRecordId,
    required this.serverId,
    required this.name,
    required this.doseMg,
    required this.frequency,
    required this.scheduleTimes,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String clientRecordId;
  final String? serverId;
  final String name;
  final double doseMg;
  final MedicationFrequency frequency;

  /// "HH:mm" strings. The full set of times this medication is due at, for
  /// every frequency — frequency does not independently generate times.
  final List<String> scheduleTimes;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  Medication copyWith({
    String? serverId,
    String? name,
    double? doseMg,
    MedicationFrequency? frequency,
    List<String>? scheduleTimes,
    bool? active,
    DateTime? updatedAt,
  }) {
    return Medication(
      clientRecordId: clientRecordId,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      doseMg: doseMg ?? this.doseMg,
      frequency: frequency ?? this.frequency,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      active: active ?? this.active,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Wire-identical to the backend's `Frequency` enum.
enum MedicationFrequency {
  onceDaily('ONCE_DAILY'),
  bid('BID'),
  tid('TID'),
  custom('CUSTOM');

  const MedicationFrequency(this.wire);

  final String wire;

  static MedicationFrequency fromWire(String value) =>
      values.firstWhere((MedicationFrequency f) => f.wire == value);

  /// How many time-of-day fields the add/edit form suggests by default.
  /// Soft guidance only — never enforced against `scheduleTimes.length`,
  /// mirroring the backend's deliberate non-validation (the client owns
  /// this UX; see `backend/docs/DEVELOPMENT.md`/API design decision).
  int get suggestedTimeCount => switch (this) {
    MedicationFrequency.onceDaily => 1,
    MedicationFrequency.bid => 2,
    MedicationFrequency.tid => 3,
    MedicationFrequency.custom => 1,
  };
}
