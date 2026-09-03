import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized || kIsWeb) return;

    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
      debugPrint('NotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationService: Initialization failed: $e');
    }
  }

  Future<void> scheduleEventReminder({
    required ScheduleEvent event,
    Course? course,
    int minutesBefore = 15,
  }) async {
    if (!_isInitialized) return;

    try {
      final now = DateTime.now();
      DateTime scheduledDate;

      if (event.recurring && event.daysOfWeek.isNotEmpty) {
        // Calculate next upcoming occurrence for recurring event
        DateTime nextDate = now;
        while (!event.daysOfWeek.contains(nextDate.weekday % 7)) {
          nextDate = nextDate.add(const Duration(days: 1));
        }
        scheduledDate = DateTime(
          nextDate.year,
          nextDate.month,
          nextDate.day,
          event.startTime.hour,
          event.startTime.minute,
        ).subtract(Duration(minutes: minutesBefore));

        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 7));
        }
      } else {
        scheduledDate = event.startTime.subtract(Duration(minutes: minutesBefore));
      }

      if (scheduledDate.isBefore(now)) return;

      final notificationId = event.id.hashCode.abs();
      final courseName = course?.name ?? '';
      final title = event.type == EventType.exam
          ? '🚨 Exam Reminder: ${event.title}'
          : '📚 Class in $minutesBefore min: ${event.title}';
      final body = event.location.isNotEmpty
          ? '$courseName • Room: ${event.location}'
          : courseName;

      await _notificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'rocis_schedule_channel',
            'Class & Exam Reminders',
            channelDescription: 'Notifications for upcoming classes and exams',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('NotificationService: Scheduled event reminder for ${event.title} at $scheduledDate');
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule event reminder: $e');
    }
  }

  Future<void> scheduleAssignmentReminder({
    required Assignment assignment,
    Course? course,
  }) async {
    if (!_isInitialized || assignment.isCompleted) return;

    try {
      final now = DateTime.now();
      // Remind 1 day before due date at 09:00 AM, or 3 hours before
      final scheduledDate = assignment.dueDate.subtract(const Duration(days: 1));
      if (scheduledDate.isBefore(now)) return;

      final notificationId = ('assign_${assignment.id}').hashCode.abs();
      final courseName = course?.name ?? '';
      final title = '📝 Assignment Due Tomorrow: ${assignment.title}';
      final body = courseName.isNotEmpty ? 'Course: $courseName' : 'Make sure to finish on time!';

      await _notificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'rocis_schedule_assignments',
            'Assignment Reminders',
            channelDescription: 'Notifications for upcoming assignment due dates',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule assignment reminder: $e');
    }
  }

  Future<void> cancelReminder(int id) async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
