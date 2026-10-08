/// The server's ActivityType values. Each has an EN/AM label under
/// `activity.type.<wire>`.
enum ActivityType {
  walking('WALKING'),
  jogging('JOGGING'),
  cycling('CYCLING'),
  household('HOUSEHOLD'),
  farming('FARMING'),
  stretching('STRETCHING'),
  other('OTHER');

  const ActivityType(this.wire);

  final String wire;

  static ActivityType fromWire(String value) => values.firstWhere(
    (ActivityType t) => t.wire == value,
    orElse: () => other,
  );
}

/// The standard CHD exercise-guidance scale the server uses.
enum Intensity {
  light('LIGHT'),
  moderate('MODERATE'),
  vigorous('VIGOROUS');

  const Intensity(this.wire);

  final String wire;

  static Intensity fromWire(String value) => values.firstWhere(
    (Intensity i) => i.wire == value,
    orElse: () => moderate,
  );
}

class ActivityEntry {
  const ActivityEntry({
    required this.clientRecordId,
    required this.type,
    required this.durationMinutes,
    required this.intensity,
    required this.measuredAt,
    this.steps,
    this.distanceMeters,
    this.note,
  });

  final String clientRecordId;
  final ActivityType type;
  final int durationMinutes;
  final Intensity intensity;
  final DateTime measuredAt;
  final int? steps;
  final double? distanceMeters;
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is ActivityEntry &&
      other.clientRecordId == clientRecordId &&
      other.type == type &&
      other.durationMinutes == durationMinutes &&
      other.intensity == intensity &&
      other.measuredAt.isAtSameMomentAs(measuredAt) &&
      other.steps == steps &&
      other.distanceMeters == distanceMeters &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(clientRecordId, type, durationMinutes, intensity);
}
