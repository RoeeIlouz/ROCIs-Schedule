import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LocalDbService SQLite CRUD Suite', () {
    late LocalDbService dbService;
    const testUserId = 'test_user_unit';

    setUp(() async {
      await LocalDbService.clearCache();
      dbService = LocalDbService(testUserId);
      final db = await dbService.database;
      expect(db, isNotNull);
      // Clean tables before each test
      await db!.delete('assignments');
      await db.delete('events');
      await db.delete('courses');
    });

    tearDown(() async {
      await LocalDbService.clearCache();
    });

    test('Course CRUD operations work as expected', () async {
      final course1 = Course(
        id: 'c_math',
        name: 'Calculus I',
        code: 'MATH101',
        instructor: 'Dr. Euler',
        color: const Color(0xFF4285F4),
        credits: 4,
        grade: 95.0,
      );

      // Insert
      await dbService.insertCourse(course1);
      var courses = await dbService.getCourses();
      expect(courses.length, 1);
      expect(courses.first.id, 'c_math');
      expect(courses.first.name, 'Calculus I');
      expect(courses.first.code, 'MATH101');
      expect(courses.first.credits, 4);
      expect(courses.first.grade, 95.0);

      // Update / Replace
      final updatedCourse = course1.copyWith(
        name: 'Calculus I - Advanced',
        grade: 98.5,
      );
      await dbService.insertCourse(updatedCourse);
      courses = await dbService.getCourses();
      expect(courses.length, 1);
      expect(courses.first.name, 'Calculus I - Advanced');
      expect(courses.first.grade, 98.5);

      // Delete
      await dbService.deleteCourse('c_math');
      courses = await dbService.getCourses();
      expect(courses.isEmpty, isTrue);
    });

    test(
      'ScheduleEvent CRUD operations work with foreign key constraint',
      () async {
        final course = Course(
          id: 'c_cs',
          name: 'Computer Science',
          code: 'CS101',
          instructor: 'Prof. Turing',
          color: const Color(0xFF34A853),
          credits: 3,
        );
        await dbService.insertCourse(course);

        final now = DateTime.now();
        final event1 = ScheduleEvent(
          id: 'e_lecture_1',
          title: 'Algorithms Lecture',
          courseId: 'c_cs',
          type: EventType.classType,
          startTime: now,
          endTime: now.add(const Duration(hours: 2)),
          location: 'Auditorium A',
          daysOfWeek: [1, 3],
          recurring: true,
          notes: 'Bring laptop',
        );

        // Insert event
        await dbService.insertEvent(event1);
        var events = await dbService.getEvents();
        expect(events.length, 1);
        expect(events.first.id, 'e_lecture_1');
        expect(events.first.title, 'Algorithms Lecture');
        expect(events.first.daysOfWeek, [1, 3]);
        expect(events.first.recurring, isTrue);

        // Delete event
        await dbService.deleteEvent('e_lecture_1');
        events = await dbService.getEvents();
        expect(events.isEmpty, isTrue);
      },
    );

    test(
      'Deleting a course cascades and deletes its events and assignments',
      () async {
        final course = Course(
          id: 'c_physics',
          name: 'Physics I',
          code: 'PHYS101',
          instructor: 'Prof. Newton',
          color: const Color(0xFFEA4335),
          credits: 3,
        );
        await dbService.insertCourse(course);

        final event = ScheduleEvent(
          id: 'e_phys_lab',
          title: 'Physics Lab',
          courseId: 'c_physics',
          type: EventType.lab,
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 3)),
        );
        await dbService.insertEvent(event);

        final assignment = Assignment(
          id: 'a_phys_hw',
          courseId: 'c_physics',
          title: 'Lab Report 1',
          dueDate: DateTime.now().add(const Duration(days: 7)),
          priority: AssignmentPriority.high,
        );
        await dbService.insertAssignment(assignment);

        // Verify insertion
        expect((await dbService.getCourses()).length, 1);
        expect((await dbService.getEvents()).length, 1);
        expect((await dbService.getAssignments()).length, 1);

        // Delete the course
        await dbService.deleteCourse('c_physics');

        // Verify cascade
        expect((await dbService.getCourses()).isEmpty, isTrue);
        expect((await dbService.getEvents()).isEmpty, isTrue);
        expect((await dbService.getAssignments()).isEmpty, isTrue);
      },
    );

    test('Assignment CRUD and completion toggle', () async {
      final course = Course(
        id: 'c_chem',
        name: 'Chemistry',
        code: 'CHEM101',
        instructor: 'Dr. Curie',
        color: const Color(0xFFFBBC05),
        credits: 3,
      );
      await dbService.insertCourse(course);

      final assignment = Assignment(
        id: 'a_chem_1',
        courseId: 'c_chem',
        title: 'Stoichiometry Quiz',
        description: 'Chapters 1-3',
        dueDate: DateTime(2026, 10, 15, 14, 0),
        priority: AssignmentPriority.high,
        isCompleted: false,
      );

      await dbService.insertAssignment(assignment);
      var assignments = await dbService.getAssignments();
      expect(assignments.length, 1);
      expect(assignments.first.isCompleted, isFalse);
      expect(assignments.first.priority, AssignmentPriority.high);

      // Update completion
      final completed = assignment.copyWith(isCompleted: true);
      await dbService.insertAssignment(completed);
      assignments = await dbService.getAssignments();
      expect(assignments.first.isCompleted, isTrue);

      // Delete
      await dbService.deleteAssignment('a_chem_1');
      assignments = await dbService.getAssignments();
      expect(assignments.isEmpty, isTrue);
    });

    test('LocalDbService isolation across different userIds', () async {
      final user1Db = LocalDbService('user_alpha');
      final user2Db = LocalDbService('user_beta');

      await user1Db.insertCourse(
        Course(
          id: 'c_alpha',
          name: 'Alpha Course',
          code: 'ALPHA101',
          instructor: 'Prof. A',
          color: const Color(0xFF000000),
          credits: 3,
        ),
      );

      final user1Courses = await user1Db.getCourses();
      expect(user1Courses.any((c) => c.id == 'c_alpha'), isTrue);

      final user2Courses = await user2Db.getCourses();
      expect(user2Courses.any((c) => c.id == 'c_alpha'), isFalse);
    });
  });
}
