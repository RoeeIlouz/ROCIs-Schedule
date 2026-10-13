import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/schedule/widgets/weekly_timetable_grid.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/event_collision_service.dart';
import 'package:rocis_schedule/shared/services/google_calendar_event_builder.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/utils/bidi.dart';
import 'package:rocis_schedule/shared/utils/event_time_format.dart';

/// Holiday from [first] through [last], stored the way the event form does.
ScheduleEvent _holiday(String id, DateTime first, DateTime last) =>
    ScheduleEvent(
      id: id,
      title: id,
      courseId: '',
      type: EventType.other,
      startTime: DateUtils.dateOnly(first),
      endTime: DateTime(last.year, last.month, last.day, 23, 59),
      domain: EventDomain.personal,
      allDay: true,
    );

ScheduleEvent _timed(String id, DateTime start, DateTime end) => ScheduleEvent(
  id: id,
  title: id,
  courseId: '',
  type: EventType.other,
  startTime: start,
  endTime: end,
  domain: EventDomain.personal,
);

final _labels = CalendarEventLabels(
  course: 'Course',
  instructor: 'Instructor',
  type: 'Type',
  credits: 'Credits',
  semester: 'Semester',
  category: 'Category',
  footer: 'Synced',
  typeName: (t) => t.name,
  domainName: (d) => d.name,
);

