import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils;
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
    for (final s in _semesters) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Semester bounds as yyyymmdd ints, rebuilt only when semesters change.
  /// Per-day checks run for every event on every visible day, and building
  /// local DateTimes there costs a timezone lookup each.
  Map<String, ({int? start, int? end})>? _semesterBoundsCache;

  Map<String, ({int? start, int? end})> get _semesterBounds =>
      _semesterBoundsCache ??= {
        for (final s in _semesters)
          s.id: (start: dayKeyOf(s.startDate), end: dayKeyOf(s.endDate)),
      };

  static int? dayKeyOf(DateTime? d) =>
      d == null ? null : d.year * 10000 + d.month * 100 + d.day;

  /// Whether [event] takes place on [date]: recurring classes on their
  /// weekdays within their course's semester, one-off events on their date.
  bool occursOn(
    ScheduleEvent event,
    DateTime date,
    Map<String, Course> courses,
  ) {
    if (!event.recurring) return DateUtils.isSameDay(event.startTime, date);
    if (!event.daysOfWeek.contains(date.weekday % 7)) return false;

    final semesterId = courses[event.courseId]?.semester;
    final bounds = semesterId == null ? null : _semesterBounds[semesterId];
    if (bounds == null) return true;
    final day = dayKeyOf(date)!;
    if (bounds.start != null && day < bounds.start!) return false;
    if (bounds.end != null && day > bounds.end!) return false;
    return true;
  }

  @override
  void notifyListeners() {
    _semesterBoundsCache = null;
    super.notifyListeners();
  }

  /// Loads the local cache for an instant first frame. Cloud changes arrive
  /// through [SyncService]'s live mirror, which calls the `applyRemote*`
  /// methods below.
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
    } catch (e) {
      debugPrint('CourseProvider.loadData error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cloud writes are not awaited: Firestore queues them offline, and awaiting
  /// a commit while offline would never complete and freeze the caller.
  void _cloud(Future<void> write) {
    unawaited(
      write.catchError((Object e) {
        debugPrint('CourseProvider cloud write failed: $e');
      }),
    );
  }

  Future<void> updateSemester(Semester semester) async {
    final idx = _semesters.indexWhere((s) => s.id == semester.id);
    if (idx >= 0) {
      _semesters[idx] = semester;
    } else {
      _semesters.add(semester);
    }
    await _dbService.insertSemester(semester);
    _cloud(_firestoreService.saveSemester(userId, semester));
    notifyListeners();
  }

  Future<void> updateCourse(Course course) async {
    await _dbService.insertCourse(course);
    _upsert(_courses, course, (c) => c.id);
    _cloud(_firestoreService.saveCourse(userId, course));
    notifyListeners();
  }

  Future<void> addCourse(Course course) => updateCourse(course);

  Future<void> addCourseFromSync(Course course) async {
    await _dbService.insertCourse(course);
    _upsert(_courses, course, (c) => c.id);
    notifyListeners();
  }

  Future<void> updateCourseGrade(String courseId, double? grade) async {
    final index = _courses.indexWhere((c) => c.id == courseId);
    if (index >= 0) {
      await updateCourse(_courses[index].copyWith(grade: grade));
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
      _upsert(_events, event, (e) => e.id);
    }
    _cloud(_firestoreService.uploadCourses(userId, result.courses));
    _cloud(_firestoreService.uploadEvents(userId, result.events));
    notifyListeners();
  }

  /// Deletes a course and its events (the cloud side also removes them).
  Future<void> deleteCourse(String id) async {
    await _dbService.deleteCourse(id);
    final courseEvents = _events.where((e) => e.courseId == id).toList();
    for (final event in courseEvents) {
      await _dbService.deleteEvent(event.id);
    }
    _courses.removeWhere((c) => c.id == id);
    _events.removeWhere((e) => e.courseId == id);
    _cloud(_firestoreService.deleteCourse(userId, id));
    notifyListeners();
  }

  Future<void> addEvent(ScheduleEvent event) async {
    await _dbService.insertEvent(event);
    _upsert(_events, event, (e) => e.id);
    _cloud(_firestoreService.saveEvent(userId, event));
    notifyListeners();
  }

  Future<void> addEventFromSync(ScheduleEvent event) async {
    await _dbService.insertEvent(event);
    _upsert(_events, event, (e) => e.id);
    notifyListeners();
  }

  Future<void> deleteEvent(String id) async {
    await _dbService.deleteEvent(id);
    _events.removeWhere((e) => e.id == id);
    _cloud(_firestoreService.deleteEvent(userId, id));
    notifyListeners();
  }

  /// Applies a batch of cloud changes with a single UI notification.
  Future<void> applyRemoteCourses(
    List<Course> upserts,
    List<String> deletedIds,
  ) async {
    for (final course in upserts) {
      await _dbService.insertCourse(course);
      _upsert(_courses, course, (c) => c.id);
    }
    for (final id in deletedIds) {
      await _dbService.deleteCourse(id);
    }
    _courses.removeWhere((c) => deletedIds.contains(c.id));
    notifyListeners();
  }

  Future<void> applyRemoteEvents(
    List<ScheduleEvent> upserts,
    List<String> deletedIds,
  ) async {
    for (final event in upserts) {
      await _dbService.insertEvent(event);
      _upsert(_events, event, (e) => e.id);
    }
    for (final id in deletedIds) {
      await _dbService.deleteEvent(id);
    }
    _events.removeWhere((e) => deletedIds.contains(e.id));
    notifyListeners();
  }

  Future<void> applyRemoteSemesters(
    List<Semester> upserts,
    List<String> deletedIds,
  ) async {
    for (final semester in upserts) {
      await _dbService.insertSemester(semester);
      _upsert(_semesters, semester, (s) => s.id);
    }
    for (final id in deletedIds) {
      await _dbService.deleteSemester(id);
    }
    _semesters.removeWhere((s) => deletedIds.contains(s.id));
    notifyListeners();
  }

  static void _upsert<T>(List<T> list, T item, String Function(T) idOf) {
    final index = list.indexWhere((x) => idOf(x) == idOf(item));
    if (index >= 0) {
      list[index] = item;
    } else {
      list.add(item);
    }
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
