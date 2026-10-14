import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/courses/services/ocr_timetable_parser.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

void main() {
  group('OcrTimetableParser Tests', () {
    test('parses English course syllabus format with days and times', () {
      const sampleText = '''
Fall Semester 2026 Timetable
CS101 - Introduction to Computer Science
Monday 10:00 - 12:00 Room Taub 201
Wednesday 14:00 - 16:00 Lab 3

MATH201 - Linear Algebra
Tuesday 08:30 - 10:00 Auditorium A
Thursday 08:30 - 10:00 Auditorium A
''';

      final result = OcrTimetableParser.parseText(sampleText);
      expect(result.drafts.length, greaterThanOrEqualTo(2));

      final csDraft = result.drafts.firstWhere(
        (d) => d.course.name.contains('Computer Science') || d.course.name.contains('CS101'),
      );
      expect(csDraft.events.length, equals(2));
      expect(csDraft.events[0].daysOfWeek, contains(1)); // Monday
      expect(csDraft.events[0].startTime.hour, equals(10));
      expect(csDraft.events[0].endTime.hour, equals(12));
      expect(csDraft.events[1].daysOfWeek, contains(3)); // Wednesday
      expect(csDraft.events[1].type, equals(EventType.lab));

      final mathDraft = result.drafts.firstWhere(
        (d) => d.course.name.contains('Linear Algebra') || d.course.name.contains('MATH201'),
      );
      expect(mathDraft.events.length, equals(2));
      expect(mathDraft.events[0].daysOfWeek, contains(2)); // Tuesday
      expect(mathDraft.events[0].startTime.hour, equals(8));
      expect(mathDraft.events[0].startTime.minute, equals(30));
    });

    test('parses Hebrew university schedule text', () {
      const hebrewSchedule = '''
מערכת שעות סמסטר א
חדו"א 1 (011110)
יום א 08:30 - 10:30 חדר 101
יום ג 10:30 - 12:30 כיתה 204
מעבדה בפיזיקה
יום ה 14:00 - 17:00 מעבדה 3
''';

      final result = OcrTimetableParser.parseText(hebrewSchedule);
      expect(result.drafts.isNotEmpty, isTrue);

      final calcDraft = result.drafts.firstWhere(
        (d) => d.course.name.contains('חדו'),
      );
      expect(calcDraft.events.length, equals(2));
      expect(calcDraft.events[0].daysOfWeek, contains(0)); // Sunday
      expect(calcDraft.events[0].startTime.hour, equals(8));
      expect(calcDraft.events[0].startTime.minute, equals(30));
      expect(calcDraft.events[1].daysOfWeek, contains(2)); // Tuesday

      final physicsDraft = result.drafts.firstWhere(
        (d) => d.course.name.contains('פיזיקה'),
      );
      expect(physicsDraft.events[0].daysOfWeek, contains(4)); // Thursday
      expect(physicsDraft.events[0].type, equals(EventType.lab));
    });

    test('handles 12-hour AM/PM format correctly', () {
      const ampmText = '''
Macroeconomics
Monday 01:30 PM - 03:00 PM Room 402
''';

      final result = OcrTimetableParser.parseText(ampmText);
      expect(result.drafts.length, equals(1));
      final draft = result.drafts.first;
      expect(draft.events[0].startTime.hour, equals(13));
      expect(draft.events[0].startTime.minute, equals(30));
      expect(draft.events[0].endTime.hour, equals(15));
      expect(draft.events[0].endTime.minute, equals(0));
    });
  });
}
