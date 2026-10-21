import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rocis_schedule/features/courses/services/course_notes_pdf_service.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

Course _course({String name = 'Calculus 2', String instructor = 'Dr. Levi'}) =>
    Course(
      id: 'c1',
      name: name,
      code: 'MATH201',
      instructor: instructor,
      color: Colors.indigo,
      credits: 4,
    );

ScheduleEvent _event({
  List<int> days = const [1, 3],
  bool recurring = true,
  String location = 'Room 4',
}) =>
    ScheduleEvent(
      id: 'e1',
      title: 'Lecture',
      courseId: 'c1',
      type: EventType.classType,
      startTime: DateTime(2026, 1, 5, 10),
      endTime: DateTime(2026, 1, 5, 11, 30),
      location: location,
      daysOfWeek: days,
      recurring: recurring,
    );

int _pageCount(List<int> pdf) =>
    RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(pdf)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('he');
  });

  group('CourseNotesPdfService.meetingLines', () {
    test('formats recurring events with days, time range and room', () {
      final lines = CourseNotesPdfService.meetingLines([_event()], 'en');
      expect(lines, ['Mon · Wed  10:00-11:30 · Room 4']);
    });

    test('skips one-off events and de-duplicates identical meetings', () {
      final lines = CourseNotesPdfService.meetingLines(
        [_event(), _event(), _event(recurring: false), _event(days: [])],
        'en',
      );
      expect(lines.length, 1);
    });

    test('omits the room separator when location is empty', () {
      final lines = CourseNotesPdfService.meetingLines(
        [_event(location: ' ')],
        'en',
      );
      expect(lines.single, 'Mon · Wed  10:00-11:30');
    });
  });

  group('CourseNotesPdfService.fileNameFor', () {
    test('strips characters that break share targets', () {
      expect(
        CourseNotesPdfService.fileNameFor(_course(name: 'A/B: C?*')),
        'A_B_ C__.pdf',
      );
    });

    test('falls back when the name is blank', () {
      expect(CourseNotesPdfService.fileNameFor(_course(name: '  ')), 'notes.pdf');
    });
  });

  group('CourseNotesPdfService.buildPdf', () {
    Future<List<int>> build(
      WidgetTester t, {
      required Course course,
      int pages = 3,
      NotesPaperStyle paper = NotesPaperStyle.ruled,
      TextDirection dir = TextDirection.ltr,
      String locale = 'en',
    }) async {
      final bytes = await t.runAsync(
        () => CourseNotesPdfService().buildPdf(
          course: course,
          events: [_event()],
          instructorLabel: 'Instructor',
          scheduleLabel: 'Schedule',
          localeCode: locale,
          textDirection: dir,
          pageCount: pages,
          paper: paper,
        ),
      );
      return bytes!;
    }

    testWidgets('produces a PDF with a cover plus the requested pages', (t) async {
      final pdf = await build(t, course: _course(), pages: 3);
      expect(latin1.decode(pdf.sublist(0, 5)), '%PDF-');
      expect(_pageCount(pdf), 4);
    });

    testWidgets('grid paper and RTL Hebrew cover build without error', (t) async {
      final pdf = await build(
        t,
        course: _course(name: 'חשבון דיפרנציאלי', instructor: 'ד"ר לוי'),
        pages: 2,
        paper: NotesPaperStyle.grid,
        dir: TextDirection.rtl,
        locale: 'he',
      );
      expect(_pageCount(pdf), 3);
    });
  });
}
