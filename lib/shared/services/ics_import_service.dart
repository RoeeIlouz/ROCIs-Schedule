import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

class IcsImportResult {
  final List<Course> courses;
  final List<ScheduleEvent> events;

  IcsImportResult({required this.courses, required this.events});
}

class IcsImportService {
  static const List<Color> _palette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Rose
    Color(0xFF8B5CF6), // Violet
    Color(0xFF14B8A6), // Teal
    Color(0xFFEC4899), // Pink
  ];

  /// Parses [icsContent] into courses and events.
  ///
  /// By default every event and course gets a random id (a one-off import).
  /// With [idPrefix], ids are derived from the calendar's own event UIDs, so
  /// parsing the same calendar again yields the same ids. A live calendar
  /// sync relies on that to update items in place instead of duplicating.
  static IcsImportResult parseIcsContent(
    String icsContent, {
    String? idPrefix,
  }) {
    final coursesMap = <String, Course>{};
    final events = <ScheduleEvent>[];
    const uuid = Uuid();

    final lines = icsContent
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final unfoldedLines = <String>[];

    // Unfold multi-line entries (lines starting with space or tab)
    for (var line in lines) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          unfoldedLines.isNotEmpty) {
        unfoldedLines.last += line.substring(1);
      } else {
        unfoldedLines.add(line);
      }
    }

    bool inEvent = false;
    String summary = '';
    String location = '';
    String description = '';
    String dtStartStr = '';
    String dtEndStr = '';
    String rruleStr = '';
    String uid = '';
    String recurrenceId = '';
    bool cancelled = false;

    for (var rawLine in unfoldedLines) {
      final line = rawLine.trim();

      if (line == 'BEGIN:VEVENT') {
        inEvent = true;
        summary = '';
        location = '';
        description = '';
        dtStartStr = '';
        dtEndStr = '';
        rruleStr = '';
        uid = '';
        recurrenceId = '';
        cancelled = false;
      } else if (line == 'END:VEVENT') {
        inEvent = false;
        if (!cancelled && summary.isNotEmpty && dtStartStr.isNotEmpty) {
          var startTime = _parseDateTime(dtStartStr);
          var endTime = dtEndStr.isNotEmpty
              ? _parseDateTime(dtEndStr)
              : startTime.add(const Duration(hours: 1));

          final daysOfWeek = _parseDaysOfWeek(rruleStr, startTime);
          final isRecurring =
              rruleStr.contains('FREQ=WEEKLY') || daysOfWeek.isNotEmpty;

          // A date without a time (DTSTART;VALUE=DATE) is an all-day event;
          // its DTEND is the day after the last one.
          final allDay = !isRecurring && _isDateOnly(dtStartStr);
          if (allDay) {
            startTime = DateUtils.dateOnly(startTime);
            var lastDay = dtEndStr.isNotEmpty
                ? DateUtils.dateOnly(
                    _parseDateTime(dtEndStr),
                  ).subtract(const Duration(days: 1))
                : startTime;
            if (lastDay.isBefore(startTime)) lastDay = startTime;
            endTime = DateTime(
              lastDay.year,
              lastDay.month,
              lastDay.day,
              23,
              59,
            );
          }
          final eventType = _detectEventType(summary);

          final rawKey = _extractCourseKey(summary);
          final courseKey = rawKey.isNotEmpty
              ? rawKey
              : (summary.trim().isNotEmpty ? summary.trim() : 'Course');
          if (!coursesMap.containsKey(courseKey)) {
            final colorIndex = coursesMap.length % _palette.length;
            final courseCode = _extractCourseCode(summary);
            coursesMap[courseKey] = Course(
              id: idPrefix != null
                  ? '${idPrefix}c_${_stableHash(courseKey)}'
                  : 'c_${uuid.v4().substring(0, 8)}',
              name: courseKey,
              code: courseCode,
              instructor: description.isNotEmpty ? description : '',
              color: _palette[colorIndex],
              credits: 3,
            );
          }

          final course = coursesMap[courseKey]!;
          events.add(
            ScheduleEvent(
              id: idPrefix != null
                  ? '${idPrefix}e_${_stableHash(uid.isNotEmpty ? '$uid|$recurrenceId' : '$summary|$dtStartStr|$rruleStr')}'
                  : 'e_${uuid.v4().substring(0, 8)}',
              title: summary,
              courseId: course.id,
              type: eventType,
              startTime: startTime,
              endTime: endTime,
              location: location,
              daysOfWeek: daysOfWeek,
              recurring: isRecurring,
              notes: description,
              allDay: allDay,
            ),
          );
        }
      } else if (inEvent) {
        // "NAME;PARAM=x:value": parameters (LANGUAGE, TZID, VALUE) are
        // allowed on any property, so match on the bare name.
        final colon = _valueColon(line);
        if (colon == -1) continue;
        final name = line.substring(0, colon).split(';').first.toUpperCase();
        final value = line.substring(colon + 1);
        switch (name) {
          case 'SUMMARY':
            summary = _unescapeIcsText(value.trim());
          case 'LOCATION':
            location = _unescapeIcsText(value.trim());
          case 'DESCRIPTION':
            description = _unescapeIcsText(value.trim());
          case 'DTSTART':
            dtStartStr = value.trim();
          case 'DTEND':
            dtEndStr = value.trim();
          case 'RRULE':
            rruleStr = value.trim();
          case 'UID':
            uid = value.trim();
          case 'RECURRENCE-ID':
            recurrenceId = value.trim();
          case 'STATUS':
            cancelled = value.trim().toUpperCase() == 'CANCELLED';
        }
      }
    }

    return IcsImportResult(courses: coursesMap.values.toList(), events: events);
  }

  /// Index of the colon that separates a property's name and parameters
  /// from its value, ignoring colons inside quoted parameter values.
  static int _valueColon(String line) {
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        quoted = !quoted;
      } else if (ch == ':' && !quoted) {
        return i;
      }
    }
    return -1;
  }

  /// Reverses RFC 5545 TEXT escaping (see [escapeIcsText]).
  static String _unescapeIcsText(String value) => value.replaceAllMapped(
    RegExp(r'\\([\\;,nN])'),
    (m) => (m[1] == 'n' || m[1] == 'N') ? '\n' : m[1]!,
  );

  /// A short deterministic id fragment for [input]: the same text always
  /// gives the same fragment (UUID v5, which also works on web).
  static String _stableHash(String input) => const Uuid()
      .v5(Namespace.url.value, input)
      .replaceAll('-', '')
      .substring(0, 20);

  static bool _isDateOnly(String raw) =>
      !raw.contains('T') && raw.replaceAll('-', '').trim().length == 8;

  static DateTime _parseDateTime(String raw) {
    try {
      final clean = raw
          .replaceAll('Z', '')
          .replaceAll('-', '')
          .replaceAll(':', '');
      if (clean.length >= 8) {
        final year = int.parse(clean.substring(0, 4));
        final month = int.parse(clean.substring(4, 6));
        final day = int.parse(clean.substring(6, 8));
        int hour = 9;
        int minute = 0;
        int second = 0;

        if (clean.length >= 13 && clean.contains('T')) {
          final timePart = clean.substring(clean.indexOf('T') + 1);
          if (timePart.length >= 2) {
            hour = int.parse(timePart.substring(0, 2));
          }
          if (timePart.length >= 4) {
            minute = int.parse(timePart.substring(2, 4));
          }
          if (timePart.length >= 6) {
            second = int.parse(timePart.substring(4, 6));
          }
        }
        // A trailing Z means UTC; show it in the device's own time zone.
        if (raw.trim().endsWith('Z')) {
          return DateTime.utc(
            year,
            month,
            day,
            hour,
            minute,
            second,
          ).toLocal();
        }
        return DateTime(year, month, day, hour, minute, second);
      }
    } catch (_) {}
    return DateTime.now();
  }

  static List<int> _parseDaysOfWeek(String rrule, DateTime startTime) {
    final days = <int>[];
    if (rrule.contains('BYDAY=')) {
      final byDayIdx = rrule.indexOf('BYDAY=');
      final byDayPart = rrule.substring(byDayIdx + 6).split(';').first;
      for (var token in byDayPart.split(',')) {
        final code = token.replaceAll(RegExp(r'[^A-Z]'), '');
        switch (code) {
          case 'SU':
            days.add(0);
            break;
          case 'MO':
            days.add(1);
            break;
          case 'TU':
            days.add(2);
            break;
          case 'WE':
            days.add(3);
            break;
          case 'TH':
            days.add(4);
            break;
          case 'FR':
            days.add(5);
            break;
          case 'SA':
            days.add(6);
            break;
        }
      }
    } else if (rrule.contains('FREQ=WEEKLY')) {
      days.add(startTime.weekday % 7);
    }
    return days;
  }

  static EventType _detectEventType(String summary) {
    final lower = summary.toLowerCase();
    if (lower.contains('exam') ||
        lower.contains('midterm') ||
        lower.contains('final') ||
        lower.contains('test') ||
        lower.contains('quiz') ||
        lower.contains('מבחן')) {
      return EventType.exam;
    }
    if (lower.contains('lab') || lower.contains('מעבדה')) {
      return EventType.lab;
    }
    if (lower.contains('study') ||
        lower.contains('tutorial') ||
        lower.contains('recitation') ||
        lower.contains('תרגול')) {
      return EventType.study;
    }
    return EventType.classType;
  }

  static String _extractCourseKey(String summary) {
    if (summary.contains('-')) {
      return summary.split('-').first.trim();
    }
    if (summary.contains(':')) {
      return summary.split(':').first.trim();
    }
    return summary.trim();
  }

  static String _extractCourseCode(String summary) {
    final match = RegExp(r'([A-Z]{2,4}\s?\d{3,4})').firstMatch(summary);
    if (match != null) {
      return match.group(0)!;
    }
    final rawKey = _extractCourseKey(summary);
    if (rawKey.isNotEmpty) {
      return rawKey.length > 6
          ? rawKey.substring(0, 6).toUpperCase()
          : rawKey.toUpperCase();
    }
    return 'CRS';
  }

  /// Exports events as iCalendar. Recurring classes are bounded by their
  /// course's semester when [semesters] carry dates, instead of repeating
  /// forever from the date the class was created.
  static String exportIcsContent(
    List<Course> courses,
    List<ScheduleEvent> events, {
    List<Semester> semesters = const [],
  }) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//ROCIs//ROCIs Schedule//EN');
    buffer.writeln('CALSCALE:GREGORIAN');

    final courseMap = {for (var c in courses) c.id: c};
    final semesterMap = {for (var s in semesters) s.id: s};

    String formatIcsDate(DateTime dt) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$y$m${d}T$h$min$s';
    }

    String formatIcsDay(DateTime dt) => formatIcsDate(dt).substring(0, 8);

    const dayCodes = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

    for (final event in events) {
      final course = courseMap[event.courseId];
      final title = course != null
          ? '${course.name} - ${event.title}'
          : event.title;
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${event.id}@rocisschedule.app');
      buffer.writeln('SUMMARY:${escapeIcsText(title)}');
      if (event.location.isNotEmpty) {
        buffer.writeln('LOCATION:${escapeIcsText(event.location)}');
      }
      if (event.notes.isNotEmpty) {
        buffer.writeln('DESCRIPTION:${escapeIcsText(event.notes)}');
      }

      final isWeekly = event.recurring && event.daysOfWeek.isNotEmpty;
      final semester = isWeekly
          ? semesterMap[course?.semester ?? 'semester_1']
          : null;
      final start = isWeekly
          ? firstOccurrenceFrom(event, semester?.startDate)
          : event.startTime;
      final end = start.add(event.endTime.difference(event.startTime));

      if (event.allDay) {
        // All-day dates; DTEND is exclusive, so the day after the last one.
        final afterLast = DateUtils.addDaysToDate(event.endDay, 1);
        buffer.writeln('DTSTART;VALUE=DATE:${formatIcsDay(event.startDay)}');
        buffer.writeln('DTEND;VALUE=DATE:${formatIcsDay(afterLast)}');
      } else {
        buffer.writeln('DTSTART:${formatIcsDate(start)}');
        buffer.writeln('DTEND:${formatIcsDate(end)}');
      }
      if (isWeekly) {
        final byDays = event.daysOfWeek
            .map((d) => dayCodes[d.clamp(0, 6)])
            .join(',');
        final semesterEnd = semester?.endDate;
        final until = semesterEnd == null
            ? ''
            : ';UNTIL=${formatIcsDate(DateTime(semesterEnd.year, semesterEnd.month, semesterEnd.day, 23, 59, 59))}';
        buffer.writeln('RRULE:FREQ=WEEKLY;BYDAY=$byDays$until');
      }
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  /// First class of a weekly event on or after [semesterStart] (and never
  /// before the event's own start), keeping the event's time of day.
  static DateTime firstOccurrenceFrom(
    ScheduleEvent event,
    DateTime? semesterStart,
  ) {
    final base = event.startTime;
    var day = DateTime(base.year, base.month, base.day);
    if (semesterStart != null) {
      final semDay = DateTime(
        semesterStart.year,
        semesterStart.month,
        semesterStart.day,
      );
      if (semDay.isAfter(day)) day = semDay;
    }
    // Schedule weekdays: 0=Sun..6=Sat; Dart: 1=Mon..7=Sun.
    for (var i = 0; i < 7; i++) {
      final candidate = DateTime(day.year, day.month, day.day + i);
      if (event.daysOfWeek.contains(candidate.weekday % 7)) {
        day = candidate;
        break;
      }
    }
    return DateTime(
      day.year,
      day.month,
      day.day,
      base.hour,
      base.minute,
      base.second,
    );
  }

  /// Escapes TEXT values per RFC 5545 (backslash, semicolon, comma, newline).
  static String escapeIcsText(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n');
}
