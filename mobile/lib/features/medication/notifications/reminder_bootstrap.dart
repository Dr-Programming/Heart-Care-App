import '../domain/entities/medication.dart';
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