void main() {
  final l10n = AppLocalizations(const Locale('en'));

  group('Multi-day events', () {
    final holiday = _holiday(
      'Sukkot',
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 14),
    );

    test('cover every day from start through end, and no other', () {
      expect(holiday.isMultiDay, isTrue);
      expect(holiday.spansDays, isTrue);
      expect(holiday.coversDay(DateTime(2026, 10, 11)), isFalse);
      expect(holiday.coversDay(DateTime(2026, 10, 12, 8)), isTrue);
      expect(holiday.coversDay(DateTime(2026, 10, 14, 23)), isTrue);
      expect(holiday.coversDay(DateTime(2026, 10, 15)), isFalse);
    });

    test('a single all-day event spans its day; a timed one does not', () {
      final day = _holiday(
        'Day off',
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 20),
      );
      expect(day.isMultiDay, isFalse);
      expect(day.spansDays, isTrue);
      final lecture = _timed(
        'Lecture',
        DateTime(2026, 10, 20, 9),
        DateTime(2026, 10, 20, 11),
      );
      expect(lecture.spansDays, isFalse);
    });

    test('occursOn uses the whole span for one-time events', () {
      final provider = CourseProvider('test_uid');
      expect(provider.occursOn(holiday, DateTime(2026, 10, 13), {}), isTrue);
      expect(provider.occursOn(holiday, DateTime(2026, 10, 15), {}), isFalse);
    });

    test('allDay round-trips through toMap/fromMap', () {
      final restored = ScheduleEvent.fromMap(holiday.toMap());
      expect(restored.allDay, isTrue);
      expect(restored.endDay, DateTime(2026, 10, 14));
      // Older rows without the column load as timed events.
      expect(
        ScheduleEvent.fromMap(holiday.toMap()..remove('allDay')).allDay,
        isFalse,
      );
    });

    test('day-spanning events never collide with timed ones', () {
      final lecture = _timed(
        'Lecture',
        DateTime(2026, 10, 13, 9),
        DateTime(2026, 10, 13, 11),
      );
      expect(EventCollisionService.doEventsOverlap(holiday, lecture), isFalse);
    });

    test('time labels for all-day, multi-day and overnight events', () {
      expect(
        formatEventTimeRange(
          _holiday('x', DateTime(2026, 10, 20), DateTime(2026, 10, 20)),
          l10n,
          use24HourFormat: true,
        ),
        'All day',
      );
      expect(
        formatEventTimeRange(holiday, l10n, use24HourFormat: true),
        'Oct 12 - Oct 14',
      );
      final overnight = _timed(
        'Shift',
        DateTime(2026, 10, 12, 22),
        DateTime(2026, 10, 13, 2),
      );
      expect(
        formatEventTimeRange(overnight, l10n, use24HourFormat: true),
        'Oct 12, 22:00 - Oct 13, 02:00',
      );
      expect(
        formatDayOfSpan(holiday, DateTime(2026, 10, 13), l10n),
        'Day 2 of 3',
      );
      expect(formatDayOfSpan(holiday, DateTime(2026, 10, 20), l10n), isNull);
    });

    test('week bars stack only when their days overlap', () {
      final week = List.generate(7, (i) => DateTime(2026, 10, 11 + i));
      final rows = layoutSpanRows([
        holiday, // Mon-Wed
        _holiday('Trip', DateTime(2026, 10, 13), DateTime(2026, 10, 16)),
        _holiday('Fri', DateTime(2026, 10, 16), DateTime(2026, 10, 16)),
        // Started last week, ends Sunday: clipped to the first column.
        _holiday('Carry', DateTime(2026, 10, 8), DateTime(2026, 10, 11)),
        _holiday('Elsewhere', DateTime(2026, 11, 1), DateTime(2026, 11, 2)),
      ], week);
      final byId = {for (final r in rows) r.event.id: r};
      expect(byId.containsKey('Elsewhere'), isFalse);
      expect((byId['Carry']!.first, byId['Carry']!.last), (0, 0));
      expect((byId['Sukkot']!.first, byId['Sukkot']!.last), (1, 3));
      expect(byId['Trip']!.row, isNot(byId['Sukkot']!.row));
      expect(byId['Fri']!.row, isNot(byId['Trip']!.row));
    });
  });

  group('Calendar exchange', () {
    test('ICS date-only events import as all-day with an inclusive end', () {
      const ics = '''BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Passover
DTSTART;VALUE=DATE:20260402
DTEND;VALUE=DATE:20260410
END:VEVENT
END:VCALENDAR''';
      final event = IcsImportService.parseIcsContent(ics).events.single;
      expect(event.allDay, isTrue);
      expect(event.startDay, DateTime(2026, 4, 2));
      expect(event.endDay, DateTime(2026, 4, 9));
    });

    test('ICS export writes all-day dates with an exclusive end', () {
      final ics = IcsImportService.exportIcsContent(const [], [
        _holiday('Sukkot', DateTime(2026, 10, 12), DateTime(2026, 10, 14)),
      ]);
      expect(ics, contains('DTSTART;VALUE=DATE:20261012'));
      expect(ics, contains('DTEND;VALUE=DATE:20261015'));
      // Round trip.
      final back = IcsImportService.parseIcsContent(ics).events.single;
      expect((back.allDay, back.endDay), (true, DateTime(2026, 10, 14)));
    });

    test('Google Calendar gets all-day dates and no pre-midnight reminder', () {
      final body = GoogleCalendarEventBuilder.build(
        event: _holiday(
          'Sukkot',
          DateTime(2026, 10, 12),
          DateTime(2026, 10, 14),
        ),
        course: null,
        semester: null,
        timeZone: 'Asia/Jerusalem',
        reminderMinutes: 15,
        labels: _labels,
      );
      expect(body['start'], {'date': '2026-10-12'});
      expect(body['end'], {'date': '2026-10-15'});
      expect((body['reminders'] as Map)['overrides'], isEmpty);
    });
  });

  group('Mixed-direction text', () {
    test('direction follows the first letter that has one', () {
      expect(textDirectionOf('שיעור Math 101'), TextDirection.rtl);
      expect(textDirectionOf('Math 101 עם דני'), TextDirection.ltr);
      expect(textDirectionOf('12:00 - פגישה with Dan'), TextDirection.rtl);
      expect(textDirectionOf('  (בית) home'), TextDirection.rtl);
      expect(textDirectionOf('123 !?'), isNull);
      expect(textDirectionOf(''), isNull);
    });

    testWidgets('BidiText reads in its own direction, aligned to layout', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: BidiText('מבחן ב-Calculus'),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.textDirection, TextDirection.rtl);
      expect(text.textAlign, TextAlign.left);
    });

    testWidgets('text fields switch direction as the user types', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: BidiFieldBuilder(
              controller: controller,
              builder: (context, direction) =>
                  TextField(controller: controller, textDirection: direction),
            ),
          ),
        ),
      );
      TextDirection? direction() =>
          tester.widget<TextField>(find.byType(TextField)).textDirection;

      expect(direction(), TextDirection.ltr);
      await tester.enterText(find.byType(TextField), 'פגישה עם John');
      await tester.pump();
      expect(direction(), TextDirection.rtl);
      await tester.enterText(find.byType(TextField), 'Meeting עם דני');
      await tester.pump();
      expect(direction(), TextDirection.ltr);
    });
  });

  group('Week grid', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpGrid(
      WidgetTester tester,
      List<ScheduleEvent> events,
      DateTime selected,
    ) => tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizationsDelegate()],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: WeeklyTimetableGrid(
              events: events,
              courses: const {},
              selectedDate: selected,
              onDateSelected: (_) {},
              onEventTap: (_, _) {},
              courseProvider: CourseProvider('test_uid'),
            ),
          ),
        ),
      ),
    );

    testWidgets('holidays show once, as a bar above the hours', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpGrid(tester, [
        _holiday('Sukkot', DateTime(2026, 10, 12), DateTime(2026, 10, 14)),
      ], DateTime(2026, 10, 13));
      await tester.pumpAndSettle();

      expect(find.textContaining('Sukkot'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('resting the mouse on an event previews it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final day = DateTime(2026, 10, 13);
      await pumpGrid(tester, [
        ScheduleEvent(
          id: 'm',
          title: 'Meeting',
          courseId: '',
          type: EventType.other,
          startTime: DateTime(2026, 10, 13, 10),
          endTime: DateTime(2026, 10, 13, 11),
          notes: 'Agenda attached',
          domain: EventDomain.work,
        ),
      ], day);
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.textContaining('Meeting')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Agenda attached'), findsNothing); // not instantly

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Agenda attached'), findsOneWidget);

      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.text('Agenda attached'), findsNothing);
    });
  });
}
