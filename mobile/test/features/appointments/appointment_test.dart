import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/core/db/app_database.dart';
import 'package:libu_care/core/notifications/one_time_reminders.dart';
import 'package:libu_care/features/appointments/appointment_providers.dart';
import 'package:libu_care/features/appointments/data/appointment_store.dart';
import 'package:libu_care/features/appointments/domain/appointment.dart';

import '../../helpers/test_database.dart';

class _RecordingReminders implements OneTimeReminders {
  final Map<String, DateTime> scheduled = <String, DateTime>{};
  final List<String> cancelledPrefixes = <String>[];

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async => scheduled[payload] = when;

  @override
  Future<void> cancelWithPrefix(String prefix) async {
    cancelledPrefixes.add(prefix);
    scheduled.removeWhere((String payload, _) => payload.startsWith(prefix));
  }
}

void main() {
  final DateTime now = DateTime(2026, 10, 3, 12);

  group('reminderTimes', () {
    test('2 days before and the day before at 18:00, and 2 hours before on the day', () {
      final Appointment a = Appointment(
        id: 'a',
        at: DateTime(2026, 10, 10, 10),
      );

      expect(reminderTimes(a, now: now), <ReminderTiming, DateTime>{
        ReminderTiming.twoDaysBefore: DateTime(2026, 10, 8, 18),
        ReminderTiming.dayBefore: DateTime(2026, 10, 9, 18),
        ReminderTiming.sameDay: DateTime(2026, 10, 10, 8),
      });
    });

    test(
      'an early visit is reminded at 06:00, a very early one 30 minutes before',
      () {
        expect(
          reminderTimes(
            Appointment(id: 'a', at: DateTime(2026, 10, 10, 7)),
            now: now,
          )[ReminderTiming.sameDay],
          DateTime(2026, 10, 10, 6),
        );
        expect(
          reminderTimes(
            Appointment(id: 'a', at: DateTime(2026, 10, 10, 6)),
            now: now,
          )[ReminderTiming.sameDay],
          DateTime(2026, 10, 10, 5, 30),
        );
      },
    );

    test('reminders already in the past are left out', () {
      // Visit tomorrow morning: the "2 days before" moment has passed.
      final Appointment a = Appointment(id: 'a', at: DateTime(2026, 10, 4, 10));

      expect(reminderTimes(a, now: now).keys, <ReminderTiming>[
        ReminderTiming.dayBefore,
        ReminderTiming.sameDay,
      ]);
    });

    test('only the reminders the patient kept are used', () {
      final Appointment a = Appointment(
        id: 'a',
        at: DateTime(2026, 10, 10, 10),
        reminders: const <ReminderTiming>{ReminderTiming.dayBefore},
      );

      expect(reminderTimes(a, now: now).keys, <ReminderTiming>[
        ReminderTiming.dayBefore,
      ]);
    });
  });

  test('daysUntil counts calendar days', () {
    expect(
      daysUntil(
        Appointment(id: 'a', at: DateTime(2026, 10, 3, 23)),
        now: now,
      ),
      0,
    );
    expect(
      daysUntil(
        Appointment(id: 'a', at: DateTime(2026, 10, 4, 8)),
        now: now,
      ),
      1,
    );
    expect(
      daysUntil(
        Appointment(id: 'a', at: DateTime(2026, 10, 6, 8)),
        now: now,
      ),
      3,
    );
  });

  test('an appointment survives a round trip through JSON', () {
    final Appointment a = Appointment(
      id: 'a',
      at: DateTime(2026, 10, 10, 10, 30),
      place: 'Black Lion',
      note: 'Check-up',
      reminders: const <ReminderTiming>{ReminderTiming.sameDay},
    );

    expect(Appointment.fromJson(a.toJson()), a);
  });

  group('AppointmentStore', () {
    late AppDatabase db;
    late AppointmentStore store;
    setUp(() {
      db = testDatabase();
      store = AppointmentStore(db.preferencesDao);
    });
    tearDown(() => db.close());

    test(
      'keeps appointments soonest first, replaces by id, and deletes',
      () async {
        await store.save(Appointment(id: 'late', at: DateTime(2026, 11, 1, 9)));
        await store.save(Appointment(id: 'soon', at: DateTime(2026, 10, 5, 9)));
        expect((await store.all()).map((Appointment a) => a.id), <String>[
          'soon',
          'late',
        ]);

        await store.save(
          Appointment(id: 'soon', at: DateTime(2026, 12, 1, 9), place: 'Moved'),
        );
        expect((await store.all()).map((Appointment a) => a.id), <String>[
          'late',
          'soon',
        ]);
        expect((await store.all()).last.place, 'Moved');

        await store.delete('late');
        expect((await store.all()).map((Appointment a) => a.id), <String>[
          'soon',
        ]);
      },
    );
  });

  group('AppointmentReminders', () {
    test(
      'schedules one reminder per timing, and cancels them together',
      () async {
        final _RecordingReminders recorder = _RecordingReminders();
        final AppointmentReminders reminders = AppointmentReminders(recorder);
        final Appointment a = Appointment(
          id: 'a1',
          at: DateTime(2026, 10, 10, 10),
          place: 'Black Lion',
        );

        await reminders.scheduleFor(a, now: now);
        expect(
          recorder.scheduled.keys,
          unorderedEquals(<String>[
            'appointment|a1|2d',
            'appointment|a1|1d',
            'appointment|a1|0d',
          ]),
        );
        expect(
          recorder.scheduled['appointment|a1|0d'],
          DateTime(2026, 10, 10, 8),
        );

        await reminders.cancelFor('a1');
        expect(recorder.scheduled, isEmpty);
      },
    );

    test('rescheduling replaces the old reminders', () async {
      final _RecordingReminders recorder = _RecordingReminders();
      final AppointmentReminders reminders = AppointmentReminders(recorder);

      await reminders.scheduleFor(
        Appointment(id: 'a1', at: DateTime(2026, 10, 10, 10)),
        now: now,
      );
      await reminders.scheduleFor(
        Appointment(
          id: 'a1',
          at: DateTime(2026, 10, 20, 10),
          reminders: const <ReminderTiming>{ReminderTiming.sameDay},
        ),
        now: now,
      );

      expect(recorder.scheduled, <String, DateTime>{
        'appointment|a1|0d': DateTime(2026, 10, 20, 8),
      });
    });

    test('a patient switch cancels every appointment reminder', () async {
      final _RecordingReminders recorder = _RecordingReminders();
      await AppointmentReminders(recorder).cancelAll();

      expect(recorder.cancelledPrefixes, <String>['appointment|']);
    });
  });
}
