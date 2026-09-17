import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('CourseProvider Lifecycle & Business Logic Suite', () {
    late CourseProvider courseProvider;
    const testUid = 'test_provider_user';

    setUp(() async {
      await LocalDbService.clearCache();
      final db = await LocalDbService(testUid).database;
      if (db != null) {
        await db.delete('events');
        await db.delete('courses');
      }
      courseProvider = CourseProvider(testUid);
      await courseProvider.loadData();
    });

    tearDown(() async {
      await LocalDbService.clearCache();
    });

    test('Initial state is empty and not loading', () {
      expect(courseProvider.courses, isEmpty);
      expect(courseProvider.events, isEmpty);
      expect(courseProvider.isLoading, isFalse);
      expect(courseProvider.totalCredits, 0.0);
      expect(courseProvider.averageGrade, isNull);
      expect(courseProvider.calculatedGpa, isNull);
    });

    test(
      'Adding and deleting courses updates state and notifies listeners',
      () async {
        int notifyCount = 0;
        courseProvider.addListener(() => notifyCount++);

        final course = Course(
          id: 'c_linear_algebra',
          name: 'Linear Algebra',
          code: 'MATH201',
          instructor: 'Dr. Gauss',
          color: const Color(0xFF1E88E5),
          credits: 3.5,
          grade: 92.0,
        );

        await courseProvider.addCourse(course);
        expect(courseProvider.courses.length, 1);
        expect(courseProvider.courses.first.name, 'Linear Algebra');
        expect(courseProvider.totalCredits, 3.5);
        expect(courseProvider.averageGrade, 92.0);
        expect(notifyCount > 0, isTrue);

        await courseProvider.deleteCourse('c_linear_algebra');
        expect(courseProvider.courses, isEmpty);
        expect(courseProvider.totalCredits, 0.0);
      },
    );

    test(
      'GPA calculations calculate weighted averages and 4.0 scale accurately',
      () async {
        // Course 1: 4 credits, Grade 95
        await courseProvider.addCourse(
          Course(
            id: 'c1',
            name: 'Algorithms',
            code: 'CS201',
            instructor: 'Prof. Knuth',
            color: const Color(0xFF000000),
            credits: 4,
            grade: 95.0,
          ),
        );

        // Course 2: 2 credits, Grade 80
        await courseProvider.addCourse(
          Course(
            id: 'c2',
            name: 'Ethics',
            code: 'PHIL101',
            instructor: 'Prof. Socrates',
            color: const Color(0xFF000000),
            credits: 2,
            grade: 80.0,
          ),
        );

        // Total credits: 6
        // Weighted sum: 4 * 95 + 2 * 80 = 380 + 160 = 540
        // Average: 540 / 6 = 90.0
        expect(courseProvider.totalCredits, 6.0);
        expect(courseProvider.averageGrade, closeTo(90.0, 0.01));
        // Grade >= 90 corresponds to 3.7
        expect(courseProvider.calculatedGpa, 3.7);

        // Update grade
        await courseProvider.updateCourseGrade('c2', 96.0);
        // New Weighted sum: 4 * 95 + 2 * 96 = 380 + 192 = 572
        // Average: 572 / 6 = 95.33 (>= 93 -> 4.0)
        expect(courseProvider.averageGrade, closeTo(95.33, 0.01));
        expect(courseProvider.calculatedGpa, 4.0);
      },
    );

    test(
      'addCourseFromSync updates in-memory list without duplicate entries',
      () async {
        final course = Course(
          id: 'c_sync',
          name: 'Database Systems',
          code: 'CS301',
          instructor: 'Dr. Codd',
          color: const Color(0xFF009688),
          credits: 3,
        );

        await courseProvider.addCourseFromSync(course);
        expect(courseProvider.courses.length, 1);

        // Sync again with updated title
        final updatedSync = course.copyWith(name: 'Advanced Database Systems');
        await courseProvider.addCourseFromSync(updatedSync);
        expect(courseProvider.courses.length, 1);
        expect(courseProvider.courses.first.name, 'Advanced Database Systems');
      },
    );

    test(
      'importIcsTimetable populates both courses and schedule events',
      () async {
        final icsCourse = Course(
          id: 'ics_c1',
          name: 'Software Architecture',
          code: 'CS401',
          instructor: 'Dr. Martin',
          color: const Color(0xFF673AB7),
          credits: 3,
        );
        final icsEvent = ScheduleEvent(
          id: 'ics_e1',
          title: 'Lecture 1',
          courseId: 'ics_c1',
          type: EventType.classType,
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 2)),
        );

        final result = IcsImportResult(
          courses: [icsCourse],
          events: [icsEvent],
        );

        await courseProvider.importIcsTimetable(result);
        expect(courseProvider.courses.any((c) => c.id == 'ics_c1'), isTrue);
        expect(courseProvider.events.any((e) => e.id == 'ics_e1'), isTrue);
      },
    );

    test('clearLocalData resets in-memory courses and events', () async {
      await courseProvider.addCourse(
        Course(
          id: 'c_temp',
          name: 'Temp',
          code: 'TEMP101',
          instructor: 'Staff',
          color: const Color(0xFF000000),
          credits: 1,
        ),
      );
      expect(courseProvider.courses.isNotEmpty, isTrue);

      await courseProvider.clearLocalData();
      expect(courseProvider.courses, isEmpty);
      expect(courseProvider.events, isEmpty);
    });
  });

  group('AssignmentProvider Lifecycle Suite', () {
    late AssignmentProvider assignmentProvider;
    const testUid = 'test_assignment_user';

    setUp(() async {
      await LocalDbService.clearCache();
      final db = await LocalDbService(testUid).database;
      if (db != null) {
        await db.delete('assignments');
        await db.delete('courses');
        await db.insert('courses', {
          'id': 'c_cs',
          'name': 'Computer Science',
          'code': 'CS101',
          'instructor': 'Prof. Turing',
          'color': 0xFF2196F3,
          'credits': 3.0,
        });
        await db.insert('courses', {
          'id': 'c_1',
          'name': 'Math',
          'code': 'MATH101',
          'instructor': 'Prof. Euler',
          'color': 0xFF4CAF50,
          'credits': 4.0,
        });
      }
      assignmentProvider = AssignmentProvider(testUid);
      await assignmentProvider.loadAssignments();
    });

    tearDown(() async {
      await LocalDbService.clearCache();
    });

    test('Initial state is empty and not loading', () {
      expect(assignmentProvider.assignments, isEmpty);
      expect(assignmentProvider.isLoading, isFalse);
    });

    test(
      'addAssignment, toggleAssignmentCompletion and deleteAssignment',
      () async {
        final assignment = Assignment(
          id: 'a_unit_1',
          courseId: 'c_cs',
          title: 'Complete Homework 1',
          description: 'Questions 1 through 5',
          dueDate: DateTime.now().add(const Duration(days: 3)),
          priority: AssignmentPriority.high,
          isCompleted: false,
        );

        await assignmentProvider.addAssignment(assignment);
        expect(assignmentProvider.assignments.length, 1);
        expect(
          assignmentProvider.assignments.first.title,
          'Complete Homework 1',
        );
        expect(assignmentProvider.assignments.first.isCompleted, isFalse);

        // Toggle completion
        await assignmentProvider.toggleAssignmentCompletion('a_unit_1');
        expect(assignmentProvider.assignments.first.isCompleted, isTrue);

        // Toggle again
        await assignmentProvider.toggleAssignmentCompletion('a_unit_1');
        expect(assignmentProvider.assignments.first.isCompleted, isFalse);

        // Delete
        await assignmentProvider.deleteAssignment('a_unit_1');
        expect(assignmentProvider.assignments, isEmpty);
      },
    );

    test('clearLocalData resets in-memory assignments list', () async {
      final assignment = Assignment(
        id: 'a_temp',
        courseId: 'c_1',
        title: 'Temp Assignment',
        dueDate: DateTime.now(),
        priority: AssignmentPriority.low,
      );

      await assignmentProvider.addAssignment(assignment);
      expect(assignmentProvider.assignments.isNotEmpty, isTrue);

      assignmentProvider.clearLocalData();
      expect(assignmentProvider.assignments, isEmpty);
    });
  });
}
