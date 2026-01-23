import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

class CourseProvider extends ChangeNotifier {
  final LocalDbService _dbService;
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

  Future<void> deleteCourse(String id) async {
    await _dbService.deleteCourse(id);
    await loadData();
  }

  Future<void> addEvent(ScheduleEvent event) async {
    await _dbService.insertEvent(event);
    await loadData();
  }

  Future<void> deleteEvent(String id) async {
    await _dbService.deleteEvent(id);
    await loadData();
  }

  List<ScheduleEvent> getEventsByCourse(String courseId) {
    return _events.where((e) => e.courseId == courseId).toList();
  }
}
