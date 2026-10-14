import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

/// Represents a single course and its associated sessions parsed from OCR text.
class ScannedCourseDraft {
  final Course course;
  final List<ScheduleEvent> events;
  bool isSelected;

  ScannedCourseDraft({
    required this.course,
    required this.events,
    this.isSelected = true,
  });

  ScannedCourseDraft copyWith({
    Course? course,
    List<ScheduleEvent>? events,
    bool? isSelected,
  }) {
    return ScannedCourseDraft(
      course: course ?? this.course,
      events: events ?? this.events,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// The result returned by [OcrTimetableParser].
class OcrTimetableResult {
  final List<ScannedCourseDraft> drafts;
  final String rawText;
  final List<String> unparsedLines;

  OcrTimetableResult({
    required this.drafts,
    required this.rawText,
    required this.unparsedLines,
  });

  int get totalCourses => drafts.length;
  int get totalEvents => drafts.fold(0, (acc, d) => acc + d.events.length);
}

/// On-device, fast timetable & syllabus parser.
/// Parses raw recognized OCR text (or OCR line tokens) and reconstructs
/// structured courses and weekly scheduled events.
class OcrTimetableParser {
  static const List<Color> _palette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Rose
    Color(0xFF8B5CF6), // Violet
    Color(0xFF14B8A6), // Teal
    Color(0xFFEC4899), // Pink
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Green
  ];

  static const _uuid = Uuid();

  /// Regex patterns for matching times:
  /// Examples: "08:30 - 10:00", "8:30-10:00", "14:00 – 16:00", "09:00 to 11:30"
  /// AM/PM: "9:00 AM - 10:30 AM", "2:00pm - 3:30pm"
  static final RegExp _timeRangeRegex = RegExp(
    r'(?:(\d{1,2})[:.](\d{2})\s*(am|pm|AM|PM)?)\s*(?:-|–|—|to|עד)\s*(?:(\d{1,2})[:.](\d{2})\s*(am|pm|AM|PM)?)',
  );

  /// Single time pattern (e.g. "09:00")
  static final RegExp _singleTimeRegex = RegExp(
    r'\b(\d{1,2})[:.](\d{2})\s*(am|pm|AM|PM)?\b',
  );

  /// Day of week mappings (English & Hebrew, full and abbreviated)
  static final Map<String, int> _dayKeywords = {
    // English (0=Sunday)
    'sun': 0, 'sunday': 0,
    'mon': 1, 'monday': 1,
    'tue': 2, 'tues': 2, 'tuesday': 2,
    'wed': 3, 'wednesday': 3,
    'thu': 4, 'thur': 4, 'thurs': 4, 'thursday': 4,
    'fri': 5, 'friday': 5,
    'sat': 6, 'saturday': 6,

    // Hebrew
    'ראשון': 0, "א'": 0, "יום א'": 0, "יום א": 0, "א": 0,
    'שני': 1, "ב'": 1, "יום ב'": 1, "יום ב": 1, "ב": 1,
    'שלישי': 2, "ג'": 2, "יום ג'": 2, "יום ג": 2, "ג": 2,
    'רביעי': 3, "ד'": 3, "יום ד'": 3, "יום ד": 3, "ד": 3,
    'חמישי': 4, "ה'": 4, "יום ה'": 4, "יום ה": 4, "ה": 4,
    'שישי': 5, "ו'": 5, "יום ו'": 5, "יום ו": 5, "ו": 5,
    'שבת': 6, "ש'": 6, "יום ש'": 6, "יום ש": 6,
  };

  /// Common course code pattern (e.g., "CS101", "MATH-202", "044102", "PHY 101", "234114")
  static final RegExp _courseCodeRegex = RegExp(
    r'\b([A-Za-z]{2,5}[-\s]?\d{3,4}|\d{5,7})\b',
  );

  /// Location indicator patterns
  static final RegExp _locationRegex = RegExp(
    r'(?:room|rm|bldg|building|auditorium|hall|lab|חדר|בניין|אולם|אודיטוריום|מעבדה|כיתה)\s*[:#]?\s*([A-Za-z0-9\-]+(?:\s+[A-Za-z0-9\-]+)?)',
    caseSensitive: false,
  );

  /// Parses raw text extracted from an image or syllabus document.
  static OcrTimetableResult parseText(String text, {String? defaultSemester}) {
    final cleanText = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = cleanText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final courseDraftsMap = <String, ScannedCourseDraft>{};
    final unparsed = <String>[];
    int colorIndex = 0;

    String currentCourseName = '';
    String currentCourseCode = '';
    String currentInstructor = '';

    int? activeColumnDay;

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];

      // Ignore top-level metadata junk (e.g. "Timetable page 1", "Semester A")
      if (_isMetadataJunk(line)) {
        continue;
      }

      // Check for time range in the line
      final timeMatch = _timeRangeRegex.firstMatch(line);
      final lineDay = _extractDayOfWeek(line);

      if (timeMatch != null) {
        // This line contains session details!
        final times = _parseTimeMatch(timeMatch);
        final loc = _extractLocation(line);
        final eventType = _extractEventType(line);
        final dayOfWeek = lineDay ?? activeColumnDay ?? 0;

        // If the line has an explicit course code or if currentCourseName is empty, try extracting course name from this line
        final codeMatch = _courseCodeRegex.firstMatch(line);
        if (codeMatch != null) {
          currentCourseCode = codeMatch.group(1) ?? '';
        }

        final lineCourseName = _extractCourseNameFromLine(line, timeMatch);
        if (codeMatch != null && lineCourseName.isNotEmpty) {
          currentCourseName = lineCourseName;
        } else if (currentCourseName.isEmpty) {
          if (lineCourseName.isNotEmpty) {
            currentCourseName = lineCourseName;
          } else if (i > 0) {
            final prevLine = rawLines[i - 1];
            if (!_containsTime(prevLine) && _extractDayOfWeek(prevLine) == null) {
              currentCourseName = _cleanCandidateTitle(prevLine);
            }
          }
        }

        final effectiveCourseName = currentCourseName.isNotEmpty
            ? currentCourseName
            : 'Course ${courseDraftsMap.length + 1}';

        // Check if course already exists in drafts
        final courseKey = effectiveCourseName.toLowerCase();
        ScannedCourseDraft draft;
        if (!courseDraftsMap.containsKey(courseKey)) {
          final courseColor = _palette[colorIndex % _palette.length];
          colorIndex++;

          final newCourse = Course(
            id: _uuid.v4(),
            name: effectiveCourseName,
            code: currentCourseCode,
            instructor: currentInstructor,
            color: courseColor,
            credits: 3.0,
            semester: defaultSemester ?? 'semester_1',
          );
          draft = ScannedCourseDraft(course: newCourse, events: []);
          courseDraftsMap[courseKey] = draft;
        } else {
          draft = courseDraftsMap[courseKey]!;
        }

        // Create the event
        final now = DateTime.now();
        final startDt = times != null
            ? DateTime(now.year, now.month, now.day, times.startHour, times.startMinute)
            : DateTime(now.year, now.month, now.day, 9, 0);
        final endDt = times != null
            ? DateTime(now.year, now.month, now.day, times.endHour, times.endMinute)
            : startDt.add(const Duration(minutes: 90));

        final resolvedDays = dayOfWeek != null ? [dayOfWeek] : <int>[0];

        final event = ScheduleEvent(
          id: _uuid.v4(),
          title: effectiveCourseName,
          courseId: draft.course.id,
          type: eventType,
          startTime: startDt,
          endTime: endDt,
          location: loc,
          daysOfWeek: resolvedDays,
          recurring: true,
          domain: EventDomain.academic,
        );

        draft.events.add(event);
      } else {
        // Line does not have a time.
        // Check if it's a day column header (e.g. "Sunday", "Monday", "יום ראשון")
        if (lineDay != null && line.length <= 15) {
          activeColumnDay = lineDay;
          continue;
        }

        // Check if it's a course title or code
        final codeMatch = _courseCodeRegex.firstMatch(line);
        if (codeMatch != null && line.length < 30) {
          currentCourseCode = codeMatch.group(1) ?? '';
        }

        final cleaned = _cleanCandidateTitle(line);
        if (cleaned.length >= 3 && !_isMetadataJunk(cleaned)) {
          currentCourseName = cleaned;
          if (codeMatch != null) {
            currentCourseName = currentCourseName.replaceAll(codeMatch.group(0)!, '').trim();
          }
        } else {
          unparsed.add(line);
        }
      }
    }

    return OcrTimetableResult(
      drafts: courseDraftsMap.values.toList(),
      rawText: text,
      unparsedLines: unparsed,
    );
  }

