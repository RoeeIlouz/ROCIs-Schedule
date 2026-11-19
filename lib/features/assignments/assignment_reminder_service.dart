import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Plans and schedules the daily unfinished-assignments reminder and the
/// optional per-assignment due date countdown.
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

  /// Countdown notices go out this many days before the due day (0 = the
  /// day itself), at [hour].
  static const List<int> countdownDays = [7, 2, 1, 0];

  /// Countdown notices further ahead than this are left for a later sync,
  /// to keep the number of scheduled alarms small.
  static const int countdownHorizonDays = 30;

  /// Countdown ids: base + slot * countdownDays.length + milestone.
  static const int countdownIdBase = 7400000;
  static const int _countdownSlots = 500000;
  static const String _countdownIdsKey = 'due_countdown_scheduled_ids';

  String? _lastSignature;
  List<Assignment> _lastAssignments = const [];
  bool _lastEnabled = false;
  bool _lastCountdown = false;
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

  /// Stable notification id for [assignmentId]'s [milestone] (an index into
  /// [countdownDays]). FNV-1a, since String.hashCode isn't guaranteed stable.
  static int countdownId(String assignmentId, int milestone) {
    var h = 0x811c9dc5;
    for (final unit in assignmentId.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return countdownIdBase +
        (h % _countdownSlots) * countdownDays.length +
        milestone;
  }

  /// The "due in N days" notices for unfinished [assignments] that are still
  /// ahead of [now], before the deadline itself, and within the horizon.
  static List<AssignmentReminder> planCountdown({
    required List<Assignment> assignments,
    required DateTime now,
    required String Function(String key) translate,
  }) {
    final horizon = now.add(const Duration(days: countdownHorizonDays));
    final plans = <AssignmentReminder>[];
    for (final a in assignments) {
      if (a.isCompleted) continue;
      // A date picked without a time is stored at midnight: due that day.
      final d = a.dueDate;
      final deadline = d.hour == 0 && d.minute == 0 && d.second == 0
          ? DateTime(d.year, d.month, d.day, 23, 59)
          : d;
      for (var m = 0; m < countdownDays.length; m++) {
        final days = countdownDays[m];
        final when = DateTime(
          a.dueDate.year,
          a.dueDate.month,
          a.dueDate.day - days,
          hour,
        );
        if (!when.isAfter(now) ||
            !when.isBefore(deadline) ||
            when.isAfter(horizon)) {
          continue;
        }
        final String key;
        if (days == 0) {
          key = 'due_countdown_today';
        } else if (days == 1) {
          key = 'due_countdown_tomorrow';
        } else if (days == 7) {
          key = 'due_countdown_week';
        } else {
          key = 'due_countdown_days';
        }
        plans.add(
          AssignmentReminder(
            id: countdownId(a.id, m),
            when: when,
            title: translate('due_countdown_title'),
            body: translate(
              key,
            ).replaceAll('{title}', a.title).replaceAll('{days}', '$days'),
          ),
        );
      }
    }
    return plans;
  }

  /// Rebuilds the schedule. [enabled] false (or nothing pending) clears the
  /// daily reminder; [countdown] false clears the due date countdown.
  Future<void> sync({
    required List<Assignment> assignments,
    required bool enabled,
    bool countdown = false,
    Locale? locale,
  }) async {
    _lastAssignments = assignments;
    _lastEnabled = enabled;
    _lastCountdown = countdown;
    _lastLocale = locale;
    final l10n = AppLocalizations(_supported(locale));
    final now = DateTime.now();
    final plans = enabled
        ? plan(assignments: assignments, now: now, translate: l10n.translate)
        : const <AssignmentReminder>[];
    final countdownPlans = countdown
        ? planCountdown(
            assignments: assignments,
            now: now,
            translate: l10n.translate,
          )
        : const <AssignmentReminder>[];

    // Skip the work (and the notification churn) when nothing changed today.
    final all = [...plans, ...countdownPlans];
    final signature =
        '${now.year}-${now.month}-${now.day}|'
        '${all.map((p) => '${p.id}${p.when}${p.title}${p.body}').join('|')}';
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
    await _syncCountdown(notifications, countdownPlans);
  }

  /// Cancels countdown notices no longer planned (remembered across app
  /// starts) and schedules the current ones.
  Future<void> _syncCountdown(
    NotificationService notifications,
    List<AssignmentReminder> plans,
  ) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('AssignmentReminderService: prefs unavailable: $e');
    }
    final previous = (prefs?.getStringList(_countdownIdsKey) ?? const [])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
    final current = plans.map((p) => p.id).toSet();
    for (final id in previous.difference(current)) {
      await notifications.cancelReminder(id);
    }
    for (final p in plans) {
      await notifications.scheduleDueCountdown(
        id: p.id,
        title: p.title,
        body: p.body,
        when: p.when,
      );
    }
    await prefs?.setStringList(
      _countdownIdsKey,
      current.map((id) => '$id').toList(),
    );
  }

  /// Schedules again from the last inputs, e.g. after something cleared every
  /// notification.
  Future<void> resync() {
    _lastSignature = null;
    return sync(
      assignments: _lastAssignments,
      enabled: _lastEnabled,
      countdown: _lastCountdown,
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
