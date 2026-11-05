import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/assignments/assignment_reminder_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'dart:ui';

Assignment _a(String title, DateTime due, {bool done = false}) => Assignment(
  id: title,
  courseId: 'c1',
  title: title,
  dueDate: due,
  isCompleted: done,
);

void main() {
  final en = AppLocalizations(const Locale('en')).translate;
  // Wednesday 2026-11-04, 08:00: today's 09:00 is still ahead.
  final now = DateTime(2026, 11, 4, 8);

  List<AssignmentReminder> plan(List<Assignment> list, [DateTime? at]) =>
      AssignmentReminderService.plan(
        assignments: list,
        now: at ?? now,
        translate: en,
      );

  test('nothing pending means no reminders', () {
    expect(plan([]), isEmpty);
    expect(plan([_a('Done', DateTime(2026, 11, 9), done: true)]), isEmpty);
  });

  test('one reminder per day at 09:00 for the window', () {
    final r = plan([_a('Problem set', DateTime(2026, 11, 9))]);
    expect(r.length, AssignmentReminderService.windowDays);
    expect(r.first.when, DateTime(2026, 11, 4, 9));
    expect(r[1].when, DateTime(2026, 11, 5, 9));
    expect(r.map((e) => e.id).toSet().length, r.length);
  });

  test('today 09:00 already passed starts tomorrow', () {
    final r = plan([
      _a('Problem set', DateTime(2026, 11, 9)),
    ], DateTime(2026, 11, 4, 10));
    expect(r.first.when, DateTime(2026, 11, 5, 9));
    expect(r.length, AssignmentReminderService.windowDays - 1);
  });

  test('text counts down to the due day then turns overdue', () {
    final r = plan([_a('Problem set', DateTime(2026, 11, 6, 23))]);
    expect(r[0].body, 'Problem set is due in 2 days');
    expect(r[1].body, 'Problem set is due tomorrow');
    expect(r[2].body, 'Problem set is due today');
    expect(r[3].body, 'Problem set is overdue');
    expect(r[0].title, '1 unfinished assignment');
  });

  test('several assignments lead with the most urgent and show the rest', () {
    final r = plan([
      _a('Later', DateTime(2026, 11, 20)),
      _a('Soon', DateTime(2026, 11, 5)),
      _a('Mid', DateTime(2026, 11, 10)),
      _a('Finished', DateTime(2026, 11, 4), done: true),
    ]);
    expect(r.first.title, '3 unfinished assignments');
    expect(r.first.body, startsWith('Soon is due tomorrow'));
    expect(r.first.body, contains('(+2 more)'));
  });
}
