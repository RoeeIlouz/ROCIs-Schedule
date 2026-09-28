import 'package:flutter/material.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

/// Store-screenshot demo data. Only compiled in with
/// `--dart-define=SCREENSHOT_SEED=true` (a compile-time constant, so release
/// builds never touch user data). Fills an empty local database only.
class ScreenshotSeed {
  ScreenshotSeed._();

  static const enabled = bool.fromEnvironment('SCREENSHOT_SEED');

  // (id, name, code, instructor, color, credits, grade)
  static const _courses = [
    ('c_linalg', 'Linear Algebra', 'MATH 201', 'Dr. Sarah Levin', 0xFF0EA5E9, 4.0, 91.0),
    ('c_ds', 'Data Structures', 'CS 210', 'Prof. Daniel Cohen', 0xFF10B981, 5.0, 88.0),
    ('c_psych', 'Intro to Psychology', 'PSY 101', 'Dr. Maya Rosen', 0xFFF59E0B, 3.0, 94.0),
    ('c_econ', 'Microeconomics', 'ECON 110', 'Dr. Adam Weiss', 0xFFF43F5E, 3.0, null),
    ('c_write', 'Academic Writing', 'ENG 120', 'Ms. Noa Katz', 0xFF14B8A6, 2.0, null),
  ];

  // (courseId, title, type, weekdays 0=Sun, start h, start m, end h, end m, room)
  static const _classes = [
    ('c_linalg', 'Lecture', EventType.classType, [1, 3], 9, 0, 10, 30, 'Science Hall 204'),
    ('c_ds', 'Lecture', EventType.classType, [1, 4], 11, 0, 12, 30, 'CS Building 1.12'),
    ('c_econ', 'Lecture', EventType.classType, [1, 3], 14, 0, 15, 30, 'Social Sciences 105'),
    ('c_ds', 'Lab session', EventType.lab, [2], 14, 0, 16, 0, 'Computer Lab B'),
    ('c_psych', 'Lecture', EventType.classType, [2, 4], 9, 30, 11, 0, 'Auditorium 3'),
    ('c_write', 'Seminar', EventType.classType, [0, 2], 12, 0, 13, 30, 'Humanities 21'),
    ('c_linalg', 'Study group', EventType.study, [0], 15, 0, 16, 30, 'Library, 2nd floor'),
  ];

  // (courseId, days from today, hour, room)
  static const _exams = [
    ('c_linalg', 12, 9, 'Exam Center A'),
    ('c_ds', 19, 13, 'CS Building 0.01'),
    ('c_econ', 33, 10, 'Exam Center B'),
  ];

  // (courseId, title, days from today, priority, done)
  static const _assignments = [
    ('c_ds', 'Binary search tree project', 2, AssignmentPriority.high, false),
    ('c_linalg', 'Problem set 4: eigenvalues', 4, AssignmentPriority.medium, false),
    ('c_write', 'Essay outline draft', 6, AssignmentPriority.medium, false),
    ('c_psych', 'Reading: chapters 5-6', 1, AssignmentPriority.low, false),
    ('c_econ', 'Supply and demand worksheet', -1, AssignmentPriority.medium, true),
  ];

  static Future<void> apply(LocalDbService db) async {
    if ((await db.getCourses()).isNotEmpty) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await db.insertSemester(Semester(
      id: 'semester_1',
      name: 'Fall 2026',
      startDate: today.subtract(const Duration(days: 21)),
      endDate: today.add(const Duration(days: 90)),
    ));
    for (final c in _courses) {
      await db.insertCourse(Course(
        id: c.$1,
        name: c.$2,
        code: c.$3,
        instructor: c.$4,
        color: Color(c.$5),
        credits: c.$6,
        grade: c.$7,
      ));
    }
    var i = 0;
    for (final e in _classes) {
      await db.insertEvent(ScheduleEvent(
        id: 'seed_class_${i++}',
        title: e.$2,
        courseId: e.$1,
        type: e.$3,
        startTime: today.add(Duration(hours: e.$5, minutes: e.$6)),
        endTime: today.add(Duration(hours: e.$7, minutes: e.$8)),
        location: e.$9,
        daysOfWeek: e.$4,
        recurring: true,
      ));
    }
    for (final e in _exams) {
      final start = today.add(Duration(days: e.$2, hours: e.$3));
      await db.insertEvent(ScheduleEvent(
        id: 'seed_exam_${i++}',
        title: 'Final exam',
        courseId: e.$1,
        type: EventType.exam,
        startTime: start,
        endTime: start.add(const Duration(hours: 3)),
        location: e.$4,
      ));
    }
    for (final a in _assignments) {
      await db.insertAssignment(Assignment(
        id: 'seed_asg_${i++}',
        courseId: a.$1,
        title: a.$2,
        dueDate: today.add(Duration(days: a.$3, hours: 23, minutes: 59)),
        priority: a.$4,
        isCompleted: a.$5,
      ));
    }
  }
}
