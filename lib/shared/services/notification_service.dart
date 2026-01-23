import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:rocis_schedule/shared/models/schedule_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const DarwinInitializationSettings ios = DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _notifications.initialize(settings);
  }

  Future<void> scheduleClassReminder(ScheduleEvent event) async {
    // Schedule 10 minutes before
    final scheduleTime = event.startTime.subtract(const Duration(minutes: 10));
    if (scheduleTime.isBefore(DateTime.now())) return;

    await _notifications.zonedSchedule(
      event.id.hashCode,
      'Upcoming Class: ${event.title}',
      'Starts in 10 minutes at ${event.location}',
      tz.TZDateTime.from(scheduleTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: event.recurring
          ? DateTimeComponents.dayOfWeekAndTime
          : null,
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
