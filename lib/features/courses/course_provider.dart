import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/core/dev/screenshot_seed.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/calendar_subscription_service.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';
import 'package:rocis_schedule/shared/services/schedule_widget_service.dart';

class CourseProvider extends ChangeNotifier {
  final LocalDbService _dbService;
  final FirestoreService _firestoreService = FirestoreService();
  final String userId;
  List<Course> _courses = [];
  List<ScheduleEvent> _events = [];
  List<Semester> _semesters = [];
  bool _isLoading = false;
  final Completer<void> _loaded = Completer<void>();
  bool _subscriptionSyncing = false;

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

  /// The semester a course belongs to; courses saved without one count as
  /// the first semester, as in [getFilteredCourses].
  static String semesterIdOf(Course course) => course.semester ?? 'semester_1';

  /// Semesters that have at least one course, in the user's order. A course
  /// pointing at a semester that no longer exists still gets an entry, so it
  /// stays reachable.
  List<Semester> get semestersWithCourses {
    final used = {for (final c in _courses) semesterIdOf(c)};
    return [
      for (final s in _semesters)
        if (used.remove(s.id)) s,
      for (final id in used) Semester(id: id, name: id),
    ];
  }

  /// The semester whose dates include [date], if any has dates set.
  Semester? semesterOn(DateTime date) {
    final day = dayKeyOf(date)!;
    for (final s in _semesters) {
      final bounds = _semesterBounds[s.id];
      if (bounds?.start == null || bounds?.end == null) continue;
      if (day >= bounds!.start! && day <= bounds.end!) return s;
    }
    return null;
  }

  /// Places typed into earlier events, for the location field: [courseId]'s
  /// own places first, then the most used. Matches [query] anywhere, ignoring
  /// case, and leaves out an exact match (nothing left to complete).
  List<String> locationSuggestions({
    String? courseId,
    String query = '',
    int limit = 6,
  }) {
    final q = query.trim().toLowerCase();
    final spelling = <String, String>{};
    final uses = <String, int>{};
    final ownCourse = <String>{};
    for (final event in _events) {
      final place = event.location.trim();
      if (place.isEmpty) continue;
      final key = place.toLowerCase();
      spelling.putIfAbsent(key, () => place);
      uses[key] = (uses[key] ?? 0) + 1;
      if (courseId != null && event.courseId == courseId) ownCourse.add(key);
    }
    final keys =
        uses.keys.where((k) => k != q && (q.isEmpty || k.contains(q))).toList()
          ..sort((a, b) {
            final own =
                (ownCourse.contains(b) ? 1 : 0) -
                (ownCourse.contains(a) ? 1 : 0);
            return own != 0 ? own : uses[b]!.compareTo(uses[a]!);
          });
    return [for (final k in keys.take(limit)) spelling[k]!];
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
    if (!event.recurring) return event.coversDay(date);
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
    _syncWidget();
  }

  void _syncWidget() {
    if (_courses.isNotEmpty || _events.isNotEmpty) {
      final coursesMap = {for (final c in _courses) c.id: c};
      unawaited(
        ScheduleWidgetService.updateScheduleWidget(
          events: _events,
          courses: coursesMap,
        ),
      );
    }
  }

