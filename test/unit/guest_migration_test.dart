import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/services/guest_data_migrator.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

/// Signing in must never lose what a guest created before signing in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const guestId = GuestDataMigrator.guestUserId;
  const accountUid = 'migration_test_account';

  final course = Course(
    id: 'guest_course',
    name: 'Calculus',
    code: 'MATH101',
    instructor: 'Dr. Leibniz',
    color: const Color(0xFF1E88E5),
    credits: 4,
  );
  final event = ScheduleEvent(
    id: 'guest_event',
    courseId: 'guest_course',
    title: 'Calculus Lecture',
    type: EventType.classType,
    startTime: DateTime(2026, 10, 4, 10),
    endTime: DateTime(2026, 10, 4, 12),
    location: 'Hall A',
    daysOfWeek: const [0],
    recurring: true,
  );
  final assignment = Assignment(
    id: 'guest_assignment',
    courseId: 'guest_course',
    title: 'Problem set 1',
    dueDate: DateTime(2026, 10, 10),
  );
  final datedSemester = CourseProvider.defaultSemesters.first.copyWith(
    startDate: DateTime(2026, 10, 1),
  );

  Future<void> seedGuest() async {
    final guest = LocalDbService(guestId);
    await guest.insertSemester(datedSemester);
    await guest.insertCourse(course);
    await guest.insertEvent(event);
    await guest.insertAssignment(assignment);
  }

  setUp(() async {
    for (final uid in [guestId, accountUid]) {
      await LocalDbService.clearCache();
      await LocalDbService(uid).clearAll();
    }
    await LocalDbService.clearCache();
  });

  tearDown(() => LocalDbService.clearCache());

  test('Guest courses, events, assignments and semester dates move into '
      'the account', () async {
    await seedGuest();

    await GuestDataMigrator.migrateInto(accountUid);

    final account = LocalDbService(accountUid);
    expect((await account.getCourses()).map((c) => c.id), ['guest_course']);
    expect((await account.getEvents()).map((e) => e.id), ['guest_event']);
    expect((await account.getAssignments()).map((a) => a.id), [
      'guest_assignment',
    ]);
    final semester = (await account.getSemesters()).singleWhere(
      (s) => s.id == datedSemester.id,
    );
    expect(semester.startDate, DateTime(2026, 10, 1));
  });

  test(
    'The guest profile is empty afterwards (e.g. after a later sign-out)',
    () async {
      await seedGuest();

      await GuestDataMigrator.migrateInto(accountUid);

      final guest = LocalDbService(guestId);
      expect(await guest.getCourses(), isEmpty);
      expect(await guest.getEvents(), isEmpty);
      expect(await guest.getAssignments(), isEmpty);
    },
  );

  test('Records the account already has keep the account\'s version', () async {
    await LocalDbService(
      accountUid,
    ).insertCourse(course.copyWith(name: 'Calculus (account)'));
    await seedGuest();

    await GuestDataMigrator.migrateInto(accountUid);

    final courses = await LocalDbService(accountUid).getCourses();
    expect(courses, hasLength(1));
    expect(courses.single.name, 'Calculus (account)');
  });

  test('The account\'s providers load the migrated data', () async {
    await seedGuest();

    await GuestDataMigrator.migrateInto(accountUid);

    final provider = CourseProvider(accountUid);
    await provider.loadData();
    expect(provider.courses.map((c) => c.name), ['Calculus']);
    expect(provider.events.map((e) => e.title), ['Calculus Lecture']);
  });
}
