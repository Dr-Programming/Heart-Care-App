import '../../../core/utils/date_formatter.dart';
import 'entities/adherence.dart';
import 'entities/dose_log.dart';
import 'entities/medication.dart';
import 'entities/scheduled_dose.dart';

/// Whether [medication] counts as active on [day] — i.e. whether any of its
/// scheduled times on that day are due at all.
///
/// **Known limitations, accepted deliberately:**
///
/// 1. **Single-transition edge case:** The schema (owned by the foundation,
/// not editable by this slice) has no `deactivatedAt` column — only `active`
/// and a generic `updatedAt` that changes on *any* edit. When `active` is
/// false, `updatedAt` is used as a best-effort proxy for "the day it stopped
/// being due". A medication edited (not deactivated) shortly before being
/// deactivated could therefore lose one day of adherence history at the
/// boundary.
///
/// 2. **Multi-transition/reactivation gap (latent, not currently exploitable):**
/// When a medication is deactivated and later reactivated (flipping `active`
/// back to `true`), this function treats every day from `createdAt` onward as
/// active — it consults only `createdAt`, never checks whether `updatedAt`
/// marks a deactivation somewhere in the middle. This means `computeAdherence`
/// will incorrectly count the inactive gap-days as due-but-unlogged,
/// undercounting adherence for that period. **This cannot be fixed without an
/// activation-history column added to the schema**, which is outside this
/// slice's authority. No UI in this plan currently exposes medication
/// reactivation, so this bug is latent rather than exploitable today.
///
/// Revisit both if the schema ever grows dedicated deactivation and activation
/// history columns.
bool isActiveOn(Medication medication, DateTime day) {
  final DateTime dayStart = DateFormatter.startOfDay(day);
  final DateTime createdDay = DateFormatter.startOfDay(medication.createdAt);
  if (dayStart.isBefore(createdDay)) return false;
  if (!medication.active) {
    final DateTime deactivatedDay = DateFormatter.startOfDay(medication.updatedAt);
    if (dayStart.isAfter(deactivatedDay)) return false;
  }
  return true;
}

/// Today's (or any single day's) doses (Decision 2): active medications ×
/// their scheduled times, matched against that day's logs. Never
/// pre-materialized — this runs fresh on every read.
List<ScheduledDose> scheduledDosesFor({
  required List<Medication> medications,
  required List<DoseLog> logsForDate,
  required DateTime date,
  required DateTime now,
}) {
  final String dateStr = DateFormatter.toApiDate(date);
  final List<ScheduledDose> result = <ScheduledDose>[];

  for (final Medication medication in medications) {
    if (!isActiveOn(medication, date)) continue;
    for (final String time in medication.scheduleTimes) {
      final DoseLog? match = _matchingLog(logsForDate, medication.clientRecordId, time);
      final ScheduledDoseStatus status = match != null
          ? ScheduledDoseStatus.logged
          : (_isPastDue(date, time, now)
                ? ScheduledDoseStatus.overdue
                : ScheduledDoseStatus.pending);

      result.add(
        ScheduledDose(
          medicationClientRecordId: medication.clientRecordId,
          medicationName: medication.name,
          doseMg: medication.doseMg,
          scheduledDate: dateStr,
          scheduledTime: time,
          status: status,
          doseLog: match,
        ),
      );
    }
  }

  result.sort((ScheduledDose a, ScheduledDose b) => a.scheduledTime.compareTo(b.scheduledTime));
  return result;
}

/// `taken / due` over `[windowStart, now]` (Decision 5). A slot only counts
/// as due once its time has passed — "later today" is never counted — and
/// `SKIPPED` never counts toward either side.
Adherence computeAdherence({
  required List<Medication> medications,
  required List<DoseLog> allLogs,
  required DateTime windowStart,
  required DateTime now,
  required int windowDays,
}) {
  int taken = 0;
  int due = 0;
  int skipped = 0;

  DateTime day = DateFormatter.startOfDay(windowStart);
  final DateTime today = DateFormatter.startOfDay(now);

  while (!day.isAfter(today)) {
    for (final Medication medication in medications) {
      if (!isActiveOn(medication, day)) continue;
      for (final String time in medication.scheduleTimes) {
        if (!_isPastDue(day, time, now)) continue;

        final DoseLog? match = _matchingLog(
          allLogs.where((DoseLog l) => l.scheduledDate == DateFormatter.toApiDate(day)).toList(),
          medication.clientRecordId,
          time,
        );

        if (match == null) {
          due++;
        } else if (match.status == DoseStatus.skipped) {
          skipped++;
        } else {
          due++;
          if (match.status == DoseStatus.taken) taken++;
        }
      }
    }
    day = day.add(const Duration(days: 1));
  }

  return Adherence(taken: taken, due: due, skipped: skipped, windowDays: windowDays);
}

DoseLog? _matchingLog(List<DoseLog> logs, String medicationClientRecordId, String time) {
  for (final DoseLog log in logs) {
    if (log.medicationClientRecordId == medicationClientRecordId && log.scheduledTime == time) {
      return log;
    }
  }
  return null;
}

bool _isPastDue(DateTime date, String time, DateTime now) {
  final List<String> parts = time.split(':');
  final DateTime due = DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  );
  return !due.isAfter(now);
}
