import '../domain/entities/medication.dart';
import '../domain/repositories/medication_repository.dart';
import 'medication_notifications.dart';
import 'notification_scheduler.dart';

/// Brings medication reminders back up, and takes them back down again.
///
/// Decision 4 says reminders are rescheduled "on add/edit/deactivate/
/// reactivate **and on app start**" — Android drops every pending alarm on
/// reboot and on force-stop, so a patient who restarts their phone would
/// otherwise silently stop being reminded. The add/edit path is handled by
/// `MedicationFormController`; this class is the app-start half, plus the
/// bulk cancel/re-arm the reminders switch needs (spec: "cancel everything
/// when it is off — do not just suppress display").
///
/// Kept as a plain class over three injected collaborators rather than a
/// provider body so it is unit-testable with fakes and so the same
/// [rescheduleAll] runs from both callers instead of being written twice.
class MedicationReminderBootstrap {
  const MedicationReminderBootstrap({
    required this.scheduler,
    required this.notifications,
    required this.repository,
  });

  final NotificationScheduler scheduler;
  final MedicationNotifications notifications;
  final MedicationRepository repository;

  /// App start: initialise the plugin (timezone database, notification
  /// channels, and the Android 13+ `POST_NOTIFICATIONS` permission prompt),
  /// then re-arm every active medication's reminders.
  ///
  /// [MedicationNotifications.scheduleFor] checks
  /// `PreferenceKeys.notificationsEnabled` itself, so this is already a no-op
  /// for a patient who turned reminders off.
  Future<void> start() async {
    await scheduler.init();
    await rescheduleAll();
  }

  /// Re-arms reminders for every currently active medication.
  ///
  /// `scheduleFor` cancels that medication's existing reminders first, so
  /// running this repeatedly replaces rather than duplicates.
  Future<void> rescheduleAll() async {
    final List<Medication> medications = await repository.activeMedications();
    for (final Medication medication in medications) {
      await notifications.scheduleFor(medication);
    }
  }

  /// Cancels every reminder this feature has scheduled.
  ///
  /// Deliberately over `allMedications(includeInactive: true)` rather than
  /// only the active ones: a medication deactivated while its reminders were
  /// still pending has to be swept up too, and cancelling a medication with
  /// nothing pending costs nothing.
  Future<void> cancelAll() async {
    final List<Medication> medications = await repository.allMedications(
      includeInactive: true,
    );
    await notifications.cancelAll(medications);
  }
}
