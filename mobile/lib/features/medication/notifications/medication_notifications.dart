import 'package:easy_localization/easy_localization.dart';

// `app_database.dart` re-exports `tables.dart`, whose Drift-generated row
// class for the `Medications` table defaults to the name `Medication` —
// identical to this feature's domain entity, imported below. Hiding it
// avoids an ambiguous-import error; this file only needs `PreferenceKeys`
// from this import (see `medication_repository_impl.dart` for the same
// pattern).
import '../../../core/db/app_database.dart' hide Medication;
import '../../../core/db/daos/preferences_dao.dart';
import '../domain/entities/medication.dart';
import 'notification_scheduler.dart';

/// Scheduling policy for medication reminders (Decision 4). Reschedule on
/// every add/edit/deactivate/reactivate and on app start — the caller (the
/// controller) is responsible for calling [scheduleFor] at those points.
class MedicationNotifications {
  MedicationNotifications(this._scheduler, this._prefs);

  final NotificationScheduler _scheduler;
  final PreferencesDao _prefs;

  static const Duration followUpDelay = Duration(hours: 1);

  /// Cancels any existing reminders for this medication, then — if it is
  /// active and notifications are enabled — schedules a main reminder and a
  /// one-hour follow-up for every scheduled time.
  Future<void> scheduleFor(Medication medication) async {
    await cancelFor(medication.clientRecordId);
    if (!medication.active) return;
    if (!await _notificationsEnabled()) return;

    for (final String time in medication.scheduleTimes) {
      final DateTime first = _nextOccurrence(time);
      await _scheduler.zonedSchedule(
        id: _idFor(medication.clientRecordId, time, isFollowUp: false),
        title: 'meds.notifications.doseTitle'.tr(),
        body: 'meds.notifications.doseBody'.tr(
          namedArgs: <String, String>{'name': medication.name},
        ),
        when: first,
        payload: _payloadFor(medication.clientRecordId, time, isFollowUp: false),
      );
      await _scheduler.zonedSchedule(
        id: _idFor(medication.clientRecordId, time, isFollowUp: true),
        title: 'meds.notifications.followUpTitle'.tr(),
        body: 'meds.notifications.followUpBody'.tr(
          namedArgs: <String, String>{'name': medication.name},
        ),
        when: first.add(followUpDelay),
        payload: _payloadFor(medication.clientRecordId, time, isFollowUp: true),
      );
    }
  }

  /// Cancels every reminder for one medication, found by filtering the OS's
  /// pending list by payload prefix — there is no other local index of
  /// "which ids belong to this medication".
  Future<void> cancelFor(String medicationClientRecordId) async {
    final List<PendingScheduledNotification> all = await _scheduler.pending();
    for (final PendingScheduledNotification n in all) {
      if (n.payload != null && n.payload!.startsWith('$medicationClientRecordId|')) {
        await _scheduler.cancel(n.id);
      }
    }
  }

  Future<void> cancelAll(List<Medication> medications) async {
    for (final Medication medication in medications) {
      await cancelFor(medication.clientRecordId);
    }
  }

  Future<bool> _notificationsEnabled() async {
    final String? raw = await _prefs.get(PreferenceKeys.notificationsEnabled);
    // Defaults to on: M2 (settings) owns this key and may not have run yet.
    return raw != 'false';
  }

  /// Stable and reversible: the same medication+time+kind always derives the
  /// same id, so scheduling again replaces rather than duplicates.
  int _idFor(String medicationClientRecordId, String time, {required bool isFollowUp}) {
    return _payloadFor(medicationClientRecordId, time, isFollowUp: isFollowUp).hashCode &
        0x7fffffff;
  }

  String _payloadFor(String medicationClientRecordId, String time, {required bool isFollowUp}) {
    return '$medicationClientRecordId|$time|${isFollowUp ? 'follow' : 'main'}';
  }

  DateTime _nextOccurrence(String time) {
    final List<String> parts = time.split(':');
    final int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);
    final DateTime now = DateTime.now();
    DateTime candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (!candidate.isAfter(now)) candidate = candidate.add(const Duration(days: 1));
    return candidate;
  }
}
