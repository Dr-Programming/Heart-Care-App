import 'dose_log.dart';

enum ScheduledDoseStatus { pending, overdue, logged }

class ScheduledDose {
  const ScheduledDose({
    required this.medicationClientRecordId,
    required this.medicationName,
    required this.doseMg,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    required this.doseLog,
  });

  final String medicationClientRecordId;
  final String medicationName;
  final double doseMg;

  final String scheduledDate;

  final String scheduledTime;
  final ScheduledDoseStatus status;

  final DoseLog? doseLog;
}
