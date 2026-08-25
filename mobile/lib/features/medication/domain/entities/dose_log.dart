/// One logged dose. Append-only — once recorded, a `DoseLog` is never
/// edited or deleted (Decision 1).
class DoseLog {
  const DoseLog({
    required this.clientRecordId,
    required this.serverId,
    required this.medicationClientRecordId,
    required this.medicationServerId,
    required this.status,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.loggedAt,
    required this.note,
  });

  final String clientRecordId;
  final String? serverId;

  /// Always set — the offline-safe link to its medication (Decision 3).
  final String medicationClientRecordId;
  final String? medicationServerId;

  final DoseStatus status;

  /// "yyyy-MM-dd", the day the dose was due.
  final String scheduledDate;

  /// "HH:mm", null for an unscheduled/ad-hoc log.
  final String? scheduledTime;
  final DateTime loggedAt;
  final String? note;
}

/// Wire-identical to the backend's `DoseStatus` enum.
enum DoseStatus {
  taken('TAKEN'),
  missed('MISSED'),
  skipped('SKIPPED');

  const DoseStatus(this.wire);

  final String wire;

  static DoseStatus fromWire(String value) =>
      values.firstWhere((DoseStatus s) => s.wire == value);
}
