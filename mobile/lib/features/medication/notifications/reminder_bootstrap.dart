// Author: Ihab Al-Nasheei
// Last updated by: Ihab Al-Nasheei

import '../domain/entities/medication.dart';
import '../domain/entities/scheduled_dose.dart';
import '../domain/repositories/medication_repository.dart';
import 'medication_notifications.dart';
import 'notification_scheduler.dart';

class MedicationReminderBootstrap {
  const MedicationReminderBootstrap({
    required this.scheduler,
    required this.notifications,
    required this.repository,
  });

  final NotificationScheduler scheduler;
  final MedicationNotifications notifications;
  final MedicationRepository repository;

  Future<void> start() async {
    await scheduler.init();
    await rescheduleAll();
  }

  Future<void> rescheduleAll() async {
    // Doses already logged today (on this phone or another, then downloaded)
    // need no "not logged yet" follow-up.
    try {
      for (final ScheduledDose dose in await repository.todaysDoses()) {
        if (dose.doseLog != null) {
          await notifications.markLogged(
            dose.medicationClientRecordId,
            time: dose.scheduledTime.substring(0, 5),
            scheduledDate: dose.scheduledDate,
          );
        }
      }
    } on Object {
      // Best effort; reminders still get scheduled below.
    }
    final List<Medication> medications = await repository.activeMedications();
    for (final Medication medication in medications) {
      await notifications.scheduleFor(medication);
    }
  }

  Future<void> cancelAll() async {
    final List<Medication> medications = await repository.allMedications(
      includeInactive: true,
    );
    await notifications.cancelAll(medications);
  }
}
