import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/schedule_widget_service.dart';

void main() {
  group('ScheduleWidgetService findNextUpcomingOccurrence', () {
    final course1 = Course(
      id: 'course_101',
      name: 'Algorithms',
      code: 'CS101',
      instructor: 'Dr. Turing',
      color: const Color(0xFF4F46E5),
      credits: 4.0,
    );
    final course2 = Course(
      id: 'course_102',
      name: 'Linear Algebra',
      code: 'MATH102',
      instructor: 'Prof. Gauss',
      color: const Color(0xFF10B981),
      credits: 3.5,
    );

    final courses = {
      course1.id: course1,
      course2.id: course2,
    };

    // Reference now: Monday, 2026-10-19 at 10:00 AM (weekday 1)
    final mondayMorning = DateTime(2026, 10, 19, 10, 0);

    test('picks upcoming recurring event today that ends after now', () {
      final morningClass = ScheduleEvent(
        id: 'event_morning',
        title: 'Lecture',
        courseId: 'course_101',
        type: EventType.classType,
        startTime: DateTime(2026, 10, 19, 8, 30),
        endTime: DateTime(2026, 10, 19, 9, 30),
        recurring: true,
        daysOfWeek: const [1], // Monday
      );

      final upcomingClass = ScheduleEvent(
        id: 'event_upcoming',
        title: 'Algorithms Tutorial',
        courseId: 'course_101',
        type: EventType.classType,
        startTime: DateTime(2026, 10, 19, 11, 0),
        endTime: DateTime(2026, 10, 19, 12, 30),
        recurring: true,
        daysOfWeek: const [1], // Monday
      );

      final next = ScheduleWidgetService.findNextUpcomingOccurrence(
        [morningClass, upcomingClass],
        courses,
        mondayMorning,
      );

      expect(next, isNotNull);
      expect(next!.event.id, 'event_upcoming');
      expect(next.isTomorrow, isFalse);
      expect(next.startTime.hour, 11);
      expect(next.startTime.minute, 0);
    });

    test('picks non-recurring exam scheduled today', () {
      final exam = ScheduleEvent(
        id: 'exam_today',
        title: 'Midterm Exam',
        courseId: 'course_102',
        type: EventType.exam,
        startTime: DateTime(2026, 10, 19, 14, 0),
        endTime: DateTime(2026, 10, 19, 16, 0),
        recurring: false,
      );

      final next = ScheduleWidgetService.findNextUpcomingOccurrence(
        [exam],
        courses,
        mondayMorning,
      );

      expect(next, isNotNull);
      expect(next!.event.id, 'exam_today');
      expect(next.event.type, EventType.exam);
      expect(next.isTomorrow, isFalse);
    });

    test('picks tomorrow morning class when all events today have passed', () {
      final pastClass = ScheduleEvent(
        id: 'past_event',
        title: 'Morning Lab',
        courseId: 'course_101',
        type: EventType.lab,
        startTime: DateTime(2026, 10, 19, 8, 0),
        endTime: DateTime(2026, 10, 19, 9, 30),
        recurring: true,
        daysOfWeek: const [1], // Monday
      );

      final tuesdayClass = ScheduleEvent(
        id: 'tuesday_event',
        title: 'Linear Algebra Lecture',
        courseId: 'course_102',
        type: EventType.classType,
        startTime: DateTime(2026, 10, 19, 9, 0),
        endTime: DateTime(2026, 10, 19, 10, 30),
        recurring: true,
        daysOfWeek: const [2], // Tuesday (2026-10-20)
      );

      final next = ScheduleWidgetService.findNextUpcomingOccurrence(
        [pastClass, tuesdayClass],
        courses,
        mondayMorning,
      );

      expect(next, isNotNull);
      expect(next!.event.id, 'tuesday_event');
      expect(next.isTomorrow, isTrue);
      expect(next.startTime.day, 20);
      expect(next.startTime.hour, 9);
    });

    test('returns null when no events exist today or tomorrow', () {
      final fridayClass = ScheduleEvent(
        id: 'friday_event',
        title: 'Seminar',
        courseId: 'course_101',
        type: EventType.classType,
        startTime: DateTime(2026, 10, 19, 10, 0),
        endTime: DateTime(2026, 10, 19, 12, 0),
        recurring: true,
        daysOfWeek: const [5], // Friday only
      );

      final next = ScheduleWidgetService.findNextUpcomingOccurrence(
        [fridayClass],
        courses,
        mondayMorning,
      );

      expect(next, isNull);
    });
  });
}
