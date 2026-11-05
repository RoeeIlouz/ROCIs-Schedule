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

      await _notificationsPlugin.initialize(settings: initSettings);
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
    // All-day events have no start time to count back from.
    if (!_isInitialized || event.allDay) return;

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
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: const NotificationDetails(
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
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: const NotificationDetails(
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
      );
    } catch (e) {
      debugPrint('NotificationService: Failed to schedule assignment reminder: $e');
    }
  }

  /// Asks for the notification permission Android 13+ needs. Safe to call
  /// repeatedly; returns false when denied or unavailable.
  Future<bool> requestPermission() async {
    if (!_isInitialized) return false;
    try {
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Schedules a one-off notice for the unfinished-assignments reminder.
  /// Inexact on purpose: a reminder a few minutes late needs no alarm permission.
  Future<void> scheduleAssignmentDigest({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!_isInitialized || !when.isAfter(DateTime.now())) return;
    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'rocis_schedule_assignment_digest',
            'Unfinished assignments',
            channelDescription: 'Daily reminder about assignments not done yet',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('NotificationService: digest schedule failed: $e');
    }
  }

  /// Shows a notification right away. A fixed [id] makes a repeat replace the
  /// previous one instead of stacking.
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'rocis_calendar_sync_channel',
            'Calendar sync',
            channelDescription: 'Timetable changes found by calendar sync',
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('NotificationService: showNow failed: $e');
    }
  }

  Future<void> cancelReminder(int id) async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
