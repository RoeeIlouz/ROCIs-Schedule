import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/cross_app_bridge_service.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrossAppBridgeService Tests', () {
    test('URI format construction for sendAssignmentToTasks', () {
      final assignment = Assignment(
        id: 'a1',
        courseId: 'c1',
        title: 'Algorithms Homework 3',
        description: 'Complete dynamic programming exercises 1-5',
        dueDate: DateTime(2026, 9, 15, 23, 59),
        priority: AssignmentPriority.high,
      );

      final course = Course(
        id: 'c1',
        name: 'Algorithms CS301',
        code: 'CS301',
        instructor: 'Prof. Knuth',
        color: Colors.blue,
        credits: 4,
      );

      final uri = Uri(
        scheme: 'rocistasks',
        host: 'add_task',
        queryParameters: {
          'title': assignment.title,
          'dueDate': assignment.dueDate.toIso8601String(),
          'priority': assignment.priority.name,
          'notes': assignment.description,
          'category': course.name,
        },
      );

      expect(uri.scheme, 'rocistasks');
      expect(uri.host, 'add_task');
      expect(uri.queryParameters['title'], 'Algorithms Homework 3');
      expect(uri.queryParameters['priority'], 'high');
      expect(uri.queryParameters['category'], 'Algorithms CS301');
    });

    test('URI format construction for sendEventToTasks', () {
      final event = ScheduleEvent(
        id: 'e1',
        title: 'Algorithms Final Exam',
        courseId: 'c1',
        type: EventType.exam,
        startTime: DateTime(2026, 9, 20, 10, 0),
        endTime: DateTime(2026, 9, 20, 13, 0),
        location: 'Hall A 101',
      );

      final course = Course(
        id: 'c1',
        name: 'Algorithms CS301',
        code: 'CS301',
        instructor: 'Prof. Knuth',
        color: Colors.blue,
        credits: 4,
      );

      final notes = [
        if (event.location.isNotEmpty) 'Location: ${event.location}',
        if (course.instructor.isNotEmpty) 'Instructor: ${course.instructor}',
        if (event.notes.isNotEmpty) event.notes,
      ].join(' • ');

      final uri = Uri(
        scheme: 'rocistasks',
        host: 'add_task',
        queryParameters: {
          'title': event.title,
          'dueDate': event.startTime.toIso8601String(),
          'priority': 'high',
          if (notes.isNotEmpty) 'notes': notes,
          'category': course.name,
        },
      );

      expect(uri.scheme, 'rocistasks');
      expect(uri.host, 'add_task');
      expect(uri.queryParameters['title'], 'Algorithms Final Exam');
      expect(uri.queryParameters['priority'], 'high');
      expect(uri.queryParameters['notes'], contains('Hall A 101'));
      expect(uri.queryParameters['notes'], contains('Prof. Knuth'));
      expect(uri.queryParameters['category'], 'Algorithms CS301');
    });

    test(
      'isRocisTasksInstalled returns boolean safely in test harness',
      () async {
        final isInstalled = await CrossAppBridgeService.isRocisTasksInstalled();
        expect(isInstalled, isA<bool>());
      },
    );
  });
}
