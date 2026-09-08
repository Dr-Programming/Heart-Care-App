/// The seven activity types the API accepts (`backend/docs/API.md` §6).
///
/// `FARMING` and `HOUSEHOLD` are first-class, not folded into `OTHER` — for
/// many patients they are the day's exercise.
///
/// Wire-identical to the backend's `ActivityType` enum. Stored as a Dart enum
/// with a `wire` field rather than a `textEnum` because the wire form is
/// SCREAMING_SNAKE and an enum's `.name` is not — the same pattern
/// `core/clinical`'s `Severity` and `core/db`'s `SyncEntityType` use.
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

  static ActivityType fromWire(String value) =>
      values.firstWhere((ActivityType t) => t.wire == value);
}

/// How hard the session was (`backend/docs/API.md` §6).
enum Intensity {
  light('LIGHT'),
  moderate('MODERATE'),
  vigorous('VIGOROUS');

  const Intensity(this.wire);

  final String wire;

  static Intensity fromWire(String value) =>
      values.firstWhere((Intensity i) => i.wire == value);
}

/// One logged bout of physical activity (FR-ACT-003).
///
/// Pure Dart — no JSON, no Drift, no Flutter import — so the domain layer is
/// testable with no test harness at all. The server computes nothing from
/// this: no assessment, no derived fields.
class ActivitySession {
  const ActivitySession({
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

  /// Optional — the API places no range on either.
  final int? steps;
  final double? distanceMeters;

  final String? note;
}