  /// Loads the local cache for an instant first frame. Cloud changes arrive
  /// through [SyncService]'s live mirror, which calls the `applyRemote*`
  /// methods below.
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (ScreenshotSeed.enabled) await ScreenshotSeed.apply(_dbService);
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
      if (!_loaded.isCompleted) _loaded.complete();
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
    final previous = _courses.where((c) => c.id == course.id).firstOrNull;
    await _dbService.insertCourse(course);
    _upsert(_courses, course, (c) => c.id);
    if (previous != null && previous.color != course.color) {
      await _releaseCourseColor(course.id, previous.color);
    }
    _cloud(_firestoreService.saveCourse(userId, course));
    notifyListeners();
  }

  Future<void> addCourse(Course course) => updateCourse(course);

  /// School events used to store a copy of their course's color (shared
  /// course imports did). When the course is recolored, such copies are
  /// cleared so the events follow the course; real per-event colors stay.
  Future<void> _releaseCourseColor(String courseId, Color oldColor) async {
    for (var i = 0; i < _events.length; i++) {
      final event = _events[i];
      if (event.courseId != courseId || event.color != oldColor) continue;
      if (event.domain != EventDomain.academic) continue;
      final released = event.copyWith(clearColor: true);
      _events[i] = released;
      await _dbService.insertEvent(released);
      _cloud(_firestoreService.saveEvent(userId, released));
    }
  }

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

  /// Syncs the subscribed calendar link (e.g. the Afeka calendar feed).
  ///
  /// [newUrl] subscribes to a new link: it is fetched first and only saved
  /// once it works. Without it the saved link is re-read; with [onlyIfStale]
  /// that is skipped when the last sync is recent, which keeps the automatic
  /// checks (app open, resume) cheap. Returns null when there was nothing to
  /// do; throws [CalendarSyncException] when the link could not be synced.
  Future<SubscriptionSyncResult?> syncCalendarSubscription({
    String? newUrl,
    bool onlyIfStale = false,
  }) async {
    if (_subscriptionSyncing) return null;
    _subscriptionSyncing = true;
    try {
      final url = newUrl ?? await CalendarSubscriptionService.savedUrl(userId);
      if (url == null) return null;

      if (onlyIfStale && newUrl == null) {
        final last = await CalendarSubscriptionService.lastSync(userId);
        if (last != null &&
            DateTime.now().difference(last) <
                CalendarSubscriptionService.staleAfter) {
          return null;
        }
      }

      final feed = await CalendarSubscriptionService.fetch(url);

      // Merging against a half-loaded timetable would re-create courses the
      // user already has.
      try {
        await _loaded.future.timeout(const Duration(seconds: 10));
      } on TimeoutException {
        return null;
      }

      final summary = await _applySubscription(feed);
      if (newUrl != null) {
        await CalendarSubscriptionService.saveUrl(userId, newUrl);
      }
      await CalendarSubscriptionService.markSynced(userId, DateTime.now());
      return summary;
    } finally {
      _subscriptionSyncing = false;
    }
  }

  /// Makes the timetable's subscription items match [feed]: adds new ones,
  /// updates changed ones and removes those no longer in the calendar.
  /// Only items with subscription ids are ever removed or replaced.
  Future<SubscriptionSyncResult> _applySubscription(
    IcsImportResult feed,
  ) async {
    const prefix = CalendarSubscriptionService.idPrefix;

    // A feed course maps onto a course the user already has when the names
    // match; that course (grade, credits, color...) is left as the user set it.
    String key(String name) => name.trim().toLowerCase();
    final courseIdFor = <String, String>{};
    final newCourses = <Course>[];
    for (final course in feed.courses) {
      final existing = _courses
          .where((c) => c.id == course.id || key(c.name) == key(course.name))
          .firstOrNull;
      if (existing != null) {
        courseIdFor[course.id] = existing.id;
      } else {
        courseIdFor[course.id] = course.id;
        newCourses.add(course);
      }
    }

    final oldById = {for (final e in _events) e.id: e};
    final feedIds = <String>{};
    final changedEvents = <ScheduleEvent>[];
    var added = 0;
    var updated = 0;
    for (final raw in feed.events) {
      final old = oldById[raw.id];
      // The color is the user's own choice, not part of the calendar.
      final event = raw.copyWith(
        courseId: courseIdFor[raw.courseId] ?? raw.courseId,
        color: old?.color,
      );
      if (!feedIds.add(event.id)) continue;
      if (old == null) {
        added++;
        changedEvents.add(event);
      } else if (!mapEquals(old.toMap(), event.toMap())) {
        updated++;
        changedEvents.add(event);
      }
    }

    final goneEvents = _events
        .where((e) => e.id.startsWith(prefix) && !feedIds.contains(e.id))
        .toList();

    for (final course in newCourses) {
      await _dbService.insertCourse(course);
      _upsert(_courses, course, (c) => c.id);
    }
    for (final event in changedEvents) {
      await _dbService.insertEvent(event);
      _upsert(_events, event, (e) => e.id);
    }
    for (final event in goneEvents) {
      await _dbService.deleteEvent(event.id);
      _cloud(_firestoreService.deleteEvent(userId, event.id));
    }
    final goneIds = {for (final e in goneEvents) e.id};
    _events.removeWhere((e) => goneIds.contains(e.id));

    // A course the calendar created and no longer has any event for goes too,
    // unless the user has since graded it.
    final emptyCourses = _courses
        .where(
          (c) =>
              c.id.startsWith(prefix) &&
              c.grade == null &&
              !_events.any((e) => e.courseId == c.id),
        )
        .toList();
    for (final course in emptyCourses) {
      await _dbService.deleteCourse(course.id);
      _cloud(_firestoreService.deleteCourse(userId, course.id));
    }
    _courses.removeWhere((c) => emptyCourses.contains(c));

    if (newCourses.isNotEmpty) {
      _cloud(_firestoreService.uploadCourses(userId, newCourses));
    }
    if (changedEvents.isNotEmpty) {
      _cloud(_firestoreService.uploadEvents(userId, changedEvents));
    }

    final result = SubscriptionSyncResult(
      added: added,
      updated: updated,
      removed: goneEvents.length,
    );
    if (result.changed || newCourses.isNotEmpty || emptyCourses.isNotEmpty) {
      notifyListeners();
    }
    return result;
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
