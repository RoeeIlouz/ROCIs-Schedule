import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';

class CourseProvider extends ChangeNotifier {
  final LocalDbService _dbService;
  final FirestoreService _firestoreService = FirestoreService();
  final String userId;
  List<Course> _courses = [];
  List<ScheduleEvent> _events = [];
  List<Semester> _semesters = [];
  bool _isLoading = false;

  static const List<Semester> defaultSemesters = [
    Semester(id: 'semester_1', name: 'First Semester'),
    Semester(id: 'semester_2', name: 'Second Semester'),
    Semester(id: 'semester_summer', name: 'Summer Semester'),
  ];

  CourseProvider(this.userId) : _dbService = LocalDbService(userId);

  List<Course> get courses => _courses;
  List<ScheduleEvent> get events => _events;
  List<Semester> get semesters => _semesters;
  bool get isLoading => _isLoading;

  double get totalCredits => _courses.fold(0.0, (sum, c) => sum + c.credits);

  double? get averageGrade => getFilteredAverageGrade(null);

  double? get calculatedGpa => getFilteredGpa(null);

  List<Course> getFilteredCourses(String? semesterId) {
    if (semesterId == null || semesterId == 'all') {
      return _courses;
    }
    return _courses
        .where((c) => (c.semester ?? 'semester_1') == semesterId)
        .toList();
  }

  double getFilteredCredits(String? semesterId) {
    return getFilteredCourses(
      semesterId,
    ).fold(0.0, (sum, c) => sum + c.credits);
  }

  double? getFilteredAverageGrade(String? semesterId) {
    final graded = getFilteredCourses(
      semesterId,
    ).where((c) => c.grade != null).toList();
    if (graded.isEmpty) return null;
    final totalWeighted = graded.fold(
      0.0,
      (sum, c) => sum + (c.grade! * c.credits),
    );
    final totalCreds = graded.fold(0.0, (sum, c) => sum + c.credits);
    return totalCreds > 0 ? (totalWeighted / totalCreds) : null;
  }

  double? getFilteredGpa(String? semesterId) {
    final avg = getFilteredAverageGrade(semesterId);
    if (avg == null) return null;
    final roundedAvg = double.parse(avg.toStringAsFixed(2));
    if (roundedAvg <= 4.0) return roundedAvg; // Already on 4.0 scale
    if (roundedAvg >= 93) return 4.0;
    if (roundedAvg >= 90) return 3.7;
    if (roundedAvg >= 87) return 3.3;
    if (roundedAvg >= 83) return 3.0;
    if (roundedAvg >= 80) return 2.7;
    if (roundedAvg >= 77) return 2.3;
    if (roundedAvg >= 73) return 2.0;
    if (roundedAvg >= 70) return 1.7;
    if (roundedAvg >= 60) return 1.0;
    return 0.0;
  }

  Semester? getSemesterById(String? id) {
    if (id == null) return null;
    try {
      return _semesters.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      _courses = await _dbService.getCourses();
      _events = await _dbService.getEvents();
      _semesters = await _dbService.getSemesters();
      if (_semesters.isEmpty) {
        _semesters = List.from(defaultSemesters);
        for (final sem in _semesters) {
          await _dbService.insertSemester(sem);
        }
      }
      if (_events.isNotEmpty) {
        unawaited(_firestoreService.uploadEvents(userId, _events));
      }
      if (_courses.isNotEmpty) {
        unawaited(_firestoreService.uploadCourses(userId, _courses));
      }
    } catch (e) {
      debugPrint('CourseProvider.loadData error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSemester(Semester semester) async {
    final idx = _semesters.indexWhere((s) => s.id == semester.id);
    if (idx >= 0) {
      _semesters[idx] = semester;
    } else {
      _semesters.add(semester);
    }
    await _dbService.insertSemester(semester);
    await _firestoreService.uploadSemesters(userId, _semesters);
    notifyListeners();
  }

  Future<void> updateCourse(Course course) async {
    await _dbService.insertCourse(course);
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index >= 0) {
      _courses[index] = course;
    } else {
      _courses.add(course);
    }
    await _firestoreService.uploadCourses(userId, _courses);
    notifyListeners();
  }

  Future<void> addCourse(Course course) async {
    await _dbService.insertCourse(course);
    await loadData();
    await _firestoreService.uploadCourses(userId, _courses);
  }

  Future<void> addCourseFromSync(Course course) async {
    await _dbService.insertCourse(course);
    final existingIndex = _courses.indexWhere((c) => c.id == course.id);
    if (existingIndex >= 0) {
      _courses[existingIndex] = course;
    } else {
      _courses.add(course);
    }
    notifyListeners();
  }

  Future<void> updateCourseGrade(String courseId, double? grade) async {
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index >= 0) {
      final updated = _courses[index].copyWith(grade: grade);
      _courses[index] = updated;
      await _dbService.insertCourse(updated);
      await _firestoreService.uploadCourses(userId, _courses);
      notifyListeners();
    }
  }

  Future<void> importIcsTimetable(IcsImportResult result) async {
    for (var course in result.courses) {
      await _dbService.insertCourse(course);
      final existingIndex = _courses.indexWhere(
        (c) => c.id == course.id || c.name == course.name,
      );
      if (existingIndex >= 0) {
        _courses[existingIndex] = course;
      } else {
        _courses.add(course);
      }
    }
    for (var event in result.events) {
      await _dbService.insertEvent(event);
      final existingIndex = _events.indexWhere((e) => e.id == event.id);
      if (existingIndex >= 0) {
        _events[existingIndex] = event;
      } else {
        _events.add(event);
      }
    }
    await _firestoreService.uploadCourses(userId, _courses);
    await _firestoreService.uploadEvents(userId, _events);
    notifyListeners();
  }

  Future<void> deleteCourse(String id) async {
    await _dbService.deleteCourse(id);
    await loadData();
    await _firestoreService.deleteCourse(userId, id);
  }

  Future<void> addEvent(ScheduleEvent event) async {
    await _dbService.insertEvent(event);
    await loadData();
    await _firestoreService.uploadEvents(userId, _events);
  }

  Future<void> addEventFromSync(ScheduleEvent event) async {
    await _dbService.insertEvent(event);
    final existingIndex = _events.indexWhere((e) => e.id == event.id);
    if (existingIndex >= 0) {
      _events[existingIndex] = event;
    } else {
      _events.add(event);
    }
    notifyListeners();
  }

  Future<void> deleteEvent(String id) async {
    await _dbService.deleteEvent(id);
    await loadData();
    await _firestoreService.deleteEvent(userId, id);
    await _firestoreService.uploadEvents(userId, _events);
  }

  List<ScheduleEvent> getEventsByCourse(String courseId) {
    return _events.where((e) => e.courseId == courseId).toList();
  }

  Future<void> clearLocalData() async {
    try {
      await _dbService.clearAll();
    } catch (_) {}
    _courses.clear();
    _events.clear();
    _semesters.clear();
    notifyListeners();
  }
}
