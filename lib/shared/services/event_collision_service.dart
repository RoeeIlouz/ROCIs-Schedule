import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

class EventCollisionService {
  /// Determines if two events overlap in both day-of-occurrence and time.
  static bool doEventsOverlap(ScheduleEvent a, ScheduleEvent b) {
    // 1. Day comparison
    bool daysOverlap = false;

    if (a.recurring && b.recurring) {
      // Both recurring: overlap if daysOfWeek set has an intersection
      daysOverlap = a.daysOfWeek.any((d) => b.daysOfWeek.contains(d));
    } else if (a.recurring && !b.recurring) {
      // a is recurring, b is one-time: overlap if b's weekday is in a.daysOfWeek
      final bDayOfWeek = b.startTime.weekday % 7;
      daysOverlap = a.daysOfWeek.contains(bDayOfWeek);
    } else if (!a.recurring && b.recurring) {
      // a is one-time, b is recurring: overlap if a's weekday is in b.daysOfWeek
      final aDayOfWeek = a.startTime.weekday % 7;
      daysOverlap = b.daysOfWeek.contains(aDayOfWeek);
    } else {
      // Both one-time: overlap only if on the exact same calendar day
      daysOverlap = DateUtils.isSameDay(a.startTime, b.startTime);
    }

    if (!daysOverlap) return false;

    // 2. Time-of-day interval comparison (in minutes from midnight)
    final aStart = a.startTime.hour * 60 + a.startTime.minute;
    final aEnd = a.endTime.hour * 60 + a.endTime.minute;
    final bStart = b.startTime.hour * 60 + b.startTime.minute;
    final bEnd = b.endTime.hour * 60 + b.endTime.minute;

    // Two intervals [startA, endA) and [startB, endB) overlap if startA < endB && endA > startB
    return aStart < bEnd && aEnd > bStart;
  }

  /// Finds all existing events that collide with [candidate].
  /// Optionally ignores an event by [excludeEventId] (useful when editing).
  static List<ScheduleEvent> findConflicts({
    required ScheduleEvent candidate,
    required List<ScheduleEvent> existingEvents,
    String? excludeEventId,
  }) {
    return existingEvents.where((event) {
      if (excludeEventId != null && event.id == excludeEventId) return false;
      if (candidate.id.isNotEmpty && event.id == candidate.id) return false;
      return doEventsOverlap(candidate, event);
    }).toList();
  }

  /// Returns true if any conflicting event involves a collision between
  /// Work and Academic domains (e.g. Work shift colliding with Class/Exam).
  static bool hasWorkAcademicConflict({
    required ScheduleEvent candidate,
    required List<ScheduleEvent> existingEvents,
    String? excludeEventId,
  }) {
    final conflicts = findConflicts(
      candidate: candidate,
      existingEvents: existingEvents,
      excludeEventId: excludeEventId,
    );

    return conflicts.any((c) {
      final isCandidateWork = candidate.domain == EventDomain.work;
      final isCandidateAcademic = candidate.domain == EventDomain.academic;
      final isConfWork = c.domain == EventDomain.work;
      final isConfAcademic = c.domain == EventDomain.academic;

      return (isCandidateWork && isConfAcademic) ||
          (isCandidateAcademic && isConfWork);
    });
  }

  /// Formats a readable title and time range for a conflicting event.
  static String formatConflictSummary(
    ScheduleEvent conflict, {
    Course? course,
  }) {
    final title = conflict.title.isNotEmpty
        ? conflict.title
        : (course?.name ?? 'Event');
    final timeStr =
        '${DateFormat.Hm().format(conflict.startTime)} - ${DateFormat.Hm().format(conflict.endTime)}';
    return '$title ($timeStr)';
  }
}
