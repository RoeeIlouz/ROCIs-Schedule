import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';
import 'package:rocis_schedule/features/calendar_sync/services/calendar_sync_service.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_store.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

FeedEntry lecture(
  String course,
  DateTime start, {
  String lecturer = 'מר א',
  String location = '101',
  String desc = 'סוג מפגש: הרצאה',
  bool cancelled = false,
}) => FeedEntry(
  uid: 'u',
  summary: '$course $lecturer${cancelled ? ' ** השיעור מבוטל **' : ''}',
  description: desc,
  location: location,
  start: start,
  end: start.add(const Duration(hours: 2)),
);

Future<CourseProvider> freshProvider(String uid) async {
  await LocalDbService.clearCache();
  final db = await LocalDbService(uid).database;
  if (db != null) {
    await db.delete('events');
    await db.delete('courses');
  }
  final p = CourseProvider(uid);
  await p.loadData();
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final mon = DateTime(2026, 11, 9, 9);

  test(
    'matches an existing course by normalized name and keeps its data',
    () async {
      final p = await freshProvider('cs_match');
      await p.addCourse(
        Course(
          id: 'mine',
          name: '‏אלגברה ליניארית',
          code: 'X1',
          instructor: 'i',
          color: const Color(0xFF123456),
          credits: 4,
          grade: 90,
        ),
      );
      final svc = CalendarSyncService(p, SyncStore());
      await svc.applyEntries('afeka', [lecture('אלגברה ליניארית', mon)]);
      expect(p.courses, hasLength(1));
      expect(p.courses.single.color, const Color(0xFF123456));
      expect(p.courses.single.grade, 90);
      expect(p.events.single.courseId, 'mine');
    },
  );

  Course mine(String id, String name) => Course(
    id: id,
    name: name,
    code: 'C',
    instructor: 'My Lecturer',
    color: const Color(0xFF222222),
    credits: 5,
    grade: 80,
  );

  test(
    'a partial name match joins the existing course, nothing created',
    () async {
      final p = await freshProvider('cs_fuzzy');
      await p.addCourse(mine('alg', 'אלגברה'));
      await CalendarSyncService(
        p,
        SyncStore(),
        autoCreateCourses: false,
      ).applyEntries('afeka', [lecture('אלגברה ליניארית', mon)]);
      expect(p.courses, hasLength(1));
      final c = p.courses.single;
      expect(
        [c.name, c.instructor, c.credits, c.grade],
        ['אלגברה', 'My Lecturer', 5, 80],
      );
      expect(p.events.single.courseId, 'alg');
    },
  );

  test(
    'ambiguous or missing matches wait for the user, nothing is created',
    () async {
      final p = await freshProvider('cs_unmapped');
      await p.addCourse(mine('a1', 'פיזיקה א'));
      await p.addCourse(mine('a2', 'פיזיקה ב'));
      final svc = CalendarSyncService(p, SyncStore(), autoCreateCourses: false);
      final s = await svc.applyEntries('afeka', [
        lecture('פיזיקה', mon),
        lecture('כימיה', mon),
      ]);
      expect(s.unmappedCourses.toSet(), {'פיזיקה', 'כימיה'});
      expect(p.courses, hasLength(2));
      expect(p.events, isEmpty);
    },
  );

  test('saved mapping picks the chosen course or creates a new one', () async {
    final p = await freshProvider('cs_map');
    await p.addCourse(mine('a1', 'Calculus'));
    final store = SyncStore();
    await store.saveCourseMap('afeka', {'חשבון': 'a1', 'כימיה': ''});
    final svc = CalendarSyncService(p, store, autoCreateCourses: false);
    final s = await svc.applyEntries('afeka', [
      lecture('חשבון', mon),
      lecture('כימיה', mon),
    ]);
    expect(s.unmappedCourses, isEmpty);
    expect(p.courses.map((c) => c.name).toSet(), {'Calculus', 'כימיה'});
    expect(
      p.events.where((e) => e.courseId == 'a1' && e.title == 'Calculus'),
      hasLength(1),
    );
  });

  test('creates a course for an unmatched name', () async {
    final p = await freshProvider('cs_create');
    await CalendarSyncService(
      p,
      SyncStore(),
    ).applyEntries('afeka', [lecture('פיזיקה', mon)]);
    expect(p.courses.single.name, 'פיזיקה');
  });

  test('second run does not duplicate; ids are deterministic', () async {
    final p = await freshProvider('cs_idem');
    final svc = CalendarSyncService(p, SyncStore());
    final feed = [lecture('פיזיקה', mon)];
    await svc.applyEntries('afeka', feed);
    final id = p.events.single.id;
    await svc.applyEntries('afeka', feed);
    expect(p.events, hasLength(1));
    expect(p.events.single.id, id);
    expect(
      CalendarSyncService.syncedEventId('afeka', 'k', 0),
      CalendarSyncService.syncedEventId('afeka', 'k', 0),
    );
  });

  test('two devices produce identical event ids', () async {
    final a = await freshProvider('cs_dev_a');
    await CalendarSyncService(
      a,
      SyncStore(),
    ).applyEntries('afeka', [lecture('פיזיקה', mon)]);
    SharedPreferences.setMockInitialValues({});
    final b = await freshProvider('cs_dev_b');
    await CalendarSyncService(
      b,
      SyncStore(),
    ).applyEntries('afeka', [lecture('פיזיקה', mon)]);
    expect(a.events.single.id, b.events.single.id);
  });

  test('cancelled entry is kept, prefixed and grey', () async {
    final p = await freshProvider('cs_cancel');
    await CalendarSyncService(
      p,
      SyncStore(),
      cancelledLabel: 'Cancelled',
    ).applyEntries('afeka', [lecture('פיזיקה', mon, cancelled: true)]);
    final e = p.events.single;
    expect(e.title, startsWith('Cancelled'));
    expect(e.color, const Color(0xFF9E9E9E));
  });

  test('removed entries delete only synced events', () async {
    final p = await freshProvider('cs_remove');
    final svc = CalendarSyncService(p, SyncStore());
    await p.addEvent(
      ScheduleEvent(
        id: 'hand',
        title: 'mine',
        courseId: '',
        type: EventType.other,
        startTime: mon,
        endTime: mon.add(const Duration(hours: 1)),
      ),
    );
    await svc.applyEntries('afeka', [
      lecture('פיזיקה', mon),
      lecture('פיזיקה', mon.add(const Duration(days: 7))),
    ]);
    expect(p.events, hasLength(3));
    final summary = await svc.applyEntries('afeka', [lecture('פיזיקה', mon)]);
    expect(p.events.map((e) => e.id), contains('hand'));
    expect(p.events, hasLength(2));
    expect(summary.changes.single.kind, ChangeKind.removed);
  });

  test('skip kinds and unregistered exams are not imported', () async {
    final p = await freshProvider('cs_skip');
    final holiday = FeedEntry(
      uid: 'h',
      summary: 'חנוכה',
      start: mon,
      end: mon,
      transparent: true,
    );
    final exam = FeedEntry(
      uid: 'e',
      summary: 'מבחן מועד 2 בחינה פיזיקה',
      description: 'מבחן מועד 2 בחינה.חדר לימוד : .לא רשום למבחן',
      start: mon,
      end: mon.add(const Duration(hours: 3)),
    );
    await CalendarSyncService(
      p,
      SyncStore(),
    ).applyEntries('afeka', [holiday, exam, lecture('פיזיקה', mon)]);
    expect(p.events, hasLength(1));
  });

  test('lecture and practice at the same minute both survive', () async {
    final p = await freshProvider('cs_both');
    await CalendarSyncService(p, SyncStore()).applyEntries('afeka', [
      lecture('פיזיקה', mon),
      lecture('פיזיקה', mon, desc: 'סוג מפגש: תרגול'),
    ]);
    expect(p.events, hasLength(2));
  });

  test('legacy garbled import is removed and redone as a first run', () async {
    final p = await freshProvider('cs_legacy');
    final svc = CalendarSyncService(p, SyncStore());
    final garbled = latin1.decode(utf8.encode('פיזיקה'));
    await svc.applyEntries('afeka', [lecture(garbled, mon)]);
    expect(p.courses.single.name, garbled);
    // Simulate an install from before the UTF-8 fix (no format version).
    await (await SharedPreferences.getInstance()).remove('calsync.ver.afeka');

    final summary = await svc.applyEntries('afeka', [lecture('פיזיקה', mon)]);

    expect(summary.isFirstRun, isTrue);
    expect(p.courses.map((c) => c.name), ['פיזיקה']);
    expect(p.events, hasLength(1));
    expect(p.events.single.title, 'פיזיקה');
  });

  test('first run offers weekly sessions as replace candidates', () async {
    final p = await freshProvider('cs_replace');
    await p.addCourse(
      Course(
        id: 'phys',
        name: 'פיזיקה',
        code: '',
        instructor: '',
        color: const Color(0xFF111111),
        credits: 3,
      ),
    );
    await p.addEvent(
      ScheduleEvent(
        id: 'weekly',
        title: 'פיזיקה',
        courseId: 'phys',
        type: EventType.classType,
        startTime: mon,
        endTime: mon.add(const Duration(hours: 2)),
        recurring: true,
        daysOfWeek: const [0],
      ),
    );
    final svc = CalendarSyncService(p, SyncStore());
    final summary = await svc.applyEntries('afeka', [lecture('פיזיקה', mon)]);
    expect(summary.isFirstRun, isTrue);
    expect(summary.replaceCandidates.map((e) => e.id), ['weekly']);
    expect(p.events.map((e) => e.id), contains('weekly'));
    await svc.applyReplacement(
      summary.replaceCandidates.map((e) => e.id).toList(),
    );
    expect(p.events.map((e) => e.id), isNot(contains('weekly')));
  });
}
