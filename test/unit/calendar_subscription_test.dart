import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/calendar_subscription_service.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';

const _feed = '''
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:lec-1@afeka
SUMMARY;LANGUAGE=en:CS201 - Data Structures\\, Lecture
LOCATION:Room 402
DTSTART;TZID=Asia/Jerusalem:20261101T100000
DTEND;TZID=Asia/Jerusalem:20261101T120000
RRULE:FREQ=WEEKLY;BYDAY=SU
END:VEVENT
BEGIN:VEVENT
UID:exam-1@afeka
SUMMARY:CS201 - Final Exam
DTSTART:20261220T070000Z
DTEND:20261220T100000Z
END:VEVENT
BEGIN:VEVENT
UID:gone-1@afeka
SUMMARY:CS201 - Cancelled Tutorial
DTSTART:20261105T100000
DTEND:20261105T110000
STATUS:CANCELLED
END:VEVENT
END:VCALENDAR
''';

void main() {
  group('Subscription parsing', () {
    test('ids are stable across parses and use the prefix', () {
      final a = IcsImportService.parseIcsContent(_feed, idPrefix: 'sub_');
      final b = IcsImportService.parseIcsContent(_feed, idPrefix: 'sub_');

      expect(a.events.map((e) => e.id), b.events.map((e) => e.id));
      expect(a.courses.map((c) => c.id), b.courses.map((c) => c.id));
      expect(a.events.every((e) => e.id.startsWith('sub_e_')), isTrue);
      expect(a.courses.every((c) => c.id.startsWith('sub_c_')), isTrue);
      expect(a.events.map((e) => e.id).toSet().length, a.events.length);
    });

    test('without a prefix ids stay random (one-off import)', () {
      final a = IcsImportService.parseIcsContent(_feed);
      final b = IcsImportService.parseIcsContent(_feed);
      expect(a.events.first.id, isNot(b.events.first.id));
    });

    test('skips cancelled events', () {
      final result = IcsImportService.parseIcsContent(_feed, idPrefix: 'sub_');
      expect(result.events.length, 2);
      expect(result.events.any((e) => e.title.contains('Cancelled')), isFalse);
    });

    test('reads properties that carry parameters and unescapes text', () {
      final result = IcsImportService.parseIcsContent(_feed, idPrefix: 'sub_');
      final lecture = result.events.firstWhere((e) => e.recurring);

      expect(lecture.title, 'CS201 - Data Structures, Lecture');
      expect(lecture.startTime, DateTime(2026, 11, 1, 10));
      expect(lecture.daysOfWeek, [0]); // Sunday
    });

    test('converts UTC times to the device time zone', () {
      final result = IcsImportService.parseIcsContent(_feed, idPrefix: 'sub_');
      final exam = result.events.firstWhere((e) => e.type == EventType.exam);

      expect(exam.startTime, DateTime.utc(2026, 12, 20, 7).toLocal());
      expect(exam.endTime, DateTime.utc(2026, 12, 20, 10).toLocal());
    });
  });

  group('CalendarSubscriptionService.normalizeUrl', () {
    test('reads webcal links over https', () {
      expect(
        CalendarSubscriptionService.normalizeUrl(' webcal://x.example/a.ics ')
            .toString(),
        'https://x.example/a.ics',
      );
      expect(
        CalendarSubscriptionService.normalizeUrl('WEBCALS://x.example/a.ics')
            .toString(),
        'https://x.example/a.ics',
      );
    });

    test('keeps http(s) and rejects everything else', () {
      expect(
        CalendarSubscriptionService.normalizeUrl('https://x.example/a.ics'),
        isNotNull,
      );
      expect(CalendarSubscriptionService.normalizeUrl(''), isNull);
      expect(CalendarSubscriptionService.normalizeUrl('not a url'), isNull);
      expect(
        CalendarSubscriptionService.normalizeUrl('ftp://x.example/a.ics'),
        isNull,
      );
      expect(CalendarSubscriptionService.normalizeUrl('https://'), isNull);
    });
  });

  group('CalendarSubscriptionService.fetch', () {
    Future<CalendarSyncFailure?> failureOf(http.Client client) async {
      try {
        await CalendarSubscriptionService.fetch(
          'https://x.example/a.ics',
          client: client,
        );
      } on CalendarSyncException catch (e) {
        return e.failure;
      }
      return null;
    }

    test('parses a good feed (UTF-8 Hebrew titles survive)', () async {
      final body = _feed.replaceFirst('Final Exam', 'מבחן סופי');
      final client = MockClient(
        (_) async => http.Response.bytes(utf8.encode(body), 200),
      );
      final result = await CalendarSubscriptionService.fetch(
        'webcal://x.example/a.ics',
        client: client,
      );
      expect(result.events.length, 2);
      expect(result.events.any((e) => e.title.contains('מבחן סופי')), isTrue);
    });

    test('maps failures', () async {
      expect(
        await failureOf(MockClient((_) async => http.Response('', 404))),
        CalendarSyncFailure.network,
      );
      expect(
        await failureOf(
          MockClient((_) async => throw http.ClientException('offline')),
        ),
        CalendarSyncFailure.network,
      );
      expect(
        await failureOf(
          MockClient((_) async => http.Response('<html></html>', 200)),
        ),
        CalendarSyncFailure.notCalendar,
      );
      expect(
        await failureOf(
          MockClient(
            (_) async => http.Response(
              'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR',
              200,
            ),
          ),
        ),
        CalendarSyncFailure.empty,
      );
    });

    test('rejects an invalid url before any request', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('', 200);
      });
      final failure = await (() async {
        try {
          await CalendarSubscriptionService.fetch('nope', client: client);
        } on CalendarSyncException catch (e) {
          return e.failure;
        }
        return null;
      })();
      expect(failure, CalendarSyncFailure.invalidUrl);
      expect(called, isFalse);
    });
  });
}
