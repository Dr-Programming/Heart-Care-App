import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/notifications/one_time_reminders.dart';
import '../../core/providers/core_providers.dart';
import '../../core/utils/date_formatter.dart';
import 'data/appointment_store.dart';
import 'domain/appointment.dart';

/// Schedules and cancels the reminders for appointments. Payloads are
/// `appointment|<id>|<timing>`, so one appointment's reminders can be
/// cancelled together.
class AppointmentReminders {
  AppointmentReminders(this._reminders);

  final OneTimeReminders _reminders;

  static const String _prefix = 'appointment|';

  Future<void> scheduleFor(Appointment appointment, {DateTime? now}) async {
    await cancelFor(appointment.id);
    final String time = DateFormatter.toClock(appointment.at);
    final String date = DateFormat.MMMEd(Intl.getCurrentLocale())
        .format(appointment.at);
    final String place = appointment.place.trim().isEmpty
        ? 'appointments.notification.yourClinic'.tr()
        : appointment.place.trim();
    final Map<String, String> args = <String, String>{
      'place': place,
      'time': time,
      'date': date,
    };

    for (final MapEntry<ReminderTiming, DateTime> e in reminderTimes(
      appointment,
      now: now,
    ).entries) {
      final String payload = '$_prefix${appointment.id}|${e.key.code}';
      await _reminders.schedule(
        id: payload.hashCode & 0x7fffffff,
        title: 'appointments.notification.${e.key.code}.title'.tr(),
        body: 'appointments.notification.${e.key.code}.body'.tr(
          namedArgs: args,
        ),
        when: e.value,
        payload: payload,
      );
    }
  }

  Future<void> cancelFor(String appointmentId) =>
      _reminders.cancelWithPrefix('$_prefix$appointmentId|');

  /// Every appointment reminder on this phone, e.g. when another patient
  /// signs in.
  Future<void> cancelAll() => _reminders.cancelWithPrefix(_prefix);
}

final Provider<AppointmentStore> appointmentStoreProvider =
    Provider<AppointmentStore>(
      (Ref ref) =>
          AppointmentStore(ref.watch(appDatabaseProvider).preferencesDao),
    );

final Provider<AppointmentReminders> appointmentRemindersProvider =
    Provider<AppointmentReminders>(
      (Ref ref) => AppointmentReminders(ref.watch(oneTimeRemindersProvider)),
    );

/// All appointments, soonest first, kept current as they change.
final StreamProvider<List<Appointment>> appointmentsProvider =
    StreamProvider<List<Appointment>>((Ref ref) {
      final AppDatabase db = ref.watch(appDatabaseProvider);
      return (db.select(db.preferences)..where(
            ($PreferencesTable t) => t.key.equals(AppointmentStore.storageKey),
          ))
          .watchSingleOrNull()
          .map((Preference? row) => AppointmentStore.parse(row?.value));
    });

/// Save and delete, keeping the reminders in step.
class AppointmentActions {
  AppointmentActions(this._store, this._reminders);

  final AppointmentStore _store;
  final AppointmentReminders _reminders;

  Future<void> save(Appointment appointment) async {
    await _store.save(appointment);
    // A missing notification permission must not lose the appointment.
    try {
      await _reminders.scheduleFor(appointment);
    } on Object {
      // The appointment is saved; the Home card still shows it.
    }
  }

  Future<void> delete(String id) async {
    await _store.delete(id);
    try {
      await _reminders.cancelFor(id);
    } on Object {
      // Nothing scheduled, or notifications unavailable.
    }
  }
}

final Provider<AppointmentActions> appointmentActionsProvider =
    Provider<AppointmentActions>(
      (Ref ref) => AppointmentActions(
        ref.watch(appointmentStoreProvider),
        ref.watch(appointmentRemindersProvider),
      ),
    );
