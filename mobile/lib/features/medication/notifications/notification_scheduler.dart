import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class PendingScheduledNotification {
  const PendingScheduledNotification({required this.id, required this.payload});
  final int id;
  final String? payload;
}

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