  static int? _extractDayOfWeek(String line) {
    final lower = line.toLowerCase();
    // Sort keys by descending length so full names like "יום ראשון" or "sunday" are matched before single letter tokens
    final sortedKeys = _dayKeywords.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final key in sortedKeys) {
      final pattern = RegExp(
        '(?:^|\\s|[.,;:\\-()\\[\\]])${RegExp.escape(key)}(?:\\s|[.,;:\\-()\\[\\]]|\$)',
        caseSensitive: false,
      );
      if (pattern.hasMatch(lower)) {
        return _dayKeywords[key];
      }
    }
    return null;
  }

  static bool _containsTime(String line) {
    return _timeRangeRegex.hasMatch(line) || _singleTimeRegex.hasMatch(line);
  }

  static _ParsedTimeRange? _parseTimeMatch(Match? match) {
    if (match == null) return null;
    int sh = int.tryParse(match.group(1) ?? '') ?? 9;
    int sm = int.tryParse(match.group(2) ?? '') ?? 0;
    final sampm = match.group(3)?.toLowerCase();

    int eh = int.tryParse(match.group(4) ?? '') ?? (sh + 1);
    int em = int.tryParse(match.group(5) ?? '') ?? sm;
    final eampm = match.group(6)?.toLowerCase();

    // Adjust 12-hour clock
    if (sampm == 'pm' && sh < 12) sh += 12;
    if (sampm == 'am' && sh == 12) sh = 0;
    if (eampm == 'pm' && eh < 12) eh += 12;
    if (eampm == 'am' && eh == 12) eh = 0;

    // Fix end time if earlier than start time (e.g. 10:00 - 12:00 vs 1:00 - 3:00 without PM)
    if (eh < sh && eh <= 6) {
      eh += 12;
    }

    return _ParsedTimeRange(
      startHour: sh.clamp(0, 23),
      startMinute: sm.clamp(0, 59),
      endHour: eh.clamp(0, 23),
      endMinute: em.clamp(0, 59),
    );
  }

  static String _extractLocation(String line) {
    final match = _locationRegex.firstMatch(line);
    if (match != null) {
      final loc = match.group(0)?.trim() ?? '';
      return loc;
    }
    return '';
  }

  static EventType _extractEventType(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('lab') || lower.contains('מעבדה')) {
      return EventType.lab;
    }
    if (lower.contains('exam') || lower.contains('מבחן') || lower.contains('בוחן')) {
      return EventType.exam;
    }
    if (lower.contains('tutorial') || lower.contains('תרגול') || lower.contains('recitation')) {
      return EventType.classType;
    }
    if (lower.contains('study') || lower.contains('לימוד')) {
      return EventType.study;
    }
    return EventType.classType;
  }

  static String _extractCourseNameFromLine(String line, Match? timeMatch) {
    String textWithoutTime = line;
    if (timeMatch != null) {
      textWithoutTime = line.replaceRange(timeMatch.start, timeMatch.end, ' ');
    }
    // Remove location if present
    textWithoutTime = textWithoutTime.replaceAll(_locationRegex, ' ');
    // Remove day words (supporting Hebrew and English without relying on ASCII-only \b)
    for (final day in _dayKeywords.keys) {
      textWithoutTime = textWithoutTime.replaceAll(
        RegExp('(?:^|\\s|[.,;:\\-()\\[\\]])${RegExp.escape(day)}(?:\\s|[.,;:\\-()\\[\\]]|\$)', caseSensitive: false),
        ' ',
      );
    }
    final cleaned = textWithoutTime.replaceAll(RegExp(r'[|:;,\-\(\)\[\]]'), ' ').trim();
    if (cleaned.length >= 3 && !_isMetadataJunk(cleaned)) {
      return cleaned;
    }
    return '';
  }

  static String _cleanCandidateTitle(String line) {
    return line
        .replaceAll(RegExp(r'[|:;\-\(\)\[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isMetadataJunk(String str) {
    final lower = str.toLowerCase();
    if (lower.contains('page') ||
        lower.contains('semester') ||
        lower.contains('timetable') ||
        lower.contains('schedule') ||
        lower.contains('printed') ||
        lower.contains('סמסטר') ||
        lower.contains('מערכת שעות') ||
        lower.contains('עמוד')) {
      return true;
    }
    return false;
  }
}

class _ParsedTimeRange {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  _ParsedTimeRange({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });
}
