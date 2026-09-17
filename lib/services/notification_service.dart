import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  int _notificationId(String sourceId) => sourceId.hashCode & 0x7fffffff;

  Future<void> scheduleReminder({
    required String sourceId,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    if (dateTime.isBefore(DateTime.now())) return;
    try {
      await init();
      const androidDetails = AndroidNotificationDetails(
        'wedding_reminders',
        'Wedding Reminders',
        channelDescription: 'Reminders for tasks, payments, and RSVPs',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.zonedSchedule(
        _notificationId(sourceId),
        title,
        body,
        tz.TZDateTime.from(dateTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      // Reminders are best-effort; a plugin/platform failure here must
      // never block saving the underlying checklist/budget item.
      debugPrint('NotificationService.scheduleReminder failed: $e\n$st');
    }
  }

  Future<void> cancelReminder(String sourceId) async {
    try {
      await _plugin.cancel(_notificationId(sourceId));
    } catch (e, st) {
      debugPrint('NotificationService.cancelReminder failed: $e\n$st');
    }
  }
}
