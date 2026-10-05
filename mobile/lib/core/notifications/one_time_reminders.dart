import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notifications that fire once at a set moment (appointment reminders),
/// on their own Android channel. Medication reminders repeat daily and keep
/// their own scheduler.
abstract interface class OneTimeReminders {
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  });

  /// Cancels every pending reminder whose payload starts with [prefix].
  Future<void> cancelWithPrefix(String prefix);
}

class LocalOneTimeReminders implements OneTimeReminders {
  LocalOneTimeReminders(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'appointment_reminders',
      'Appointment reminders',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_libucare',
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Addis_Ababa'));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_libucare'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    await _init();
    final tz.TZDateTime at = tz.TZDateTime.from(when, tz.local);
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        at,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } on PlatformException {
      // Exact alarms not allowed on this phone: a few minutes late is fine.
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        at,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  @override
  Future<void> cancelWithPrefix(String prefix) async {
    await _init();
    for (final PendingNotificationRequest r
        in await _plugin.pendingNotificationRequests()) {
      if (r.payload?.startsWith(prefix) ?? false) await _plugin.cancel(r.id);
    }
  }
}

final Provider<OneTimeReminders> oneTimeRemindersProvider =
    Provider<OneTimeReminders>(
      (Ref ref) => LocalOneTimeReminders(FlutterLocalNotificationsPlugin()),
    );
