import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/services/notification_service.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Resilience Suite', () {
    test('NotificationService maintains a singleton instance', () {
      final s1 = NotificationService();
      final s2 = NotificationService();
      expect(identical(s1, s2), isTrue);
    });

    test(
      'scheduleEventReminder executes without throwing when uninitialized',
      () async {
        final service = NotificationService();

        final event = ScheduleEvent(
          id: 'ev_notif_1',
          title: 'Midterm Exam',
          courseId: 'c_test',
          type: EventType.exam,
          startTime: DateTime.now().add(const Duration(days: 2)),
          endTime: DateTime.now().add(const Duration(days: 2, hours: 2)),
        );

        // Should complete cleanly with no uncaught exception
        await expectLater(
          service.scheduleEventReminder(event: event, minutesBefore: 30),
          completes,
        );
      },
    );

    test(
      'scheduleAssignmentReminder executes without throwing when uninitialized',
      () async {
        final service = NotificationService();

        final assignment = Assignment(
          id: 'assign_notif_1',
          courseId: 'c_test',
          title: 'Project Submission',
          dueDate: DateTime.now().add(const Duration(days: 1)),
          priority: AssignmentPriority.high,
        );

        await expectLater(
          service.scheduleAssignmentReminder(assignment: assignment),
          completes,
        );
      },
    );

    test('cancelReminder and cancelAll do not throw', () async {
      final service = NotificationService();
      await expectLater(service.cancelReminder(101), completes);
      await expectLater(service.cancelAll(), completes);
    });
  });
}
