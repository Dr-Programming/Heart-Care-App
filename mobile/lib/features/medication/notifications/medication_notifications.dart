import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

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
        payload: _payloadFor(
          medication.clientRecordId,
          time,
          isFollowUp: false,
        ),
      );
      await _scheduler.zonedSchedule(
        id: _idFor(medication.clientRecordId, time, isFollowUp: true),
        title: 'meds.notifications.followUpTitle'.tr(),
        body: 'meds.notifications.followUpBody'.tr(
          namedArgs: <String, String>{'name': medication.name},
        ),
        when: await _nextFollowUp(medication.clientRecordId, time),
        payload: _payloadFor(medication.clientRecordId, time, isFollowUp: true),
      );
    }
  }

  /// A dose was marked taken, missed or skipped: today's "you have not
  /// logged it yet" follow-up for that time is no longer true, so it starts
  /// again tomorrow. Remembered, so reopening the app doesn't bring it back.
  Future<void> doseLogged(
    Medication medication, {
    required String time,
    required String scheduledDate,
    DateTime? now,
  }) async {
    final DateTime today = now ?? DateTime.now();
    if (scheduledDate != _date(today)) return;
    await markLogged(
      medication.clientRecordId,
      time: time,
      scheduledDate: scheduledDate,
    );
    await scheduleFor(medication);
  }

  /// Notes that the dose at [time] on [scheduledDate] is logged, so the next
  /// [scheduleFor] leaves out that day's follow-up.
  Future<void> markLogged(
    String medicationClientRecordId, {
    required String time,
    required String scheduledDate,
  }) => _prefs.set(_loggedKey(medicationClientRecordId, time), scheduledDate);

  /// When the next follow-up for [time] fires; for tests.
  @visibleForTesting
  Future<DateTime> nextFollowUpFor(
    String medicationClientRecordId,
    String time, {
    DateTime? now,
  }) => _nextFollowUp(medicationClientRecordId, time, now: now);

  String _loggedKey(String medicationClientRecordId, String time) =>
      'dose_logged_${medicationClientRecordId}_$time';

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// One hour after the dose time, the next time that is still to come and
  /// whose dose hasn't been logged yet.
  Future<DateTime> _nextFollowUp(
    String medicationClientRecordId,
    String time, {
    DateTime? now,
  }) async {
    final DateTime current = now ?? DateTime.now();
    final List<String> parts = time.split(':');
    DateTime dose = DateTime(
      current.year,
      current.month,
      current.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
    final String? logged = await _prefs.get(
      _loggedKey(medicationClientRecordId, time),
    );
    while (!dose.add(followUpDelay).isAfter(current) ||
        _date(dose) == logged) {
      dose = DateTime(dose.year, dose.month, dose.day + 1, dose.hour, dose.minute);
    }
    return dose.add(followUpDelay);
  }

  Future<void> cancelFor(String medicationClientRecordId) async {
    final List<PendingScheduledNotification> all = await _scheduler.pending();
    for (final PendingScheduledNotification n in all) {
      if (n.payload != null &&
          n.payload!.startsWith('$medicationClientRecordId|')) {
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

  int _idFor(
    String medicationClientRecordId,
    String time, {
    required bool isFollowUp,
  }) {
    return _payloadFor(
          medicationClientRecordId,
          time,
          isFollowUp: isFollowUp,
        ).hashCode &
        0x7fffffff;
  }

  String _payloadFor(
    String medicationClientRecordId,
    String time, {
    required bool isFollowUp,
  }) {
    return '$medicationClientRecordId|$time|${isFollowUp ? 'follow' : 'main'}';
  }

  DateTime _nextOccurrence(String time) {
    final List<String> parts = time.split(':');
    final int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);
    final DateTime now = DateTime.now();
    DateTime candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}
