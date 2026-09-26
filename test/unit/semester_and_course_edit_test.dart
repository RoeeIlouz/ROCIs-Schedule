import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Semester Model & Serialization Suite', () {
    test('Semester toMap and fromMap serialization with dates', () {
      final startDate = DateTime(2026, 10, 15);
      final endDate = DateTime(2027, 1, 30);
      const semester = Semester(
        id: 'semester_1',
        name: 'First Semester',
        startDate: null,
        endDate: null,
      );

      final withDates = semester.copyWith(
        startDate: startDate,
        endDate: endDate,
      );

      expect(withDates.startDate, startDate);
      expect(withDates.endDate, endDate);

      final map = withDates.toMap();
      expect(map['id'], 'semester_1');
      expect(map['name'], 'First Semester');
      expect(map['startDate'], startDate.toIso8601String());
      expect(map['endDate'], endDate.toIso8601String());

      final fromMap = Semester.fromMap(map);
      expect(fromMap.id, 'semester_1');
      expect(fromMap.name, 'First Semester');
      expect(fromMap.startDate, startDate);
      expect(fromMap.endDate, endDate);
    });

    test('Semester copyWith clearDates resets dates to null', () {
      final semester = Semester(
        id: 'semester_2',
        name: 'Second Semester',
        startDate: DateTime(2027, 3, 1),
        endDate: DateTime(2027, 6, 30),
      );

      final cleared = semester.copyWith(clearDates: true);
      expect(cleared.startDate, isNull);
      expect(cleared.endDate, isNull);
      expect(cleared.id, 'semester_2');
      expect(cleared.name, 'Second Semester');
    });

    test(
      'Course model handles semester serialization and defaults gracefully',
      () {
        final courseDefault = Course(
          id: 'c1',
          name: 'Physics',
          code: 'PHYS101',
          instructor: 'Dr. Feynman',
          color: Colors.blue,
          credits: 3.5,
        );
        expect(courseDefault.semester, 'semester_1');

        final map = courseDefault.toMap();
        expect(map['semester'], 'semester_1');

        final fromMap = Course.fromMap(map);
        expect(fromMap.semester, 'semester_1');

        final courseSummer = courseDefault.copyWith(
          semester: 'semester_summer',
        );
        expect(courseSummer.semester, 'semester_summer');
        expect(courseSummer.toMap()['semester'], 'semester_summer');
      },
    );
  });

  group('CourseProvider Semester & Course CRUD Suite', () {
    late CourseProvider provider;
    const testUid = 'test_semester_user';

    setUp(() async {
      await LocalDbService.clearCache();
      final db = await LocalDbService(testUid).database;
      if (db != null) {
        await db.delete('semesters');
        await db.delete('events');
        await db.delete('courses');
      }
      provider = CourseProvider(testUid);
      await provider.loadData();
    });

    tearDown(() async {
      await LocalDbService.clearCache();
    });

    test('Provider seeds default semesters when empty', () {
      expect(provider.semesters.length, 3);
      expect(
        provider.semesters.map((s) => s.id),
        containsAll(['semester_1', 'semester_2', 'semester_summer']),
      );
    });

    test('updateSemester updates dates and persists in provider', () async {
      final start = DateTime(2026, 10, 20);
      final end = DateTime(2027, 1, 25);
      final sem1 = provider.getSemesterById('semester_1')!;
      final updatedSem = sem1.copyWith(startDate: start, endDate: end);

      await provider.updateSemester(updatedSem);

      final reloaded = provider.getSemesterById('semester_1');
      expect(reloaded?.startDate, start);
      expect(reloaded?.endDate, end);
    });

    test('updateCourse updates existing course details seamlessly', () async {
      final course = Course(
        id: 'c_math',
        name: 'Calculus I',
        code: 'MATH101',
        instructor: 'Prof. Newton',
        color: Colors.red,
        credits: 4.0,
        grade: 85.0,
        semester: 'semester_1',
      );
      await provider.addCourse(course);
      expect(provider.courses.length, 1);

      final updatedCourse = course.copyWith(
        name: 'Calculus I - Honors',
        credits: 5.0,
        grade: 92.0,
        semester: 'semester_2',
      );
      await provider.updateCourse(updatedCourse);

      expect(provider.courses.length, 1);
      final retrieved = provider.courses.first;
      expect(retrieved.name, 'Calculus I - Honors');
      expect(retrieved.credits, 5.0);
      expect(retrieved.grade, 92.0);
      expect(retrieved.semester, 'semester_2');
    });

    test(
      'Semester course filtering & isolated GPA calculation work accurately',
      () async {
        final courseSem1A = Course(
          id: 'c1',
          name: 'Intro to CS',
          code: 'CS101',
          instructor: 'Turing',
          color: Colors.blue,
          credits: 3.0,
          grade: 90.0,
          semester: 'semester_1',
        );
        final courseSem1B = Course(
          id: 'c2',
          name: 'Calculus',
          code: 'MATH101',
          instructor: 'Leibniz',
          color: Colors.green,
          credits: 4.0,
          grade: 80.0,
          semester: 'semester_1',
        );
        final courseSem2 = Course(
          id: 'c3',
          name: 'Data Structures',
          code: 'CS102',
          instructor: 'Knuth',
          color: Colors.orange,
          credits: 4.0,
          grade: 95.0,
          semester: 'semester_2',
        );

        await provider.addCourse(courseSem1A);
        await provider.addCourse(courseSem1B);
        await provider.addCourse(courseSem2);

        expect(provider.courses.length, 3);

        // Filtering by semester_1
        final sem1Courses = provider.getFilteredCourses('semester_1');
        expect(sem1Courses.length, 2);
        expect(sem1Courses.map((c) => c.id), containsAll(['c1', 'c2']));
        expect(provider.getFilteredCredits('semester_1'), 7.0);
        // Sem 1 Average: (3 * 90 + 4 * 80) / 7 = (270 + 320) / 7 = 590 / 7 = 84.2857
        expect(
          provider.getFilteredAverageGrade('semester_1'),
          closeTo(84.285, 0.01),
        );

        // Filtering by semester_2
        final sem2Courses = provider.getFilteredCourses('semester_2');
        expect(sem2Courses.length, 1);
        expect(sem2Courses.first.id, 'c3');
        expect(provider.getFilteredCredits('semester_2'), 4.0);
        expect(provider.getFilteredAverageGrade('semester_2'), 95.0);
        expect(provider.getFilteredGpa('semester_2'), 4.0);

        // Filtering by 'all'
        expect(provider.getFilteredCourses('all').length, 3);
        expect(provider.getFilteredCredits('all'), 11.0);
      },
    );
  });

  group('AuthService guest-first defaults', () {
    test('A fresh install is a guest with local-only data', () {
      final auth = AuthService();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isGuest, isTrue);
      expect(auth.effectiveUserId, 'guest');
    });

    test('signOut returns to the guest profile', () async {
      final auth = AuthService();
      await auth.signOut();
      expect(auth.isGuest, isTrue);
      expect(auth.effectiveUserId, 'guest');
    });
  });
}
