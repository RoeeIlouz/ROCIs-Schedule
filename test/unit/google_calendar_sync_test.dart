import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/google_calendar_sync_service.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GrantedAuth extends AuthService {
  @override
  Future<Map<String, String>?> googleCalendarHeaders({
    required bool interactive,
    bool refresh = false,
  }) async => {'Authorization': 'Bearer test'};
}

/// An in-memory Google Calendar that records every write.
http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _FakeCalendar {
  final events = <String, Map<String, dynamic>>{};
  final writes = <String>[];
  bool calendarExists = false;
  bool failCalendarDelete = false;
  int calendarsCreated = 0;

  MockClient get client => MockClient((request) async {
    final path = request.url.path.replaceFirst('/calendar/v3', '');
    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    if (path == '/calendars' && request.method == 'POST') {
      calendarExists = true;
      calendarsCreated++;
      writes.add('create-calendar');
      return _json({'id': 'cal1'});
    }
    if (path == '/calendars/cal1' && request.method == 'DELETE') {
      if (failCalendarDelete) {
        return _json({
          'error': {'message': 'Backend Error'},
        }, 500);
      }
      calendarExists = false;
      events.clear();
      return http.Response('', 204);
    }
    if (path == '/calendars/cal1' && request.method == 'GET') {
      return http.Response(
        calendarExists ? '{}' : '',
        calendarExists ? 200 : 404,
      );
    }
    if (path == '/calendars/cal1/events' && request.method == 'GET') {
      return _json({
        'items': [
          for (final e in events.entries)
            {'id': e.key, 'extendedProperties': e.value['extendedProperties']},
        ],
      });
    }
    if (path == '/calendars/cal1/events' && request.method == 'POST') {
      final id = body['id'] as String;
      events[id] = body;
      writes.add('insert $id');
      return _json(body);
    }
    final id = path.split('/').last;
    if (request.method == 'PUT') {
      events[id] = body;
      writes.add('update $id');
      return _json(body);
    }
    if (request.method == 'DELETE') {
      events.remove(id);
      writes.add('delete $id');
      return http.Response('', 204);
    }
    return http.Response('unexpected ${request.method} $path', 500);
  });
}

ScheduleEvent _event(String id, String title) => ScheduleEvent(
  id: id,
  courseId: 'c1',
  title: title,
  type: EventType.classType,
  startTime: DateTime(2026, 10, 19, 10),
  endTime: DateTime(2026, 10, 19, 12),
  location: 'Room 204',
  daysOfWeek: const [1],
  recurring: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCalendar google;
  late CourseProvider courses;
  late GoogleCalendarSyncService sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    google = _FakeCalendar();
    courses = CourseProvider('test_uid');
    await courses.addCourse(
      Course(
        id: 'c1',
        name: 'Algorithms',
        code: 'CS201',
        instructor: 'Dr. Turing',
        color: Colors.teal,
        credits: 4,
      ),
    );
    await courses.addEvent(_event('e1', 'Lecture'));
    await courses.addEvent(_event('e2', 'Tutorial'));
    sync = GoogleCalendarSyncService(_GrantedAuth(), client: google.client)
      ..attach(courses, ThemeProvider());
  });

  tearDown(() => sync.dispose());

  test('turning sync on creates the calendar and every event', () async {
    expect(await sync.enable(), isTrue);
    expect(google.writes.first, 'create-calendar');
    expect(google.writes.where((w) => w.startsWith('insert')), hasLength(2));
    expect(sync.status, CalendarSyncStatus.synced);
    expect(sync.syncedCount, 2);
    final lecture = google.events.values.firstWhere(
      (e) => e['summary'] == 'Algorithms · Lecture',
    );
    expect(lecture['location'], 'Room 204');
    expect(lecture['description'], contains('Instructor: Dr. Turing'));
  });

  test('a resync without changes writes nothing', () async {
    await sync.enable();
    google.writes.clear();
    await sync.syncNow();
    expect(google.writes, isEmpty);
  });

  test('only the changed event is updated', () async {
    await sync.enable();
    google.writes.clear();
    await courses.addEvent(_event('e1', 'Lecture (moved)'));
    await sync.syncNow();
    expect(google.writes, hasLength(1));
    expect(google.writes.single, startsWith('update'));
  });

  test('a deleted event is removed from Google Calendar', () async {
    await sync.enable();
    google.writes.clear();
    await courses.deleteEvent('e2');
    await sync.syncNow();
    expect(google.writes, hasLength(1));
    expect(google.writes.single, startsWith('delete'));
    expect(google.events, hasLength(1));
  });

  test('off (keep) then on reuses the same calendar', () async {
    await sync.enable();
    await sync.disable(removeCalendar: false);
    await sync.enable();
    expect(google.calendarsCreated, 1);
  });

  test('a failed calendar removal does not lead to a duplicate', () async {
    await sync.enable();
    google.failCalendarDelete = true;
    await sync.disable(removeCalendar: true);
    expect(sync.lastError, contains('Backend Error'));
    await sync.enable();
    expect(google.calendarsCreated, 1);
  });

  test('off (remove) then on creates exactly one new calendar', () async {
    await sync.enable();
    await sync.disable(removeCalendar: true);
    await sync.enable();
    expect(google.calendarsCreated, 2);
    expect(google.events, hasLength(2));
  });

  test('a course without a semester repeats with no end date', () async {
    await sync.enable();
    for (final event in google.events.values) {
      expect(event['recurrence'], ['RRULE:FREQ=WEEKLY;BYDAY=MO']);
    }
  });

  test('turning sync off can remove the calendar', () async {
    await sync.enable();
    await sync.disable(removeCalendar: true);
    expect(sync.enabled, isFalse);
    expect(sync.status, CalendarSyncStatus.off);
  });
}
