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

  static IcsImportResult parseIcsContent(String icsContent) {
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
      } else if (line == 'END:VEVENT') {
        inEvent = false;
        if (summary.isNotEmpty && dtStartStr.isNotEmpty) {
          final startTime = _parseDateTime(dtStartStr);
          final endTime = dtEndStr.isNotEmpty
              ? _parseDateTime(dtEndStr)
              : startTime.add(const Duration(hours: 1));

          final daysOfWeek = _parseDaysOfWeek(rruleStr, startTime);
          final isRecurring =
              rruleStr.contains('FREQ=WEEKLY') || daysOfWeek.isNotEmpty;
          final eventType = _detectEventType(summary);

          final rawKey = _extractCourseKey(summary);
          final courseKey = rawKey.isNotEmpty
              ? rawKey
              : (summary.trim().isNotEmpty ? summary.trim() : 'Course');
          if (!coursesMap.containsKey(courseKey)) {
            final colorIndex = coursesMap.length % _palette.length;
            final courseCode = _extractCourseCode(summary);
            coursesMap[courseKey] = Course(
              id: 'c_${uuid.v4().substring(0, 8)}',
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
              id: 'e_${uuid.v4().substring(0, 8)}',
              title: summary,
              courseId: course.id,
              type: eventType,
              startTime: startTime,
              endTime: endTime,
              location: location,
              daysOfWeek: daysOfWeek,
              recurring: isRecurring,
              notes: description,
            ),
          );
        }
      } else if (inEvent) {
        if (line.startsWith('SUMMARY:')) {
          summary = line.substring(8).trim();
        } else if (line.startsWith('LOCATION:')) {
          location = line.substring(9).trim();
        } else if (line.startsWith('DESCRIPTION:')) {
          description = line.substring(12).trim();
        } else if (line.startsWith('DTSTART')) {
          final idx = line.indexOf(':');
          if (idx != -1) dtStartStr = line.substring(idx + 1).trim();
        } else if (line.startsWith('DTEND')) {
          final idx = line.indexOf(':');
          if (idx != -1) dtEndStr = line.substring(idx + 1).trim();
        } else if (line.startsWith('RRULE:')) {
          rruleStr = line.substring(6).trim();
        }
      }
    }

    return IcsImportResult(courses: coursesMap.values.toList(), events: events);
  }

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

  static String exportIcsContent(
    List<Course> courses,
    List<ScheduleEvent> events,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//ROCIs//ROCIs Schedule//EN');
    buffer.writeln('CALSCALE:GREGORIAN');

    final courseMap = {for (var c in courses) c.id: c};

    String formatIcsDate(DateTime dt) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$y$m${d}T$h$min$s';
    }

    const dayCodes = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

    for (final event in events) {
      final course = courseMap[event.courseId];
      final title = course != null
          ? '${course.name} - ${event.title}'
          : event.title;
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${event.id}@rocisschedule.app');
      buffer.writeln('SUMMARY:$title');
      if (event.location.isNotEmpty) {
        buffer.writeln('LOCATION:${event.location}');
      }
      if (event.notes.isNotEmpty) {
        buffer.writeln('DESCRIPTION:${event.notes}');
      }
      buffer.writeln('DTSTART:${formatIcsDate(event.startTime)}');
      buffer.writeln('DTEND:${formatIcsDate(event.endTime)}');
      if (event.recurring && event.daysOfWeek.isNotEmpty) {
        final byDays = event.daysOfWeek
            .map((d) => dayCodes[d.clamp(0, 6)])
            .join(',');
        buffer.writeln('RRULE:FREQ=WEEKLY;BYDAY=$byDays');
      }
      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }
}
