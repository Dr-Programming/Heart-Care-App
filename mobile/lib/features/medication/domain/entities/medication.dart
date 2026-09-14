
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
