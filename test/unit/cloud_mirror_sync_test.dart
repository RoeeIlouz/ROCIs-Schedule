import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';
import 'package:rocis_schedule/shared/services/mirror_reconciler.dart';

Semester _sem(String id, {DateTime? start}) =>
    Semester(id: id, name: id, startDate: start);

MirrorPlan<Semester> _plan({
  required List<Semester> remote,
  required List<Semester> local,
  Set<String> confirmed = const {},
  bool fromCache = false,
}) => planMirror<Semester>(
  remote: remote,
  local: local,
  idOf: (s) => s.id,
  toMap: (s) => s.toMap(),
  confirmedIds: confirmed,
  fromCache: fromCache,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('planMirror', () {
    test('cloud copy wins for records present on both sides', () {
      final cloud = _sem('semester_1', start: DateTime(2026, 10, 25));
      final plan = _plan(remote: [cloud], local: [_sem('semester_1')]);

      expect(plan.upsertLocal, [cloud]);
      expect(plan.uploadToCloud, isEmpty);
      expect(plan.deleteLocal, isEmpty);
    });

    test('unchanged records produce no work', () {
      final s = _sem('semester_1', start: DateTime(2026, 10, 25));
      final plan = _plan(
        remote: [s],
        local: [_sem('semester_1', start: DateTime(2026, 10, 25))],
      );

      expect(plan.changesLocal, isFalse);
      expect(plan.uploadToCloud, isEmpty);
    });

    test('never-synced local records are uploaded, not deleted', () {
      final localOnly = _sem('semester_2', start: DateTime(2027, 3, 14));
      final plan = _plan(remote: const [], local: [localOnly]);

      expect(plan.uploadToCloud, [localOnly]);
      expect(plan.deleteLocal, isEmpty);
    });

    test('records deleted on another device are removed locally', () {
      final plan = _plan(
        remote: const [],
        local: [_sem('semester_2')],
        confirmed: {'semester_2'},
      );

      expect(plan.deleteLocal, ['semester_2']);
      expect(plan.uploadToCloud, isEmpty);
    });

    test('cache snapshots never delete or upload, and confirm nothing', () {
      final plan = _plan(
        remote: const [],
        local: [_sem('semester_2')],
        confirmed: {'semester_2'},
        fromCache: true,
      );

      expect(plan.deleteLocal, isEmpty);
      expect(plan.uploadToCloud, isEmpty);
      expect(plan.confirmedIds, isNull);
    });

    test('server snapshots confirm exactly the cloud ids', () {
      final plan = _plan(remote: [_sem('a'), _sem('b')], local: [_sem('c')]);

      expect(plan.confirmedIds, {'a', 'b'});
    });
  });

  group('CourseProvider remote application', () {
    const uid = 'mirror_test_user';
    late CourseProvider provider;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      await LocalDbService.clearCache();
      final db = await LocalDbService(uid).database;
      if (db != null) {
        await db.delete('events');
        await db.delete('courses');
        await db.delete('semesters');
      }
      provider = CourseProvider(uid);
      await provider.loadData();
    });

    tearDown(LocalDbService.clearCache);

    Course course(String id, String name) => Course(
      id: id,
      name: name,
      code: '',
      instructor: '',
      color: const Color(0xFF1E88E5),
      credits: 3,
    );

    test('applies upserts and deletions with one notification', () async {
      await provider.addCourseFromSync(course('keep', 'Old name'));
      await provider.addCourseFromSync(course('gone', 'Deleted elsewhere'));
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.applyRemoteCourses([course('keep', 'New name')], ['gone']);

      expect(provider.courses.map((c) => c.name), ['New name']);
      expect(notifications, 1);
      final reloaded = CourseProvider(uid);
      await reloaded.loadData();
      expect(reloaded.courses.map((c) => c.id), ['keep']);
    });

    test('cloud semester dates replace date-less local defaults', () async {
      expect(
        provider.getSemesterById('semester_1')?.startDate,
        isNull,
        reason: 'fresh install starts with date-less defaults',
      );

      await provider.applyRemoteSemesters([
        _sem('semester_1', start: DateTime(2026, 10, 25)),
      ], const []);

      expect(
        provider.getSemesterById('semester_1')?.startDate,
        DateTime(2026, 10, 25),
      );
    });

    test('deleting a course also removes its events locally', () async {
      final now = DateTime(2026, 10, 25, 9);
      await provider.addCourseFromSync(course('c1', 'Algebra'));
      await provider.addEventFromSync(
        ScheduleEvent(
          id: 'e1',
          title: 'Lecture',
          courseId: 'c1',
          type: EventType.classType,
          startTime: now,
          endTime: now.add(const Duration(hours: 2)),
          location: '',
          daysOfWeek: const [0],
          recurring: true,
          notes: '',
        ),
      );

      await provider.deleteCourse('c1');

      expect(provider.courses, isEmpty);
      expect(provider.events, isEmpty);
    });
  });
}
