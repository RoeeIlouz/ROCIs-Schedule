import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/schedule/add_event_screen.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';

Course _course(String id, String name, String? semester) => Course(
  id: id,
  name: name,
  code: id,
  instructor: '',
  color: Colors.indigo,
  credits: 3,
  semester: semester,
);

ScheduleEvent _class(String id, String courseId, String location) =>
    ScheduleEvent(
      id: id,
      title: id,
      courseId: courseId,
      type: EventType.classType,
      startTime: DateTime(2026, 10, 4, 9),
      endTime: DateTime(2026, 10, 4, 10),
      location: location,
    );

Future<CourseProvider> _provider() async {
  final provider = CourseProvider('test_semester_places');
  await provider.applyRemoteSemesters([
    Semester(
      id: 'semester_1',
      name: 'First Semester',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2027, 1, 31),
    ),
    Semester(
      id: 'semester_2',
      name: 'Second Semester',
      startDate: DateTime(2027, 3, 1),
      endDate: DateTime(2027, 6, 30),
    ),
    const Semester(id: 'semester_summer', name: 'Summer Semester'),
  ], const []);
  await provider.applyRemoteCourses([
    _course('alg', 'Algorithms', 'semester_1'),
    _course('old', 'Legacy course', null), // counts as the first semester
    _course('os', 'Operating Systems', 'semester_2'),
  ], const []);
  await provider.applyRemoteEvents([
    _class('e1', 'alg', 'Hall B'),
    _class('e2', 'alg', 'Hall B'),
    _class('e3', 'os', 'Lab 3'),
    _class('e4', 'os', 'Lab 3'),
    _class('e5', 'os', 'lab 3'), // same place, different case
    _class('e6', 'os', 'Library'),
  ], const []);
  return provider;
}

void main() {
  group('Semesters for the event form', () {
    test('only semesters with courses are offered, in order', () async {
      final provider = await _provider();
      expect(provider.semestersWithCourses.map((s) => s.id), [
        'semester_1',
        'semester_2',
      ]);
    });

    test('the semester is found from a date within its range', () async {
      final provider = await _provider();
      expect(provider.semesterOn(DateTime(2026, 11, 2))?.id, 'semester_1');
      expect(provider.semesterOn(DateTime(2027, 4, 2))?.id, 'semester_2');
      expect(provider.semesterOn(DateTime(2027, 2, 15)), isNull);
    });
  });

  group('Location suggestions', () {
    test('this course\'s places first, then the most used', () async {
      final provider = await _provider();
      expect(provider.locationSuggestions(courseId: 'alg'), [
        'Hall B',
        'Lab 3',
        'Library',
      ]);
      expect(provider.locationSuggestions(courseId: 'os'), [
        'Lab 3',
        'Library',
        'Hall B',
      ]);
    });

    test(
      'typing narrows the list; a finished place is not suggested',
      () async {
        final provider = await _provider();
        expect(provider.locationSuggestions(query: 'li'), ['Library']);
        expect(provider.locationSuggestions(query: 'HALL'), ['Hall B']);
        expect(provider.locationSuggestions(query: 'hall b'), isEmpty);
      },
    );
  });

  group('Add event form', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pumpForm(WidgetTester tester, CourseProvider provider) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CourseProvider>.value(value: provider),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [AppLocalizationsDelegate()],
            home: AddEventScreen(initialStart: DateTime(2026, 11, 2, 10)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('semester comes first and limits the course list', (
      tester,
    ) async {
      await pumpForm(tester, await _provider());

      // The event's date falls in the first semester.
      expect(find.text('Semester'), findsOneWidget);
      expect(find.text('First Semester'), findsOneWidget);
      expect(find.text('Algorithms'), findsOneWidget);

      await tester.tap(find.text('Algorithms'));
      await tester.pumpAndSettle();
      expect(find.text('Legacy course'), findsWidgets);
      expect(find.text('Operating Systems'), findsNothing);
      await tester.tap(find.text('Legacy course').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('First Semester'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second Semester').last);
      await tester.pumpAndSettle();

      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.text('Legacy course'), findsNothing);
      expect(find.text('Algorithms'), findsNothing);
    });

    testWidgets('the location field suggests earlier places', (tester) async {
      await pumpForm(tester, await _provider());

      final location = find.widgetWithText(
        TextFormField,
        'Building, room number, or Zoom link',
      );
      await tester.ensureVisible(location);
      await tester.enterText(location, 'li');
      await tester.pumpAndSettle();
      expect(find.text('Library'), findsOneWidget);

      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(location).controller?.text,
        'Library',
      );
    });
  });
}
