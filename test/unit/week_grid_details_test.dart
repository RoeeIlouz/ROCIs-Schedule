import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/schedule/widgets/weekly_timetable_grid.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';

Course _course({String? icon}) => Course(
  id: 'c1',
  name: 'Algorithms',
  code: 'CS201',
  instructor: 'Dr. Turing',
  color: Colors.teal,
  credits: 4,
  icon: icon,
);

ScheduleEvent _event(
  String id,
  DateTime day,
  int startHour,
  int endHour, {
  EventType type = EventType.classType,
  EventDomain domain = EventDomain.academic,
  String location = '',
  String notes = '',
}) => ScheduleEvent(
  id: id,
  courseId: domain == EventDomain.academic ? 'c1' : '',
  title: id,
  type: type,
  startTime: DateTime(day.year, day.month, day.day, startHour),
  endTime: DateTime(day.year, day.month, day.day, endHour),
  location: location,
  notes: notes,
  domain: domain,
);

void main() {
  group('Course icon', () {
    test('round-trips through toMap/fromMap', () {
      final course = Course.fromMap(_course(icon: 'science').toMap());
      expect(course.icon, 'science');
      expect(course.iconData, Icons.science_outlined);
    });

    test('unknown or missing keys fall back to no icon', () {
      expect(Course.fromMap({..._course().toMap(), 'icon': 'nope'}).icon, null);
      expect(Course.fromMap(_course().toMap()..remove('icon')).icon, null);
    });

    test('copyWith keeps, replaces and clears the icon', () {
      final course = _course(icon: 'code');
      expect(course.copyWith(name: 'x').icon, 'code');
      expect(course.copyWith(icon: 'music').icon, 'music');
      expect(course.copyWith(clearIcon: true).icon, null);
    });

    test('events use the course icon, else the type or domain icon', () {
      final day = DateTime(2026, 10, 4);
      final lab = _event('lab', day, 9, 10, type: EventType.lab);
      expect(lab.iconFor(_course(icon: 'code')), Icons.code_rounded);
      expect(lab.iconFor(_course()), Icons.science_outlined);
      expect(lab.iconFor(null), Icons.science_outlined);
      final work = _event('w', day, 9, 10, domain: EventDomain.work);
      expect(work.iconFor(_course(icon: 'code')), EventDomain.work.icon);
    });
  });

  group('Compact week grid', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpGrid(WidgetTester tester, List<ScheduleEvent> events) {
      final courses = {'c1': _course(icon: 'calculate')};
      return tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
          child: MaterialApp(
            localizationsDelegates: const [AppLocalizationsDelegate()],
            supportedLocales: const [Locale('en')],
            home: Scaffold(
              body: WeeklyTimetableGrid(
                events: events,
                courses: courses,
                selectedDate: DateTime.now(),
                onDateSelected: (_) {},
                onEventTap: (_, _) {},
                courseProvider: CourseProvider('test_uid'),
                compact: true,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('tall blocks show start time and location, short ones not', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = DateTime.now();
      await pumpGrid(tester, [
        _event('Long', today, 9, 11, location: 'Hall B'),
        _event('Short', today, 13, 14, location: 'Room 7'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('09:00'), findsWidgets); // block time + axis label
      expect(find.text('Hall B'), findsOneWidget);
      expect(find.text('Room 7'), findsNothing);
      expect(find.byIcon(Icons.calculate_outlined), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('press and hold previews the event until released', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = DateTime.now();
      await pumpGrid(tester, [
        _event(
          'Seminar',
          today,
          10,
          11,
          location: 'Hall C',
          notes: 'Bring laptop',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Bring laptop'), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.textContaining('Seminar')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Bring laptop'), findsOneWidget);
      expect(find.text('Hall C'), findsOneWidget);
      expect(find.text('Algorithms · Class'), findsOneWidget);
      expect(find.text('Dr. Turing'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('Bring laptop'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
