import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'data/caregiver_notify_store.dart';
import 'data/datasources/medication_local_datasource.dart';
import 'data/datasources/medication_remote_datasource.dart';
import 'data/medication_instructions_store.dart';
import 'data/repositories/medication_repository_impl.dart';
import 'domain/repositories/medication_repository.dart';
import 'notifications/medication_notifications.dart';
import 'notifications/notification_scheduler.dart';
import 'notifications/reminder_bootstrap.dart';

final Provider<MedicationLocalDataSource> medicationLocalDataSourceProvider =
    Provider<MedicationLocalDataSource>(
      (Ref ref) => MedicationLocalDataSource(ref.watch(appDatabaseProvider)),
    );

final Provider<MedicationRemoteDataSource> medicationRemoteDataSourceProvider =
    Provider<MedicationRemoteDataSource>(
      (Ref ref) => MedicationRemoteDataSource(ref.watch(dioProvider)),
    );

final Provider<MedicationRepository> medicationRepositoryProvider =
    Provider<MedicationRepository>(
      (Ref ref) => MedicationRepositoryImpl(
        local: ref.watch(medicationLocalDataSourceProvider),
        remote: ref.watch(medicationRemoteDataSourceProvider),
        syncEnqueuer: ref.watch(syncEnqueuerProvider),
        syncQueueDao: ref.watch(syncQueueDaoProvider),
        preferences: ref.watch(appDatabaseProvider).preferencesDao,
        isOnline: ref.watch(isOnlineProvider),
      ),
    );

final Provider<NotificationScheduler> notificationSchedulerProvider =
    Provider<NotificationScheduler>(
      (Ref ref) =>
          FlutterLocalNotificationsScheduler(FlutterLocalNotificationsPlugin()),
    );

final Provider<MedicationNotifications> medicationNotificationsProvider =
    Provider<MedicationNotifications>(
      (Ref ref) => MedicationNotifications(
        ref.watch(notificationSchedulerProvider),
        ref.watch(appDatabaseProvider).preferencesDao,
      ),
    );

final Provider<CaregiverNotifyStore> caregiverNotifyStoreProvider =
    Provider<CaregiverNotifyStore>(
      (Ref ref) => CaregiverNotifyStore(ref.watch(appDatabaseProvider).preferencesDao),
    );

final Provider<MedicationInstructionsStore> medicationInstructionsStoreProvider =
    Provider<MedicationInstructionsStore>(
      (Ref ref) => MedicationInstructionsStore(ref.watch(appDatabaseProvider).preferencesDao),
    );

final Provider<MedicationReminderBootstrap> medicationReminderBootstrapProvider =
    Provider<MedicationReminderBootstrap>(
      (Ref ref) => MedicationReminderBootstrap(
        scheduler: ref.watch(notificationSchedulerProvider),
        notifications: ref.watch(medicationNotificationsProvider),
        repository: ref.watch(medicationRepositoryProvider),
      ),
    );

final Provider<void> medicationRemindersStartupProvider = Provider<void>((
  Ref ref,
) {
  final MedicationReminderBootstrap bootstrap = ref.watch(
    medicationReminderBootstrapProvider,
  );
  unawaited(bootstrap.start().catchError((Object _) {}));
});
