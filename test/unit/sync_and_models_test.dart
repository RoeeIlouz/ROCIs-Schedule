import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

void main() {
  group('Course Model Tests', () {
    test('Course toMap and fromMap serialization', () {
      final course = Course(
        id: 'c1',
        name: 'Data Structures',
        code: 'CS201',
        instructor: 'Dr. Turing',
        color: const Color(0xFF4285F4),
        credits: 4,
      );

      final map = course.toMap();
      expect(map['id'], 'c1');
      expect(map['name'], 'Data Structures');
      expect(map['code'], 'CS201');
      expect(map['instructor'], 'Dr. Turing');
      expect(map['color'], const Color(0xFF4285F4).toARGB32());
      expect(map['credits'], 4);

      final fromMap = Course.fromMap(map);
      expect(fromMap.id, course.id);
      expect(fromMap.name, course.name);
      expect(fromMap.code, course.code);
      expect(fromMap.instructor, course.instructor);
      expect(fromMap.color.toARGB32(), course.color.toARGB32());
      expect(fromMap.credits, course.credits);
    });

    test('Course copyWith works accurately', () {
      final course = Course(
        id: 'c1',
        name: 'Calculus I',
        code: 'MATH101',
        instructor: 'Prof. Newton',
        color: const Color(0xFFEA4335),
        credits: 5,
      );

      final updated = course.copyWith(
        name: 'Calculus II',
        code: 'MATH102',
      );

      expect(updated.id, 'c1');
      expect(updated.name, 'Calculus II');
      expect(updated.code, 'MATH102');
      expect(updated.instructor, 'Prof. Newton');
      expect(updated.color, const Color(0xFFEA4335));
      expect(updated.credits, 5);
    });
  });

  group('ScheduleEvent Model Tests', () {
    test('ScheduleEvent toMap and fromMap serialization', () {
      final now = DateTime(2026, 9, 1, 10, 0);
      final event = ScheduleEvent(
        id: 'e1',
        title: 'Lecture',
        courseId: 'c1',
        type: EventType.classType,
        startTime: now,
        endTime: now.add(const Duration(hours: 2)),
        location: 'Hall B',
        daysOfWeek: [1, 3, 5],
        recurring: true,
        notes: 'Bring textbook',
      );

      final map = event.toMap();
      expect(map['id'], 'e1');
      expect(map['title'], 'Lecture');
      expect(map['courseId'], 'c1');
      expect(map['type'], EventType.classType.index);
      expect(map['location'], 'Hall B');
      expect(map['daysOfWeek'], '1,3,5');
      expect(map['recurring'], 1);
      expect(map['notes'], 'Bring textbook');

      final fromMap = ScheduleEvent.fromMap(map);
      expect(fromMap.id, event.id);
      expect(fromMap.title, event.title);
      expect(fromMap.courseId, event.courseId);
      expect(fromMap.type, EventType.classType);
      expect(fromMap.location, 'Hall B');
      expect(fromMap.daysOfWeek, [1, 3, 5]);
      expect(fromMap.recurring, true);
      expect(fromMap.notes, 'Bring textbook');
    });
  });

  group('Assignment Model Tests', () {
    test('Assignment toMap and fromMap serialization', () {
      final dueDate = DateTime(2026, 9, 1, 23, 59);
      final assignment = Assignment(
        id: 'a1',
        courseId: 'c1',
        title: 'Homework 1',
        description: 'Complete questions 1-10',
        dueDate: dueDate,
        isCompleted: false,
        priority: AssignmentPriority.high,
      );

      final map = assignment.toMap();
      expect(map['id'], 'a1');
      expect(map['courseId'], 'c1');
      expect(map['title'], 'Homework 1');
      expect(map['description'], 'Complete questions 1-10');
      expect(map['dueDate'], dueDate.toIso8601String());
      expect(map['isCompleted'], 0);
      expect(map['priority'], AssignmentPriority.high.index);

      final fromMap = Assignment.fromMap(map);
      expect(fromMap.id, assignment.id);
      expect(fromMap.courseId, assignment.courseId);
      expect(fromMap.title, assignment.title);
      expect(fromMap.description, assignment.description);
      expect(fromMap.dueDate, dueDate);
      expect(fromMap.isCompleted, false);
      expect(fromMap.priority, AssignmentPriority.high);
    });

    test('Assignment toggle completion copyWith', () {
      final assignment = Assignment(
        id: 'a1',
        courseId: 'c1',
        title: 'Project Submission',
        description: 'Final report',
        dueDate: DateTime(2026, 9, 5, 12, 0),
        isCompleted: false,
        priority: AssignmentPriority.medium,
      );

      final completed = assignment.copyWith(isCompleted: true);
      expect(completed.isCompleted, true);
      expect(completed.id, assignment.id);
      expect(completed.title, assignment.title);
    });
  });

  group('LocalDbService Cache Management', () {
    test('clearCache resets static database instance without throwing', () async {
      await expectLater(LocalDbService.clearCache(), completes);
    });
  });
}
