// Author: Ihab Al-Nasheei
// Last updated by: Ihab Al-Nasheei

import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/notifications/check_in_reminder.dart';
import 'package:libu_care/core/notifications/one_time_reminders.dart';

import '../../helpers/test_database.dart';

class _FakeReminders implements OneTimeReminders {
  final Map<String, DateTime> scheduled = <String, DateTime>{};

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduled[payload] = when;
  }

  @override
  Future<void> cancelWithPrefix(String prefix) async {
    scheduled.removeWhere((String payload, _) => payload.startsWith(prefix));
  }
}

void main() {
  late AppDatabase db;
  late _FakeReminders reminders;
  late CheckInReminder reminder;
  final DateTime morning = DateTime(2026, 8, 25, 9);

  setUp(() {
    db = testDatabase();
    reminders = _FakeReminders();
    reminder = CheckInReminder(reminders, db.preferencesDao);
  });

  tearDown(() => db.close());

  test('schedules a week of reminders at the chosen time', () async {
    await db.preferencesDao.set(PreferenceKeys.symptomPromptTime, '19:30');

    await reminder.reschedule(now: morning);

    expect(reminders.scheduled, hasLength(CheckInReminder.daysAhead));
    expect(
      reminders.scheduled['${CheckInReminder.payloadPrefix}2026-08-25'],
      DateTime(2026, 8, 25, 19, 30),
    );
  });

  test('a check-in today removes today\'s reminder only', () async {
    await reminder.checkedIn(now: morning);

    expect(
      reminders.scheduled.containsKey(
        '${CheckInReminder.payloadPrefix}2026-08-25',
      ),
      isFalse,
    );
    expect(
      reminders.scheduled.containsKey(
        '${CheckInReminder.payloadPrefix}2026-08-26',
      ),
      isTrue,
    );
  });

  test('nothing is scheduled when the reminder or notifications are off', () async {
    await db.preferencesDao.set(PreferenceKeys.symptomReminderEnabled, 'false');
    await reminder.reschedule(now: morning);
    expect(reminders.scheduled, isEmpty);

    await db.preferencesDao.set(PreferenceKeys.symptomReminderEnabled, 'true');
    await db.preferencesDao.set(PreferenceKeys.notificationsEnabled, 'false');
    await reminder.reschedule(now: morning);
    expect(reminders.scheduled, isEmpty);
  });
}
