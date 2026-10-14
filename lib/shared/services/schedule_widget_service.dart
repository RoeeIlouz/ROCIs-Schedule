import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

class UpcomingOccurrence {
  final ScheduleEvent event;
  final Course? course;
  final DateTime startTime;
  final DateTime endTime;
  final bool isTomorrow;

  const UpcomingOccurrence({
    required this.event,
    this.course,
    required this.startTime,
    required this.endTime,
    required this.isTomorrow,
  });
}

class ScheduleWidgetService {
  /// Evaluates the next class or exam occurrence occurring today or tomorrow.
  /// Exposed for deterministic unit testing.
  @visibleForTesting
  static UpcomingOccurrence? findNextUpcomingOccurrence(
    List<ScheduleEvent> events,
    Map<String, Course> courses,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todayCandidates = <UpcomingOccurrence>[];
    final tomorrowCandidates = <UpcomingOccurrence>[];

    for (final event in events) {
      final course = courses[event.courseId];

      // 1. Check Today
      if (_occursOnDate(event, today)) {
        final start = DateTime(
          today.year,
          today.month,
          today.day,
          event.startTime.hour,
          event.startTime.minute,
        );
        final end = DateTime(
          today.year,
          today.month,
          today.day,
          event.endTime.hour,
          event.endTime.minute,
        );

        if (end.isAfter(now)) {
          todayCandidates.add(
            UpcomingOccurrence(
              event: event,
              course: course,
              startTime: start,
              endTime: end,
              isTomorrow: false,
            ),
          );
        }
      }

      // 2. Check Tomorrow
      if (_occursOnDate(event, tomorrow)) {
        final start = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          event.startTime.hour,
          event.startTime.minute,
        );
        final end = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          event.endTime.hour,
          event.endTime.minute,
        );

        tomorrowCandidates.add(
          UpcomingOccurrence(
            event: event,
            course: course,
            startTime: start,
            endTime: end,
            isTomorrow: true,
          ),
        );
      }
    }

    if (todayCandidates.isNotEmpty) {
      todayCandidates.sort((a, b) => a.startTime.compareTo(b.startTime));
      return todayCandidates.first;
    }

    if (tomorrowCandidates.isNotEmpty) {
      tomorrowCandidates.sort((a, b) => a.startTime.compareTo(b.startTime));
      return tomorrowCandidates.first;
    }

    return null;
  }

  static bool _occursOnDate(ScheduleEvent event, DateTime date) {
    if (!event.recurring) {
      return event.coversDay(date);
    }
    return event.daysOfWeek.contains(date.weekday % 7);
  }

  /// Syncs widget data to native Android/iOS home screen widgets via HomeWidget.
  static Future<void> updateScheduleWidget({
    required List<ScheduleEvent> events,
    required Map<String, Course> courses,
    DateTime? now,
  }) async {
    // Only native mobile platforms support home screen widgets
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      final current = now ?? DateTime.now();
      final upcoming = findNextUpcomingOccurrence(events, courses, current);

      if (upcoming != null) {
        final event = upcoming.event;
        final course = upcoming.course;
        final title = event.title.isNotEmpty ? event.title : (course?.name ?? 'Class');
        final subtitleParts = [
          if (course != null && course.name != title) course.name,
          if (event.location.isNotEmpty) event.location,
        ];
        final subtitle = subtitleParts.isNotEmpty
            ? subtitleParts.join(' • ')
            : (event.notes.isNotEmpty ? event.notes : '');

        final timeFormatted = upcoming.isTomorrow
            ? 'Tom. ${DateFormat.Hm().format(upcoming.startTime)}'
            : DateFormat.Hm().format(upcoming.startTime);

        final color = event.colorFor(course) ?? const Color(0xFF4F46E5);
        final hexColor = '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
        final header = event.type == EventType.exam
            ? 'EXAM'
            : (event.type == EventType.lab ? 'LAB' : 'NEXT CLASS');

        await HomeWidget.saveWidgetData<bool>('schedule_has_upcoming', true);
        await HomeWidget.saveWidgetData<String>('schedule_up_next_title', title);
        await HomeWidget.saveWidgetData<String>('schedule_up_next_subtitle', subtitle);
        await HomeWidget.saveWidgetData<String>('schedule_up_next_time', timeFormatted);
        await HomeWidget.saveWidgetData<String>('schedule_up_next_color', hexColor);
        await HomeWidget.saveWidgetData<String>('schedule_up_next_header', header);
      } else {
        await HomeWidget.saveWidgetData<bool>('schedule_has_upcoming', false);
        await HomeWidget.saveWidgetData<String>(
          'schedule_up_next_title',
          'No more classes today',
        );
        await HomeWidget.saveWidgetData<String>(
          'schedule_up_next_subtitle',
          "You're all caught up!",
        );
        await HomeWidget.saveWidgetData<String>('schedule_up_next_time', '--');
        await HomeWidget.saveWidgetData<String>('schedule_up_next_color', '#10B981');
        await HomeWidget.saveWidgetData<String>('schedule_up_next_header', 'SCHEDULE');
      }

      await HomeWidget.updateWidget(
        name: 'ScheduleWidgetProvider',
        androidName: 'ScheduleWidgetProvider',
      );
    } catch (e) {
      debugPrint('ScheduleWidgetService: Failed to update home widget: $e');
    }
  }

  /// Prompts the Android OS to pin the Schedule Widget to the home screen.
  static Future<bool> requestPinWidget() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      await HomeWidget.requestPinWidget(
        androidName: 'ScheduleWidgetProvider',
      );
      return true;
    } catch (e) {
      debugPrint('ScheduleWidgetService: Failed to request pin widget: $e');
      return false;
    }
  }
}
