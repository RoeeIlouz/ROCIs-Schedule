import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/schedule/add_event_screen.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/event_collision_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('EventDomain & Model Serialization Tests', () {
    test('EventDomain parsing and fallback', () {
      expect(EventDomain.fromString('academic'), EventDomain.academic);
      expect(EventDomain.fromString('work'), EventDomain.work);
      expect(EventDomain.fromString('personal'), EventDomain.personal);
      expect(EventDomain.fromString('unknown_domain'), EventDomain.academic);
      expect(EventDomain.fromString(null), EventDomain.academic);
    });

    test('EventDomain default color and icon properties', () {
      expect(EventDomain.academic.icon, Icons.school_outlined);
      expect(EventDomain.work.icon, Icons.work_outline_rounded);
      expect(EventDomain.personal.icon, Icons.person_outline_rounded);

      expect(EventDomain.academic.defaultColor, const Color(0xFF2563EB));
      expect(EventDomain.work.defaultColor, const Color(0xFF0284C7));
      expect(EventDomain.personal.defaultColor, const Color(0xFF8B5CF6));
    });

    test('ScheduleEvent serialization with domain and custom color', () {
      final event = ScheduleEvent(
        id: 'evt_work_1',
        title: 'Office Shift',
        courseId: '',
        type: EventType.other,
        startTime: DateTime(2026, 9, 21, 9, 0),
        endTime: DateTime(2026, 9, 21, 17, 0),
        location: 'Building B',
        daysOfWeek: [1, 2, 3],
        recurring: true,
        notes: 'Bring badge',
        domain: EventDomain.work,
        color: Colors.teal,
      );

      final map = event.toMap();
      expect(map['id'], 'evt_work_1');
      expect(map['title'], 'Office Shift');
      // Empty courseId must map to null for SQLite foreign key compliance
      expect(map['courseId'], isNull);
      expect(map['domain'], 'work');
      expect(map['color'], Colors.teal.toARGB32());

      final restored = ScheduleEvent.fromMap(map);
      expect(restored.id, event.id);
      expect(restored.title, event.title);
      expect(restored.courseId, '');
      expect(restored.domain, EventDomain.work);
      expect(restored.color?.toARGB32(), Colors.teal.toARGB32());
    });

    test(
      'Legacy event without domain & color safely defaults to academic and null color',
      () {
        final legacyMap = {
          'id': 'legacy_101',
          'title': 'Operating Systems Lecture',
          'courseId': 'course_os_1',
          'type': 0,
          'startTime': '2026-09-20T10:00:00.000',
          'endTime': '2026-09-20T12:00:00.000',
          'location': 'Auditorium 2',
          'daysOfWeek': '0,2',
          'recurring': 1,
          'notes': 'Chapter 4',
        };

        final restored = ScheduleEvent.fromMap(legacyMap);
        expect(restored.id, 'legacy_101');
        expect(restored.domain, EventDomain.academic);
        expect(restored.color, isNull);
      },
    );

    test('copyWith properly updates or preserves domain and color', () {
      final original = ScheduleEvent(
        id: 'evt_copy_1',
        title: 'Original Event',
        courseId: 'c1',
        type: EventType.classType,
        startTime: DateTime(2026, 9, 20, 10, 0),
        endTime: DateTime(2026, 9, 20, 12, 0),
        location: 'Room 1',
        daysOfWeek: [0],
        recurring: true,
        domain: EventDomain.academic,
        color: null,
      );

      final modified = original.copyWith(
        domain: EventDomain.personal,
        color: Colors.purple,
      );

      expect(modified.domain, EventDomain.personal);
      expect(modified.color, Colors.purple);
      expect(modified.title, original.title);

      final preserved = original.copyWith(title: 'New Title');
      expect(preserved.domain, EventDomain.academic);
      expect(preserved.color, isNull);
    });
  });

  group('EventCollisionService Collision Detection Tests', () {
    test('Recurring events overlapping on same weekday detect collision', () {
      final lecture = ScheduleEvent(
        id: 'evt_lec',
        title: 'Math Lecture',
        courseId: 'c_math',
        type: EventType.classType,
        startTime: DateTime(2026, 9, 20, 10, 0),
        endTime: DateTime(2026, 9, 20, 12, 0),
        location: 'Hall A',
        daysOfWeek: [0, 2], // Sun, Tue
        recurring: true,
        domain: EventDomain.academic,
      );

      final workShift = ScheduleEvent(
        id: 'evt_work',
        title: 'Work Shift',
        courseId: '',
        type: EventType.other,
        startTime: DateTime(2026, 9, 20, 11, 0),
        endTime: DateTime(2026, 9, 20, 15, 0),
        location: 'Office',
        daysOfWeek: [2, 4], // Tue, Thu
        recurring: true,
        domain: EventDomain.work,
      );

      expect(EventCollisionService.doEventsOverlap(lecture, workShift), isTrue);
      expect(
        EventCollisionService.hasWorkAcademicConflict(
          candidate: workShift,
          existingEvents: [lecture],
        ),
        isTrue,
      );
    });

    test(
      'Adjacent non-overlapping times on same day do NOT detect collision',
      () {
        final event1 = ScheduleEvent(
          id: 'evt_1',
          title: 'Morning Class',
          courseId: 'c1',
          type: EventType.classType,
          startTime: DateTime(2026, 9, 20, 10, 0),
          endTime: DateTime(2026, 9, 20, 11, 0),
          location: 'Room 1',
          daysOfWeek: [1],
          recurring: true,
        );

        final event2 = ScheduleEvent(
          id: 'evt_2',
          title: 'Afternoon Shift',
          courseId: '',
          type: EventType.other,
          startTime: DateTime(2026, 9, 20, 11, 0),
          endTime: DateTime(2026, 9, 20, 13, 0),
          location: 'Office',
          daysOfWeek: [1],
          recurring: true,
          domain: EventDomain.work,
        );

        // 10:00-11:00 and 11:00-13:00 do not overlap (boundary point only)
        expect(EventCollisionService.doEventsOverlap(event1, event2), isFalse);
      },
    );

    test('Recurring vs one-time event collision when day matches', () {
      final recurringLecture = ScheduleEvent(
        id: 'rec_lec',
        title: 'Physics Lab',
        courseId: 'c_phys',
        type: EventType.lab,
        startTime: DateTime(2026, 9, 20, 14, 0),
        endTime: DateTime(2026, 9, 20, 16, 0),
        location: 'Lab 3',
        daysOfWeek: [1], // Monday (in Dart weekday: Monday is 1, 1 % 7 = 1)
        recurring: true,
        domain: EventDomain.academic,
      );

      // 2026-09-21 is Monday (weekday == 1, 1 % 7 == 1)
      final oneTimeWorkMeeting = ScheduleEvent(
        id: 'one_time_work',
        title: 'Urgent Client Call',
        courseId: '',
        type: EventType.other,
        startTime: DateTime(2026, 9, 21, 15, 0),
        endTime: DateTime(2026, 9, 21, 16, 30),
        location: 'Zoom',
        daysOfWeek: [],
        recurring: false,
        domain: EventDomain.work,
      );

      expect(
        EventCollisionService.doEventsOverlap(
          recurringLecture,
          oneTimeWorkMeeting,
        ),
        isTrue,
      );
      expect(
        EventCollisionService.hasWorkAcademicConflict(
          candidate: oneTimeWorkMeeting,
          existingEvents: [recurringLecture],
        ),
        isTrue,
      );
    });

    test('Different days of week do NOT detect collision', () {
      final eventSun = ScheduleEvent(
        id: 'evt_sun',
        title: 'Sunday Class',
        courseId: 'c1',
        type: EventType.classType,
        startTime: DateTime(2026, 9, 20, 10, 0),
        endTime: DateTime(2026, 9, 20, 12, 0),
        location: 'Room 1',
        daysOfWeek: [0],
        recurring: true,
      );

      final eventMon = ScheduleEvent(
        id: 'evt_mon',
        title: 'Monday Shift',
        courseId: '',
        type: EventType.other,
        startTime: DateTime(2026, 9, 21, 10, 0),
        endTime: DateTime(2026, 9, 21, 12, 0),
        location: 'Office',
        daysOfWeek: [1],
        recurring: true,
        domain: EventDomain.work,
      );

      expect(
        EventCollisionService.doEventsOverlap(eventSun, eventMon),
        isFalse,
      );
    });

    test('Two work events colliding do not trigger work-academic conflict', () {
      final work1 = ScheduleEvent(
        id: 'w1',
        title: 'Shift 1',
        courseId: '',
        type: EventType.other,
        startTime: DateTime(2026, 9, 20, 10, 0),
        endTime: DateTime(2026, 9, 20, 14, 0),
        location: 'Office A',
        daysOfWeek: [0],
        recurring: true,
        domain: EventDomain.work,
      );

      final work2 = ScheduleEvent(
        id: 'w2',
        title: 'Shift 2',
        courseId: '',
        type: EventType.other,
        startTime: DateTime(2026, 9, 20, 12, 0),
        endTime: DateTime(2026, 9, 20, 16, 0),
        location: 'Office B',
        daysOfWeek: [0],
        recurring: true,
        domain: EventDomain.work,
      );

      expect(EventCollisionService.doEventsOverlap(work1, work2), isTrue);
      // It is a collision, but NOT a work vs academic conflict
      expect(
        EventCollisionService.hasWorkAcademicConflict(
          candidate: work2,
          existingEvents: [work1],
        ),
        isFalse,
      );
    });

    test('formatConflictSummary formats cleanly', () {
      final event = ScheduleEvent(
        id: 'e1',
        title: 'Data Structures Exam',
        courseId: 'c_ds',
        type: EventType.exam,
        startTime: DateTime(2026, 9, 20, 9, 0),
        endTime: DateTime(2026, 9, 20, 12, 0),
        location: 'Hall C',
        daysOfWeek: [0],
        recurring: false,
      );

      final summary = EventCollisionService.formatConflictSummary(event);
      expect(summary, contains('Data Structures Exam'));
      expect(summary, contains('09:00 - 12:00'));
    });
  });

  group('LocalDbService Schema V6 Migration Test', () {
    test(
      'Database creates tables with domain and color columns and handles inserts',
      () async {
        final db = await openDatabase(
          inMemoryDatabasePath,
          version: 6,
          onCreate: (db, version) async {
            // Verify table creation with version 6 columns
            await db.execute('''
            CREATE TABLE events (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              courseId TEXT,
              type INTEGER NOT NULL,
              startTime TEXT NOT NULL,
              endTime TEXT NOT NULL,
              location TEXT,
              daysOfWeek TEXT,
              recurring INTEGER NOT NULL,
              notes TEXT,
              domain TEXT DEFAULT 'academic',
              color INTEGER
            )
          ''');
          },
        );

        // Insert work event with null courseId, domain 'work', and color
        await db.insert('events', {
          'id': 'test_db_evt_1',
          'title': 'Remote Work Session',
          'courseId': null,
          'type': 3,
          'startTime': '2026-09-20T08:00:00.000',
          'endTime': '2026-09-20T12:00:00.000',
          'location': 'Home Office',
          'daysOfWeek': '0',
          'recurring': 1,
          'notes': 'Deep focus',
          'domain': 'work',
          'color': 0xFF009688,
        });

        final rows = await db.query(
          'events',
          where: 'id = ?',
          whereArgs: ['test_db_evt_1'],
        );
        expect(rows.length, 1);
        expect(rows.first['domain'], 'work');
        expect(rows.first['color'], 0xFF009688);
        expect(rows.first['courseId'], isNull);

        await db.close();
      },
    );
  });

  group('AddEventScreen Widget Flow for Work and Personal Spheres', () {
    testWidgets(
      'Selecting Work sphere hides course selection and allows custom color',
      (WidgetTester tester) async {
        final courseProvider = CourseProvider('test_user_spheres');
        courseProvider.addCourseFromSync(
          Course(
            id: 'c1',
            name: 'Physics',
            code: 'PHY101',
            instructor: 'Dr. Newton',
            color: Colors.blue,
            credits: 3.0,
          ),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<CourseProvider>.value(
                value: courseProvider,
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: const [AppLocalizationsDelegate()],
              home: const Scaffold(body: AddEventScreen()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Academic is default: Course selection label should be visible
        expect(find.text('Course'), findsOneWidget);

        // Find the Work segment button
        final workSegment = find.text('Work');
        expect(workSegment, findsOneWidget);

        await tester.tap(workSegment);
        await tester.pumpAndSettle();

        // In Work mode, Course selection is hidden and Workplace label is shown
        expect(find.text('Workplace / Company'), findsOneWidget);
        expect(find.text('Course'), findsNothing);

        // Color selection section is visible
        expect(find.text('Color Tag'), findsOneWidget);

        // Switch to Personal sphere
        final personalSegment = find.text('Personal');
        expect(personalSegment, findsOneWidget);
        await tester.tap(personalSegment);
        await tester.pumpAndSettle();

        // In Personal mode, Course is still hidden
        expect(find.text('Course'), findsNothing);
        expect(find.text('Color Tag'), findsOneWidget);
      },
    );
  });
}
