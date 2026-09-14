import 'package:easy_localization/easy_localization.dart';

import '../../../core/db/app_database.dart' hide Medication;
import '../../../core/db/daos/preferences_dao.dart';
import '../domain/entities/medication.dart';
import 'notification_scheduler.dart';

class MedicationNotifications {
  MedicationNotifications(this._scheduler, this._prefs);

  final NotificationScheduler _scheduler;
  final PreferencesDao _prefs;

  static const Duration followUpDelay = Duration(hours: 1);

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

    return raw != 'false';
  }

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
