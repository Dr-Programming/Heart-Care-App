import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/daos/preferences_dao.dart';
import '../providers/core_providers.dart';
import '../utils/date_formatter.dart';
import 'one_time_reminders.dart';

/// The daily "do your check-in" reminder, at the time chosen in the setup
/// wizard. The next [daysAhead] days are scheduled as single reminders and
/// renewed whenever the app opens, so one that is already done (today's
/// check-in is saved) is simply not scheduled.
class CheckInReminder {
  const CheckInReminder(this._reminders, this._prefs);

  final OneTimeReminders _reminders;
  final PreferencesDao _prefs;

  static const String payloadPrefix = 'checkin|';
  static const String defaultTime = '19:30';
  static const int daysAhead = 7;

  /// Call after a check-in is saved: no reminder for the rest of today.
  Future<void> checkedIn({DateTime? now}) async {
    final DateTime today = now ?? DateTime.now();
    await _prefs.set(
      PreferenceKeys.lastCheckInDate,
      DateFormatter.toApiDate(today),
    );
    await reschedule(now: today);
  }

  /// Best effort, like the other reminders: a phone that can't schedule
  /// notifications must not stop the screen that asked.
  Future<void> reschedule({DateTime? now}) async {
    try {
      await _schedule(now ?? DateTime.now());
    } on Object {
      // Notifications unavailable; the check-in itself still works.
    }
  }

  Future<void> _schedule(DateTime current) async {
    await _reminders.cancelWithPrefix(payloadPrefix);
    if (await _prefs.get(PreferenceKeys.notificationsEnabled) == 'false') {
      return;
    }
    if (await _prefs.get(PreferenceKeys.symptomReminderEnabled) == 'false') {
      return;
    }
    final List<String> parts =
        (await _prefs.get(PreferenceKeys.symptomPromptTime) ?? defaultTime)
            .split(':');
    final int hour = int.tryParse(parts.first) ?? 19;
    final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30;
    final String doneOn =
        await _prefs.get(PreferenceKeys.lastCheckInDate) ?? '';

    for (int d = 0; d < daysAhead; d++) {
      final DateTime at = DateTime(
        current.year,
        current.month,
        current.day + d,
        hour,
        minute,
      );
      final String day = DateFormatter.toApiDate(at);
      if (!at.isAfter(current) || day == doneOn) continue;
      await _reminders.schedule(
        id: '$payloadPrefix$day'.hashCode & 0x7fffffff,
        title: 'symptoms.reminder.title'.tr(),
        body: 'symptoms.reminder.body'.tr(),
        when: at,
        payload: '$payloadPrefix$day',
      );
    }
  }
}

final Provider<CheckInReminder> checkInReminderProvider =
    Provider<CheckInReminder>(
      (Ref ref) => CheckInReminder(
        ref.watch(oneTimeRemindersProvider),
        ref.watch(appDatabaseProvider).preferencesDao,
      ),
    );
