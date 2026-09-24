import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';

void main() {
  final course = Course(
    id: 'c1',
    name: 'Linear Algebra',
    code: '90905',
    instructor: '',
    color: const Color(0xFF1E88E5),
    credits: 5,
    semester: 'semester_1',
  );

  // Created on Sunday Sep 20, 2026; recurs on Sundays (0).
  final sundayClass = ScheduleEvent(
    id: 'e1',
    title: 'Practice',
    courseId: 'c1',
    type: EventType.classType,
    startTime: DateTime(2026, 9, 20, 12),
    endTime: DateTime(2026, 9, 20, 13, 50),
    location: 'Room 1',
    daysOfWeek: const [0],
    recurring: true,
    notes: 'Bring: calculator, notebook; laptop\nOptional',
  );

  final semester1 = Semester(
    id: 'semester_1',
    name: 'First Semester',
    startDate: DateTime(2026, 10, 25),
    endDate: DateTime(2027, 2, 5),
  );

  group('ICS export', () {
    test('recurring classes start at the semester start, not creation', () {
      final ics = IcsImportService.exportIcsContent(
        [course],
        [sundayClass],
        semesters: [semester1],
      );

      expect(ics, contains('DTSTART:20261025T120000'));
      expect(ics, contains('DTEND:20261025T135000'));
      expect(ics, contains('RRULE:FREQ=WEEKLY;BYDAY=SU;UNTIL=20270205T235959'));
      expect(ics, isNot(contains('20260920')));
    });

    test('first class lands on the next matching weekday', () {
      // Semester starts Sunday Oct 25; a Wednesday (3) class starts Oct 28.
      final start = IcsImportService.firstOccurrenceFrom(
        ScheduleEvent(
          id: 'e2',
          title: 'Lab',
          courseId: 'c1',
          type: EventType.classType,
          startTime: DateTime(2026, 9, 20, 14),
          endTime: DateTime(2026, 9, 20, 16),
          location: '',
          daysOfWeek: const [3],
          recurring: true,
          notes: '',
        ),
        DateTime(2026, 10, 25),
      );

      expect(start, DateTime(2026, 10, 28, 14));
    });

    test('without semester dates the event keeps its own start', () {
      final ics = IcsImportService.exportIcsContent([course], [sundayClass]);

      expect(ics, contains('DTSTART:20260920T120000'));
      expect(ics, contains('RRULE:FREQ=WEEKLY;BYDAY=SU\n'));
    });

    test('text values are escaped per RFC 5545', () {
      final ics = IcsImportService.exportIcsContent([course], [sundayClass]);

      expect(
        ics,
        contains(
          r'DESCRIPTION:Bring: calculator\, notebook\; laptop\nOptional',
        ),
      );
      expect(IcsImportService.escapeIcsText(r'a\b'), r'a\\b');
    });
  });
}
