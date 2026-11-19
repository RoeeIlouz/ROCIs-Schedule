import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/assignments/assignment_reminder_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';

void main() {
  // Wednesday 2026-11-04, 08:00.
  final now = DateTime(2026, 11, 4, 8);
  final en = AppLocalizations(const Locale('en')).translate;

  Assignment due(DateTime d, {bool done = false, String id = 'a1'}) =>
      Assignment(
        id: id,
        courseId: 'c1',
        title: 'Essay',
        dueDate: d,
        isCompleted: done,
      );

  group('automatic priority', () {
    test('is the default for new assignments', () {
      expect(due(DateTime(2026, 12, 1)).autoPriority, isTrue);
    });

    test('low, then medium within a week, then high within 2 days', () {
      expect(
        due(DateTime(2026, 11, 20)).effectivePriority(now),
        AssignmentPriority.low,
      );
      expect(
        due(DateTime(2026, 11, 11, 23, 59)).effectivePriority(now),
        AssignmentPriority.medium,
      );
      expect(
        due(DateTime(2026, 11, 7)).effectivePriority(now),
        AssignmentPriority.medium,
      );
      expect(
        due(DateTime(2026, 11, 6)).effectivePriority(now),
        AssignmentPriority.high,
      );
      expect(
        due(DateTime(2026, 11, 1)).effectivePriority(now),
        AssignmentPriority.high,
      );
    });

    test('a picked priority is kept', () {
      final a = Assignment(
        courseId: 'c1',
        title: 'x',
        dueDate: DateTime(2026, 11, 5),
        priority: AssignmentPriority.low,
        autoPriority: false,
      );
      expect(a.effectivePriority(now), AssignmentPriority.low);
    });

    test('round-trips through Firestore and SQLite maps', () {
      final a = due(DateTime(2026, 11, 20)).copyWith(autoPriority: false);
      expect(Assignment.fromMap(a.toMap()).autoPriority, isFalse);
      expect(Assignment.fromMap(a.toDbMap()).autoPriority, isFalse);
      final b = due(DateTime(2026, 11, 20));
      expect(Assignment.fromMap(b.toMap()).autoPriority, isTrue);
      expect(Assignment.fromMap(b.toDbMap()).autoPriority, isTrue);
    });

    test('old records: only the untouched medium default becomes auto', () {
      Map<String, dynamic> old(int priority) => {
        'id': 'o',
        'courseId': 'c1',
        'title': 't',
        'dueDate': DateTime(2026, 11, 20).toIso8601String(),
        'isCompleted': 0,
        'priority': priority,
      };
      expect(Assignment.fromMap(old(1)).autoPriority, isTrue);
      expect(Assignment.fromMap(old(0)).autoPriority, isFalse);
      expect(Assignment.fromMap(old(2)).autoPriority, isFalse);
    });
  });

  group('due date countdown', () {
    List<AssignmentReminder> plan(List<Assignment> list) =>
        AssignmentReminderService.planCountdown(
          assignments: list,
          now: now,
          translate: en,
        );

    test('1 week, 2 days, 1 day and the day itself at 09:00', () {
      final r = plan([due(DateTime(2026, 11, 20, 23, 59))]);
      expect(r.map((e) => e.when).toList(), [
        DateTime(2026, 11, 13, 9),
        DateTime(2026, 11, 18, 9),
        DateTime(2026, 11, 19, 9),
        DateTime(2026, 11, 20, 9),
      ]);
      expect(r.first.body, 'Essay is due in 1 week');
      expect(r[1].body, 'Essay is due in 2 days');
      expect(r[2].body, 'Essay is due tomorrow');
      expect(r[3].body, 'Essay is due today');
    });

    test('skips passed milestones and ones after the deadline', () {
      // Due Friday 08:00: the 1-week notice is past, and Friday 09:00 is
      // after the deadline.
      final r = plan([due(DateTime(2026, 11, 6, 8))]);
      expect(r.map((e) => e.when).toList(), [
        DateTime(2026, 11, 4, 9),
        DateTime(2026, 11, 5, 9),
      ]);
    });

    test('a date without a time still gets the "due today" notice', () {
      final r = plan([due(DateTime(2026, 11, 6))]);
      expect(r.last.when, DateTime(2026, 11, 6, 9));
      expect(r.last.body, 'Essay is due today');
    });

    test('finished assignments and far-off notices are left out', () {
      expect(plan([due(DateTime(2026, 11, 20), done: true)]), isEmpty);
      expect(plan([due(DateTime(2027, 3, 1))]), isEmpty);
    });

    test('ids are stable, distinct and clear of the daily reminder', () {
      final a = plan([
        due(DateTime(2026, 11, 20, 23), id: 'x'),
        due(DateTime(2026, 11, 20, 23), id: 'y'),
      ]);
      final b = plan([
        due(DateTime(2026, 11, 20, 23), id: 'x'),
        due(DateTime(2026, 11, 20, 23), id: 'y'),
      ]);
      expect(a.map((e) => e.id), b.map((e) => e.id));
      expect(a.map((e) => e.id).toSet().length, a.length);
      for (final r in a) {
        expect(
          r.id,
          greaterThanOrEqualTo(AssignmentReminderService.countdownIdBase),
        );
      }
    });
  });
}
