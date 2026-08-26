import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// A pending notification the OS still holds, as far as this feature needs
/// to know about it — just enough to filter by [payload] for cancellation.
class PendingScheduledNotification {
  const PendingScheduledNotification({required this.id, required this.payload});
  final int id;
  final String? payload;
}

/// Thin seam over `flutter_local_notifications` so [MedicationNotifications]
/// is unit-testable without the real plugin binding.
abstract interface class NotificationScheduler {
  Future<void> init();

  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  });

  Future<List<PendingScheduledNotification>> pending();

  Future<void> cancel(int id);
}

class FlutterLocalNotificationsScheduler implements NotificationScheduler {
  FlutterLocalNotificationsScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'medication_reminders',
    'Medication reminders',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const NotificationDetails _details = NotificationDetails(
    android: _android,
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    tz_data.initializeTimeZones();
    // See Task 11's header note: hardcoded to the app's sole deployment
    // timezone rather than detecting the device's, which would need a
    // package this plan cannot add to pubspec.yaml.
    tz.setLocalLocation(tz.getLocation('Africa/Addis_Ababa'));

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      // See Task 11's header note: this same-time match makes every
      // notification — including the 1-hour follow-up — repeat daily. It
      // cannot be suppressed on days the dose was already logged without
      // OS-level background work outside a local-notifications package's
      // reach, so a patient who already logged today's dose may still see
      // the follow-up fire.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<List<PendingScheduledNotification>> pending() async {
    final List<PendingNotificationRequest> requests = await _plugin
        .pendingNotificationRequests();
    return requests
        .map(
          (PendingNotificationRequest r) =>
              PendingScheduledNotification(id: r.id, payload: r.payload),
        )
        .toList();
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);
}
