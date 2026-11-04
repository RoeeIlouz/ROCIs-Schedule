import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';
import 'package:rocis_schedule/features/calendar_sync/services/feed_differ.dart';

SyncKeyed k(
  String course,
  DateTime start, {
  EntryKind kind = EntryKind.lecture,
  String location = 'room 1',
  String lecturer = 'מר א',
  bool cancelled = false,
}) {
  final entry = FeedEntry(
    uid: 'x',
    summary: course,
    location: location,
    start: start,
    end: start.add(const Duration(hours: 2)),
  );
  final info = Classified(
    courseName: course,
    lecturer: lecturer,
    kind: kind,
    cancelled: cancelled,
  );
  return SyncKeyed(FeedDiffer.keyFor(info, entry), entry, info);
}

void main() {
  final mon9 = DateTime(2026, 11, 9, 9);
  final tue9 = DateTime(2026, 11, 10, 9);

  test('identical feeds give no changes', () {
    expect(FeedDiffer.diff([k('א', mon9)], [k('א', mon9)]), isEmpty);
  });

  test('new entry is added', () {
    final r = FeedDiffer.diff([k('א', mon9)], [k('א', mon9), k('ב', tue9)]);
    expect(r.single.kind, ChangeKind.added);
    expect(r.single.course, 'ב');
  });

  test('missing entry is removed', () {
    final r = FeedDiffer.diff([k('א', mon9), k('ב', tue9)], [k('א', mon9)]);
    expect(r.single.kind, ChangeKind.removed);
    expect(r.single.course, 'ב');
  });

  test('same course and kind at a different time is one moved change', () {
    final r = FeedDiffer.diff([k('א', mon9)], [k('א', tue9)]);
    expect(r, hasLength(1));
    expect(r.single.kind, ChangeKind.moved);
    expect(r.single.when, tue9);
    expect(r.single.detail, mon9.toIso8601String());
  });

  test('room change reports old -> new', () {
    final r = FeedDiffer.diff(
      [k('א', mon9, location: '101')],
      [k('א', mon9, location: '202')],
    );
    expect(r.single.kind, ChangeKind.roomChanged);
    expect(r.single.detail, '101 -> 202');
  });

  test('lecturer change is reported', () {
    final r = FeedDiffer.diff(
      [k('א', mon9, lecturer: 'מר א')],
      [k('א', mon9, lecturer: 'מר ב')],
    );
    expect(r.single.kind, ChangeKind.lecturerChanged);
  });

  test('cancel marker appearing/disappearing', () {
    final a = k('א', mon9);
    final b = k('א', mon9, cancelled: true);
    expect(FeedDiffer.diff([a], [b]).single.kind, ChangeKind.cancelled);
    expect(FeedDiffer.diff([b], [a]).single.kind, ChangeKind.restored);
  });

  test('two entries with the same key survive and are stable', () {
    final dup = [k('א', mon9), k('א', mon9)];
    expect(FeedDiffer.diff(dup, dup), isEmpty);
    final r = FeedDiffer.diff([k('א', mon9)], dup);
    expect(r.single.kind, ChangeKind.added);
  });

  test('empty current with non-empty previous throws FeedLooksEmpty', () {
    expect(
      () => FeedDiffer.diff([k('א', mon9)], []),
      throwsA(isA<FeedLooksEmpty>()),
    );
  });

  test('empty previous (first run) with entries is not an error', () {
    expect(FeedDiffer.diff([], [k('א', mon9)]), isNotEmpty);
  });
}
