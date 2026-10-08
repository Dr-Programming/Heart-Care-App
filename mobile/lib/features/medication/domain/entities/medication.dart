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
    this.deactivatedAt,
  });

  final String clientRecordId;
  final String? serverId;
  final String name;
  final double doseMg;
  final MedicationFrequency frequency;

  final List<String> scheduleTimes;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// When the patient turned the medication off; null while active. Kept
  /// apart from [updatedAt] so editing an inactive medication doesn't move
  /// the day its doses stop being due.
  final DateTime? deactivatedAt;

  /// [copyWith] can't set a field back to null, so this is how the
  /// deactivation day is set or cleared.
  Medication withDeactivatedAt(DateTime? value) => Medication(
    clientRecordId: clientRecordId,
    serverId: serverId,
    name: name,
    doseMg: doseMg,
    frequency: frequency,
    scheduleTimes: scheduleTimes,
    active: active,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deactivatedAt: value,
  );

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
      deactivatedAt: deactivatedAt,
    );
  }
}

enum MedicationFrequency {
  onceDaily('ONCE_DAILY'),
  bid('BID'),
  tid('TID'),
  custom('CUSTOM');

  const MedicationFrequency(this.wire);

  final String wire;

  static MedicationFrequency fromWire(String value) =>
      values.firstWhere((MedicationFrequency f) => f.wire == value);

  int get suggestedTimeCount => switch (this) {
    MedicationFrequency.onceDaily => 1,
    MedicationFrequency.bid => 2,
    MedicationFrequency.tid => 3,
    MedicationFrequency.custom => 1,
  };
}
