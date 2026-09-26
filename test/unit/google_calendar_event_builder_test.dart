import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/google_calendar_event_builder.dart';

final labels = CalendarEventLabels(
  course: 'Course',
  instructor: 'Instructor',
  type: 'Type',
  credits: 'Credits',
  semester: 'Semester',
  category: 'Category',
  footer: 'Synced from ROCIs Schedule',
  typeName: (t) => switch (t) {
    EventType.classType => 'Class',
    EventType.exam => 'Exam',
    EventType.lab => 'Lab',
    EventType.study => 'Study',
    EventType.other => 'Other',
  },
  domainName: (d) => switch (d) {
    EventDomain.academic => 'Academic',
    EventDomain.work => 'Work',
    EventDomain.personal => 'Personal',
  },
);

final course = Course(
  id: 'c1',
  name: 'Linear Algebra',
  code: 'MATH201',
  instructor: 'Dr. Gauss',
  color: const Color(0xFF039BE5),
  credits: 4,
  semester: 'semester_1',
);

final semester = Semester(
  id: 'semester_1',
  name: 'First Semester',
  startDate: DateTime(2026, 10, 18),
  endDate: DateTime(2027, 1, 22),
);

ScheduleEvent lecture({String title = 'Lecture', String notes = ''}) =>
    ScheduleEvent(
      id: '3f2a9c1e-0b7d-4e8a-9f11-2c3d4e5f6a7b',
      courseId: 'c1',
      title: title,
      type: EventType.classType,
      // Created on a Wednesday before the semester starts.
      startTime: DateTime(2026, 9, 30, 10, 15),
      endTime: DateTime(2026, 9, 30, 11, 45),
      location: 'Building 72, Room 204',
      notes: notes,
      daysOfWeek: const [3, 1], // Wed, Mon (unsorted on purpose)
      recurring: true,
    );

Map<String, dynamic> build(ScheduleEvent e, {Course? c, Semester? s}) =>
    GoogleCalendarEventBuilder.build(
      event: e,
      course: c,
      semester: s,
      timeZone: 'Asia/Jerusalem',
      reminderMinutes: 15,
      labels: labels,
    );

void main() {
  group('Weekly class', () {
    final body = build(
      lecture(notes: 'Bring the problem set'),
      c: course,
      s: semester,
    );

    test('title names the course and the session', () {
      expect(body['summary'], 'Linear Algebra · Lecture');
    });

    test('classroom goes in the location field', () {
      expect(body['location'], 'Building 72, Room 204');
    });

    test('description lists every course detail, notes and a footer', () {
      expect(
        body['description'],
        'Course: Linear Algebra (MATH201)\n'
        'Instructor: Dr. Gauss\n'
        'Type: Class\n'
        'Credits: 4\n'
        'Semester: First Semester\n'
        '\n'
        'Bring the problem set\n'
        '\n'
        '— Synced from ROCIs Schedule',
      );
    });

    test('starts on the first class day of the semester, in local time', () {
      // Semester starts Sun 18 Oct 2026; first Mon/Wed class is Mon 19 Oct.
      expect(body['start'], {
        'dateTime': '2026-10-19T10:15:00',
        'timeZone': 'Asia/Jerusalem',
      });
      expect(body['end'], {
        'dateTime': '2026-10-19T11:45:00',
        'timeZone': 'Asia/Jerusalem',
      });
    });

    test('repeats weekly on its days until the semester ends', () {
      final until = DateTime(2027, 1, 22, 23, 59, 59).toUtc();
      String two(int v) => v.toString().padLeft(2, '0');
      final stamp =
          '${until.year}${two(until.month)}${two(until.day)}'
          'T${two(until.hour)}${two(until.minute)}${two(until.second)}Z';
      expect(body['recurrence'], [
        'RRULE:FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=$stamp',
      ]);
    });

    test('uses the closest Google colour and the reminder setting', () {
      expect(body['colorId'], '7'); // Peacock #039BE5
      expect(body['reminders'], {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': 15},
        ],
      });
    });

    test('links back to the schedule event', () {
      final private = body['extendedProperties']['private'] as Map;
      expect(private['rocisEventId'], lecture().id);
      expect(private['rocisHash'], isNotEmpty);
    });
  });

  test('a title that already names the course is kept as is', () {
    final body = build(
      lecture(title: 'Linear Algebra Midterm'),
      c: course,
      s: semester,
    );
    expect(body['summary'], 'Linear Algebra Midterm');
  });

  test('an untitled event falls back to its type', () {
    final body = build(
      lecture(title: ''),
      c: course,
      s: semester,
    );
    expect(body['summary'], 'Linear Algebra · Class');
  });

  test('without semester dates a class repeats with no end date', () {
    final body = build(lecture(), c: course);
    expect(body['recurrence'], ['RRULE:FREQ=WEEKLY;BYDAY=MO,WE']);
    expect((body['description'] as String).contains('Semester'), isFalse);
  });

  test('a one-off personal event keeps its date and shows its category', () {
    final body = build(
      ScheduleEvent(
        id: 'e2',
        courseId: '',
        title: 'Dentist',
        type: EventType.other,
        startTime: DateTime(2026, 11, 3, 16, 30),
        endTime: DateTime(2026, 11, 3, 17, 0),
        location: '',
        domain: EventDomain.personal,
      ),
    );
    expect(body['summary'], 'Dentist');
    expect(body.containsKey('location'), isFalse);
    expect(body.containsKey('recurrence'), isFalse);
    expect(body['start']['dateTime'], '2026-11-03T16:30:00');
    expect(
      body['description'],
      'Category: Personal\n\n— Synced from ROCIs Schedule',
    );
  });

  group('Google event ids', () {
    final valid = RegExp(r'^[a-v0-9]{5,1024}$');

    test('are valid for any schedule id, including imported ones', () {
      for (final id in [lecture().id, 'event-1@rocis.com', 'e2']) {
        expect(GoogleCalendarEventBuilder.googleEventId(id), matches(valid));
      }
    });

    test('are stable and distinct', () {
      expect(
        GoogleCalendarEventBuilder.googleEventId('a'),
        GoogleCalendarEventBuilder.googleEventId('a'),
      );
      expect(
        GoogleCalendarEventBuilder.googleEventId('a'),
        isNot(GoogleCalendarEventBuilder.googleEventId('b')),
      );
    });
  });

  test('the content hash changes only when the event changes', () {
    final a = build(lecture(), c: course, s: semester);
    final b = build(lecture(), c: course, s: semester);
    final c = build(
      lecture(notes: 'Moved'),
      c: course,
      s: semester,
    );
    String hash(Map<String, dynamic> body) =>
        body['extendedProperties']['private']['rocisHash'] as String;
    expect(hash(a), hash(b));
    expect(hash(a), isNot(hash(c)));
  });
}
