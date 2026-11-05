import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/services/notification_service.dart';

/// One scheduled "you still have unfinished assignments" notice.
class AssignmentReminder {
  final int id;
  final DateTime when;
  final String title;
  final String body;

  const AssignmentReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });
}

/// Plans and schedules the daily unfinished-assignments reminder.
///
/// Notifications can't recompute their text, so a rolling window of one
/// notice per day is scheduled and rebuilt whenever the assignments, the
/// setting or the language change (and on every app start).
class AssignmentReminderService {
  /// How many days ahead are scheduled.
  static const int windowDays = 14;

  /// Local time of day the reminder fires.
  static const int hour = 9;

  /// Notification ids used by the window: base .. base + windowDays - 1.
  static const int idBase = 7300000;

  String? _lastSignature;
  List<Assignment> _lastAssignments = const [];
  bool _lastEnabled = false;
  Locale? _lastLocale;

  /// The reminders for [pending] assignments, one per day from [now].
  /// Finished assignments never remind; overdue ones keep reminding.
  static List<AssignmentReminder> plan({
    required List<Assignment> assignments,
    required DateTime now,
    required String Function(String key) translate,
  }) {
    final pending = assignments.where((a) => !a.isCompleted).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    if (pending.isEmpty) return const [];

    String fill(String key, Map<String, String> values) {
      var text = translate(key);
      values.forEach((k, v) => text = text.replaceAll('{$k}', v));
      return text;
    }

    final plans = <AssignmentReminder>[];
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < windowDays; i++) {
      final day = DateTime(today.year, today.month, today.day + i);
      final when = DateTime(day.year, day.month, day.day, hour);
      if (!when.isAfter(now)) continue;

      final next = pending.first;
      final dueDay = DateTime(
        next.dueDate.year,
        next.dueDate.month,
        next.dueDate.day,
      );
      final daysLeft = dueDay.difference(day).inDays;

      final String due;
      if (daysLeft < 0) {
        due = fill('assignment_reminder_overdue', {'title': next.title});
      } else if (daysLeft == 0) {
        due = fill('assignment_reminder_today', {'title': next.title});
      } else if (daysLeft == 1) {
        due = fill('assignment_reminder_tomorrow', {'title': next.title});
      } else {
        due = fill('assignment_reminder_in_days', {
          'title': next.title,
          'days': '$daysLeft',
        });
      }

      final more = pending.length - 1;
      plans.add(
        AssignmentReminder(
          id: idBase + i,
          when: when,
          title: pending.length == 1
              ? translate('assignment_reminder_title_one')
              : fill('assignment_reminder_title', {
                  'count': '${pending.length}',
                }),
          body: more > 0
              ? '$due  ${fill('assignment_reminder_more', {'count': '$more'})}'
              : due,
        ),
      );
    }
    return plans;
  }

  /// Rebuilds the schedule. [enabled] false (or nothing pending) clears it.
  Future<void> sync({
    required List<Assignment> assignments,
    required bool enabled,
    Locale? locale,
  }) async {
    _lastAssignments = assignments;
    _lastEnabled = enabled;
    _lastLocale = locale;
    final l10n = AppLocalizations(_supported(locale));
    final plans = enabled
        ? plan(
            assignments: assignments,
            now: DateTime.now(),
            translate: l10n.translate,
          )
        : const <AssignmentReminder>[];

    // Skip the work (and the notification churn) when nothing changed today.
    final today = DateTime.now();
    final signature =
        '${today.year}-${today.month}-${today.day}|'
        '${plans.map((p) => '${p.id}${p.title}${p.body}').join('|')}';
    if (signature == _lastSignature) return;
    _lastSignature = signature;

    final notifications = NotificationService();
    for (var i = 0; i < windowDays; i++) {
      await notifications.cancelReminder(idBase + i);
    }
    for (final p in plans) {
      await notifications.scheduleAssignmentDigest(
        id: p.id,
        title: p.title,
        body: p.body,
        when: p.when,
      );
    }
  }

  /// Schedules again from the last inputs, e.g. after something cleared every
  /// notification.
  Future<void> resync() {
    _lastSignature = null;
    return sync(
      assignments: _lastAssignments,
      enabled: _lastEnabled,
      locale: _lastLocale,
    );
  }

  /// The app language, or the device language when it is on automatic.
  static Locale _supported(Locale? chosen) {
    final locale = chosen ?? PlatformDispatcher.instance.locale;
    for (final s in AppLocalizations.supportedLocales) {
      if (s.languageCode == locale.languageCode) return s;
    }
    return const Locale('en', '');
  }
}
