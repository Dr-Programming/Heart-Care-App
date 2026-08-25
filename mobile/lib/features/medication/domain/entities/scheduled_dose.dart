import 'dose_log.dart';

/// One occurrence of a medication being due, derived at read time — never
/// stored (Decision 2). `pending` means not yet due today or not yet acted
/// on; `overdue` means past its time with no log; `logged` means a matching
/// [DoseLog] was found.
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

  /// "yyyy-MM-dd".
  final String scheduledDate;

  /// "HH:mm".
  final String scheduledTime;
  final ScheduledDoseStatus status;

  /// Set only when [status] is `logged`.
  final DoseLog? doseLog;
}
