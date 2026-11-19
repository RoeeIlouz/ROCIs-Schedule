import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/assignments/quick_add_parser.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

Course _c(String id, String name, String code) => Course(
  id: id,
  name: name,
  code: code,
  instructor: '',
  color: Colors.blue,
  credits: 3,
);

void main() {
  // Wednesday 2026-11-04.
  final now = DateTime(2026, 11, 4, 10);
  final courses = [
    _c('calc', 'Calculus 1', 'MATH101'),
    _c('phys', 'Physics', 'PHY1'),
    _c('heb', 'חדו"א 2', ''),
    _c('algo', 'Algorithms', 'CS201'),
  ];

  QuickAddParse p(String text, {bool monthFirst = false}) =>
      QuickAddParser.parse(text, courses, now, monthFirst: monthFirst);

  DateTime end(int y, int m, int d) => DateTime(y, m, d, 23, 59);

  test('course, title and weekday from one line', () {
    final r = p('calc homework friday');
    expect(r.courseId, 'calc');
    expect(r.title, 'homework');
    expect(r.dueDate, end(2026, 11, 6));
  });

  test('connector before the date is dropped', () {
    final r = p('Lab report due tomorrow');
    expect(r.title, 'Lab report');
    expect(r.dueDate, end(2026, 11, 5));
    expect(r.courseId, isNull);
  });

  test('today\'s weekday means next week', () {
    expect(p('essay wednesday').dueDate, end(2026, 11, 11));
  });

  test('relative phrases', () {
    expect(p('hw in 3 days').dueDate, end(2026, 11, 7));
    expect(p('hw next week').dueDate, end(2026, 11, 11));
    expect(p('hw in 2 weeks').dueDate, end(2026, 11, 18));
    expect(p('hw next mon').dueDate, end(2026, 11, 9));
  });

  test('explicit dates, day first unless US', () {
    expect(p('hw 10/12').dueDate, end(2026, 12, 10));
    expect(p('hw 12/10', monthFirst: true).dueDate, end(2026, 12, 10));
    // Already past this year: next year.
    expect(p('hw 1.3').dueDate, end(2027, 3, 1));
    expect(p('hw 31/2').dueDate, isNull);
  });

  test('course code matches', () {
    expect(p('cs201 project').courseId, 'algo');
    expect(p('phy1 lab').courseId, 'phys');
  });

  test('Hebrew course with quote marks and a prefix, Hebrew dates', () {
    final r = p('תרגיל בחדוא מחר');
    expect(r.courseId, 'heb');
    expect(r.title, 'תרגיל');
    expect(r.dueDate, end(2026, 11, 5));

    expect(p('תרגיל חדו״א עד יום חמישי').dueDate, end(2026, 11, 5));
    expect(p('עבודה בשני').dueDate, end(2026, 11, 9));
    expect(p('עבודה בעוד שבוע').dueDate, end(2026, 11, 11));
    expect(p('עבודה בעוד 5 ימים').dueDate, end(2026, 11, 9));
    expect(p('עבודה מחרתיים').dueDate, end(2026, 11, 6));
  });

  test('"שני" alone is not Monday', () {
    expect(p('תרגיל שני').dueDate, isNull);
  });

  test('ambiguous course words are left alone', () {
    final two = [_c('a', 'Physics 1', ''), _c('b', 'Physics 2', '')];
    final r = QuickAddParser.parse('physics hw', two, now);
    expect(r.courseId, isNull);
    expect(r.title, 'physics hw');
  });

  test('the course word stays the title when nothing else is left', () {
    final r = p('physics friday');
    expect(r.courseId, 'phys');
    expect(r.title, 'physics');
  });

  test('plain text keeps everything', () {
    final r = p('Read chapter 4');
    expect(r.title, 'Read chapter 4');
    expect(r.courseId, isNull);
    expect(r.dueDate, isNull);
  });
}
