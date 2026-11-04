import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/calendar_sync/services/feed_parser.dart';

void main() {
  final ics = File('test/features/calendar_sync/fixtures/synthetic_feed.ics')
      .readAsStringSync();

  test('parses all VEVENTs', () {
    expect(FeedParser.parse(ics), hasLength(5));
  });

  test('unfolds continuation lines', () {
    final e = FeedParser.parse(ics).firstWhere((e) => e.uid == 'a3');
    expect(e.description, contains('תרגול'));
    expect(e.description, contains('חדר לימוד'));
  });

  test('reads TZID local times as wall-clock DateTime', () {
    final e = FeedParser.parse(ics).first;
    expect(e.start, DateTime(2026, 10, 25, 9, 0));
    expect(e.end, DateTime(2026, 10, 25, 10, 50));
  });

  test('marks TRANSP:TRANSPARENT entries transparent', () {
    final list = FeedParser.parse(ics);
    expect(list.firstWhere((e) => e.uid == 'a5').transparent, isTrue);
    expect(list.firstWhere((e) => e.uid == 'a1').transparent, isFalse);
  });

  test('looksLikeCalendar rejects html and accepts calendars', () {
    expect(FeedParser.looksLikeCalendar('<html>login</html>'), isFalse);
    expect(FeedParser.looksLikeCalendar('BEGIN:VCALENDAR\nEND:VCALENDAR'),
        isTrue);
    expect(
        FeedParser.looksLikeCalendar('\uFEFF  \nBEGIN:VCALENDAR\nEND:VCALENDAR'),
        isTrue);
  });

  test('garbage parses to empty list', () {
    expect(FeedParser.parse('not a calendar'), isEmpty);
    expect(FeedParser.parse(''), isEmpty);
  });
}
