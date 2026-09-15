
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

  final String medicationClientRecordId;
  final String? medicationServerId;

  final DoseStatus status;

  final String scheduledDate;

  final String? scheduledTime;
  final DateTime loggedAt;
  final String? note;
}

enum DoseStatus {
  taken('TAKEN'),
  missed('MISSED'),
  skipped('SKIPPED');

  const DoseStatus(this.wire);

  final String wire;

  static DoseStatus fromWire(String value) =>
      values.firstWhere((DoseStatus s) => s.wire == value);
}
