import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

class CourseProvider extends ChangeNotifier {
  final LocalDbService _dbService;
  final FirestoreService _firestoreService = FirestoreService();
  final String userId;
  List<Course> _courses = [];
  List<ScheduleEvent> _events = [];
  bool _isLoading = false;

  CourseProvider(this.userId) : _dbService = LocalDbService(userId);

  List<Course> get courses => _courses;
  List<ScheduleEvent> get events => _events;
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    _courses = await _dbService.getCourses();
    _events = await _dbService.getEvents();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCourse(Course course) async {
    await _dbService.insertCourse(course);
    await loadData();
  }

  /// Add course from sync without triggering another sync
  /// Used when downloading data from Firestore
  Future<void> addCourseFromSync(Course course) async {
    await _dbService.insertCourse(course);
    // Check if course already exists in memory
    final existingIndex = _courses.indexWhere((c) => c.id == course.id);
    if (existingIndex >= 0) {
      _courses[existingIndex] = course;
    } else {
      _courses.add(course);
    }
    notifyListeners();
  }

  Future<void> deleteCourse(String id) async {
    await _dbService.deleteCourse(id);
    await loadData();
    // Sync deletion to Firestore
    await _firestoreService.deleteCourse(userId, id);
  }

  Future<void> addEvent(ScheduleEvent event) async {
    await _dbService.insertEvent(event);
    await loadData();
  }

  /// Add event from sync without triggering another sync
  /// Used when downloading data from Firestore
  Future<void> addEventFromSync(ScheduleEvent event) async {
    await _dbService.insertEvent(event);
    // Check if event already exists in memory
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
    // Sync deletion to Firestore
    await _firestoreService.deleteEvent(userId, id);
  }

  List<ScheduleEvent> getEventsByCourse(String courseId) {
    return _events.where((e) => e.courseId == courseId).toList();
  }

  /// Clear all local data (used when user signs out)
  Future<void> clearLocalData() async {
    _courses.clear();
    _events.clear();
    notifyListeners();
  }
}
