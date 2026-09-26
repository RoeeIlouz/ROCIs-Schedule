import 'dart:convert';
import 'dart:ui' show Color;

import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';

/// Localized labels used in synced event descriptions.
class CalendarEventLabels {
  final String course;
  final String instructor;
  final String type;
  final String credits;
  final String semester;
  final String category;
  final String footer;
  final String Function(EventType) typeName;
  final String Function(EventDomain) domainName;

  const CalendarEventLabels({
    required this.course,
    required this.instructor,
    required this.type,
    required this.credits,
    required this.semester,
    required this.category,
    required this.footer,
    required this.typeName,
    required this.domainName,
  });
}

/// Builds Google Calendar API event resources from schedule events.
///
/// Pure and deterministic, so the sync can compare a content hash and only
/// write events that actually changed.
class GoogleCalendarEventBuilder {
  static const _dayCodes = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];

  /// Google's fixed event colours (colorId 1-11).
  static const Map<String, Color> eventColors = {
    '1': Color(0xFF7986CB),
    '2': Color(0xFF33B679),
    '3': Color(0xFF8E24AA),
    '4': Color(0xFFE67C73),
    '5': Color(0xFFF6BF26),
    '6': Color(0xFFF4511E),
    '7': Color(0xFF039BE5),
    '8': Color(0xFF616161),
    '9': Color(0xFF3F51B5),
    '10': Color(0xFF0B8043),
    '11': Color(0xFFD50000),
  };

  /// A stable Google event id for a schedule event. Google ids allow only
  /// base32hex characters (a-v, 0-9), so the id is hex-encoded, which also
  /// makes re-syncing idempotent without storing a mapping.
  static String googleEventId(String scheduleEventId) {
    final hex = utf8
        .encode(scheduleEventId)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'rs$hex';
  }

  /// The Google colour closest to [color].
  static String nearestColorId(Color color) {
    String best = '1';
    var bestDistance = double.infinity;
    for (final entry in eventColors.entries) {
      final c = entry.value;
      final dr = (c.r - color.r) * 255;
      final dg = (c.g - color.g) * 255;
      final db = (c.b - color.b) * 255;
      final distance = dr * dr + dg * dg + db * db;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = entry.key;
      }
    }
    return best;
  }

  /// Event title: "Course · Lecture", or the event's own title when it
  /// already names the course or has no course.
  static String summary(
    ScheduleEvent event,
    Course? course,
    CalendarEventLabels labels,
  ) {
    final title = event.title.trim();
    final label = title.isNotEmpty ? title : labels.typeName(event.type);
    if (course == null || course.name.trim().isEmpty) return label;
    final courseName = course.name.trim();
    if (label.toLowerCase().contains(courseName.toLowerCase())) return label;
    return '$courseName · $label';
  }

  /// Multi-line description with every detail the app knows.
  static String description(
    ScheduleEvent event,
    Course? course,
    Semester? semester,
    CalendarEventLabels labels,
  ) {
    final lines = <String>[];
    if (event.domain == EventDomain.academic) {
      if (course != null) {
        final code = course.code.trim();
        lines.add(
          '${labels.course}: ${course.name.trim()}${code.isEmpty ? '' : ' ($code)'}',
        );
        if (course.instructor.trim().isNotEmpty) {
          lines.add('${labels.instructor}: ${course.instructor.trim()}');
        }
      }
      lines.add('${labels.type}: ${labels.typeName(event.type)}');
      if (course != null && course.credits > 0) {
        final credits = course.credits == course.credits.roundToDouble()
            ? course.credits.toInt().toString()
            : course.credits.toString();
        lines.add('${labels.credits}: $credits');
      }
      if (semester != null && semester.name.trim().isNotEmpty) {
        lines.add('${labels.semester}: ${semester.name.trim()}');
      }
    } else {
      lines.add('${labels.category}: ${labels.domainName(event.domain)}');
    }
    final notes = event.notes.trim();
    if (notes.isNotEmpty) lines.addAll(['', notes]);
    lines.addAll(['', '— ${labels.footer}']);
    return lines.join('\n');
  }

  /// Local wall-clock time; the event's timeZone gives it meaning, which keeps
  /// recurring classes at the same time across daylight-saving changes.
  static String _localDateTime(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}'
      'T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

  static String _utcStamp(DateTime t) {
    final u = t.toUtc();
    return '${u.year.toString().padLeft(4, '0')}${_two(u.month)}${_two(u.day)}'
        'T${_two(u.hour)}${_two(u.minute)}${_two(u.second)}Z';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// The full event resource. [semester] bounds weekly classes to their
  /// semester, matching how the app itself shows them.
  static Map<String, dynamic> build({
    required ScheduleEvent event,
    required Course? course,
    required Semester? semester,
    required String timeZone,
    required int reminderMinutes,
    required CalendarEventLabels labels,
  }) {
    final isWeekly = event.recurring && event.daysOfWeek.isNotEmpty;
    final start = isWeekly
        ? IcsImportService.firstOccurrenceFrom(event, semester?.startDate)
        : event.startTime;
    final end = start.add(event.endTime.difference(event.startTime));

    final color = event.domain == EventDomain.academic
        ? course?.color
        : (event.color ?? event.domain.defaultColor);

    final body = <String, dynamic>{
      'summary': summary(event, course, labels),
      'description': description(event, course, semester, labels),
      if (event.location.trim().isNotEmpty) 'location': event.location.trim(),
      'start': {'dateTime': _localDateTime(start), 'timeZone': timeZone},
      'end': {'dateTime': _localDateTime(end), 'timeZone': timeZone},
      if (isWeekly) 'recurrence': [_rrule(event, semester)],
      if (color != null) 'colorId': nearestColorId(color),
      'reminders': {
        'useDefault': false,
        'overrides': [
          {'method': 'popup', 'minutes': reminderMinutes},
        ],
      },
      'source': {
        'title': 'ROCIs Schedule',
        'url': 'https://schedule.rocisapps.com',
      },
      'status': 'confirmed',
    };
    body['extendedProperties'] = {
      'private': {'rocisEventId': event.id, 'rocisHash': contentHash(body)},
    };
    return body;
  }

  static String _rrule(ScheduleEvent event, Semester? semester) {
    final days = ([
      ...event.daysOfWeek,
    ]..sort()).map((d) => _dayCodes[d.clamp(0, 6)]).join(',');
    final end = semester?.endDate;
    final until = end == null
        ? ''
        : ';UNTIL=${_utcStamp(DateTime(end.year, end.month, end.day, 23, 59, 59))}';
    return 'RRULE:FREQ=WEEKLY;BYDAY=$days$until';
  }

  /// FNV-1a over the canonical JSON, used to skip unchanged events.
  static String contentHash(Map<String, dynamic> body) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(jsonEncode(body))) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
