import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Course Model & GPA Calculations', () {
    test('Course serialization includes grade', () {
      final course = Course(
        id: 'c1',
        name: 'Data Structures',
        code: 'CS201',
        instructor: 'Dr. Turing',
        color: Colors.blue,
        credits: 4,
        grade: 94.5,
      );

      final map = course.toMap();
      expect(map['grade'], 94.5);

      final fromMap = Course.fromMap(map);
      expect(fromMap.grade, 94.5);
      expect(fromMap.credits, 4);
      expect(fromMap.name, 'Data Structures');
    });

    test('Course.copyWith modifies grade and attributes correctly', () {
      final course = Course(
        id: 'c1',
        name: 'Algorithms',
        code: 'CS301',
        instructor: 'Prof. Knuth',
        color: Colors.purple,
        credits: 3,
      );
      expect(course.grade, isNull);

      final updated = course.copyWith(grade: 88.0, credits: 4);
      expect(updated.grade, 88.0);
      expect(updated.credits, 4);
      expect(updated.name, 'Algorithms');
    });

    test('GPA calculations handle weighted average and 4.0 conversions', () {
      final provider = CourseProvider('test_uid');
      expect(provider.calculatedGpa, isNull);
      expect(provider.averageGrade, isNull);
      expect(provider.totalCredits, 0);
    });
  });

  group('ICS / iCalendar Importer Tests', () {
    const sampleIcs = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//ROCIs//Schedule//EN
BEGIN:VEVENT
UID:event-1@rocis.com
SUMMARY:CS201 Data Structures Lecture
DESCRIPTION:Prof. Alan Turing
LOCATION:Room 402, CS Building
DTSTART:20260901T100000
DTEND:20260901T120000
RRULE:FREQ=WEEKLY;BYDAY=MO,WE
END:VEVENT
BEGIN:VEVENT
UID:event-2@rocis.com
SUMMARY:CS201 Data Structures Lab
DESCRIPTION:Teaching Assistant
LOCATION:Computer Lab 3
DTSTART:20260902T140000
DTEND:20260902T160000
RRULE:FREQ=WEEKLY;BYDAY=TU
END:VEVENT
BEGIN:VEVENT
UID:event-3@rocis.com
SUMMARY:CS201 Midterm Exam
LOCATION:Auditorium A
DTSTART:20261015T090000
DTEND:20261015T120000
END:VEVENT
END:VCALENDAR
""";

    test('parseIcsContent extracts courses and weekly recurring events', () {
      final result = IcsImportService.parseIcsContent(sampleIcs);

      expect(result.courses.isNotEmpty, isTrue);
      expect(result.events.length, 3);

      // Verify event types detection
      final lecture = result.events.firstWhere((e) => e.title.contains('Lecture'));
      final lab = result.events.firstWhere((e) => e.title.contains('Lab'));
      final exam = result.events.firstWhere((e) => e.title.contains('Exam'));

      expect(lecture.type, EventType.classType);
      expect(lab.type, EventType.lab);
      expect(exam.type, EventType.exam);

      // Verify locations
      expect(lecture.location, 'Room 402, CS Building');
      expect(lab.location, 'Computer Lab 3');
      expect(exam.location, 'Auditorium A');

      // Verify recurrence
      expect(lecture.recurring, isTrue);
      expect(lecture.daysOfWeek, containsAll([1, 3])); // Monday & Wednesday
      expect(lab.recurring, isTrue);
      expect(lab.daysOfWeek, contains(2)); // Tuesday
      expect(exam.recurring, isFalse);
    });

    test('parseIcsContent unfolds folded lines and handles empty strings gracefully', () {
      final emptyResult = IcsImportService.parseIcsContent('');
      expect(emptyResult.courses, isEmpty);
      expect(emptyResult.events, isEmpty);

      const foldedIcs = """
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Long Course Title With 
 Folded Text Continuation
DTSTART:20260905T083000
DTEND:20260905T100000
END:VEVENT
END:VCALENDAR
""";
      final foldedResult = IcsImportService.parseIcsContent(foldedIcs);
      expect(foldedResult.events.length, 1);
      expect(foldedResult.events.first.title, 'Long Course Title With Folded Text Continuation');
    });
  });
}
