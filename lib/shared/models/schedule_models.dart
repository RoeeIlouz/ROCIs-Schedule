import 'package:flutter/material.dart';

class Semester {
  final String id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;

  const Semester({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
  });

  Semester copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
  }) {
    return Semester(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory Semester.fromMap(Map<String, dynamic> map) {
    return Semester(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      startDate:
          map['startDate'] != null && map['startDate'].toString().isNotEmpty
          ? DateTime.tryParse(map['startDate'].toString())
          : null,
      endDate: map['endDate'] != null && map['endDate'].toString().isNotEmpty
          ? DateTime.tryParse(map['endDate'].toString())
          : null,
    );
  }
}

class Course {
  final String id;
  final String name;
  final String code;
  final String instructor;
  final Color color;
  final double credits;
  final double? grade;
  final String? semester;

  /// Optional [CourseIcons] key shown on this course's events.
  final String? icon;

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.instructor,
    required this.color,
    required this.credits,
    this.grade,
    this.semester = 'semester_1',
    this.icon,
  });

  IconData? get iconData => CourseIcons.byKey[icon];

  Course copyWith({
    String? id,
    String? name,
    String? code,
    String? instructor,
    Color? color,
    double? credits,
    double? grade,
    String? semester,
    String? icon,
    bool clearIcon = false,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      instructor: instructor ?? this.instructor,
      color: color ?? this.color,
      credits: credits ?? this.credits,
      grade: grade ?? this.grade,
      semester: semester ?? this.semester,
      icon: clearIcon ? null : (icon ?? this.icon),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'instructor': instructor,
      'color': color.toARGB32(),
      'credits': credits,
      'grade': grade,
      'semester': semester ?? 'semester_1',
      'icon': icon,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    Color parsedColor = Colors.blue;
    final rawColor = map['color'];
    if (rawColor is int) {
      parsedColor = Color(rawColor);
    } else if (rawColor is num) {
      parsedColor = Color(rawColor.toInt());
    } else if (rawColor != null) {
      final parsed = int.tryParse(rawColor.toString());
      if (parsed != null) parsedColor = Color(parsed);
    }

    double parsedCredits = 0.0;
    final rawCredits = map['credits'];
    if (rawCredits is num) {
      parsedCredits = rawCredits.toDouble();
    } else if (rawCredits != null) {
      parsedCredits = double.tryParse(rawCredits.toString()) ?? 0.0;
    }

    double? parsedGrade;
    final rawGrade = map['grade'];
    if (rawGrade is num) {
      parsedGrade = rawGrade.toDouble();
    } else if (rawGrade != null) {
      parsedGrade = double.tryParse(rawGrade.toString());
    }

    return Course(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      instructor: map['instructor']?.toString() ?? '',
      color: parsedColor,
      credits: parsedCredits,
      grade: parsedGrade,
      semester: map['semester']?.toString() ?? 'semester_1',
      icon: CourseIcons.byKey.containsKey(map['icon']) ? map['icon'] : null,
    );
  }
}

enum EventDomain {
  academic,
  work,
  personal;

  static EventDomain fromString(String? val) {
    if (val == null) return EventDomain.academic;
    switch (val.toLowerCase().trim()) {
      case 'work':
        return EventDomain.work;
      case 'personal':
        return EventDomain.personal;
      case 'academic':
      default:
        return EventDomain.academic;
    }
  }

  Color get defaultColor {
    switch (this) {
      case EventDomain.academic:
        return const Color(0xFF2563EB); // Royal Blue
      case EventDomain.work:
        return const Color(0xFF0284C7); // Sky Blue
      case EventDomain.personal:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  IconData get icon {
    switch (this) {
      case EventDomain.academic:
        return Icons.school_outlined;
      case EventDomain.work:
        return Icons.work_outline_rounded;
      case EventDomain.personal:
        return Icons.person_outline_rounded;
    }
  }
}

enum EventType {
  classType,
  exam,
  lab,
  study,
  other;

  IconData get icon {
    switch (this) {
      case EventType.classType:
        return Icons.class_outlined;
      case EventType.exam:
        return Icons.assignment_outlined;
      case EventType.lab:
        return Icons.science_outlined;
      case EventType.study:
        return Icons.menu_book_outlined;
      case EventType.other:
        return Icons.event_outlined;
    }
  }

  String get l10nKey {
    switch (this) {
      case EventType.classType:
        return 'class_type';
      case EventType.exam:
        return 'exam';
      case EventType.lab:
        return 'lab';
      case EventType.study:
        return 'study';
      case EventType.other:
        return 'other';
    }
  }
}

/// Icons a user can pick for a course. Stored by key (not code point) so
/// icon tree shaking keeps working in release builds.
class CourseIcons {
  static const Map<String, IconData> byKey = {
    'school': Icons.school_outlined,
    'book': Icons.menu_book_outlined,
    'calculate': Icons.calculate_outlined,
    'functions': Icons.functions_rounded,
    'science': Icons.science_outlined,
    'biotech': Icons.biotech_outlined,
    'code': Icons.code_rounded,
    'computer': Icons.computer_rounded,
    'memory': Icons.memory_rounded,
    'engineering': Icons.engineering_outlined,
    'architecture': Icons.architecture_rounded,
    'palette': Icons.palette_outlined,
    'music': Icons.music_note_rounded,
    'language': Icons.translate_rounded,
    'history': Icons.account_balance_outlined,
    'public': Icons.public_rounded,
    'psychology': Icons.psychology_outlined,
    'health': Icons.medical_services_outlined,
    'gavel': Icons.gavel_rounded,
    'business': Icons.business_center_outlined,
    'trending': Icons.trending_up_rounded,
    'sports': Icons.sports_soccer_rounded,
    'eco': Icons.eco_outlined,
    'edit': Icons.edit_note_rounded,
  };
}

class ScheduleEvent {
  final String id;
  final String title;
  final String courseId;
  final EventType type;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final List<int> daysOfWeek; // 0=Sunday
  final bool recurring;
  final String notes;
  final EventDomain domain;

  /// The event's own color. Unset, school events follow their course's
  /// color and work/personal events their category's.
  final Color? color;

  /// The color the event is drawn in; null only for a school event without
  /// a course (callers fall back to the theme).
  Color? colorFor(Course? course) =>
      color ??
      (domain == EventDomain.academic ? course?.color : domain.defaultColor);

  /// A one-time event that fills whole days (a holiday, a trip): it runs from
  /// [startTime]'s day through [endTime]'s day and has no clock times.
  final bool allDay;

  Duration get duration => endTime.difference(startTime);

  DateTime get startDay => DateUtils.dateOnly(startTime);

  /// The last day the event covers.
  DateTime get endDay => DateUtils.dateOnly(endTime);

  /// A one-time event whose end falls on a later day than its start.
  bool get isMultiDay => !recurring && endDay.isAfter(startDay);

  /// Shown as a bar above the hour grid rather than a block inside it.
  bool get spansDays => !recurring && (allDay || isMultiDay);

  /// Whether a one-time event covers [date]; recurring events are resolved
  /// by the course provider, which knows semester bounds.
  bool coversDay(DateTime date) {
    final day = DateUtils.dateOnly(date);
    return !day.isBefore(startDay) && !day.isAfter(endDay);
  }

  /// The course's chosen icon, else the event type's for academic events;
  /// the domain's icon otherwise.
  IconData iconFor(Course? course) => domain == EventDomain.academic
      ? (course?.iconData ?? type.icon)
      : domain.icon;
  bool get isNegativeDuration => duration.isNegative;

  ScheduleEvent({
    required this.id,
    required this.title,
    required this.courseId,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.location = '',
    this.daysOfWeek = const [],
    this.recurring = false,
    this.notes = '',
    this.domain = EventDomain.academic,
    this.color,
    this.allDay = false,
  });

  ScheduleEvent copyWith({
    String? id,
    String? title,
    String? courseId,
    EventType? type,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    List<int>? daysOfWeek,
    bool? recurring,
    String? notes,
    EventDomain? domain,
    Color? color,
    bool clearColor = false,
    bool? allDay,
  }) {
    return ScheduleEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      courseId: courseId ?? this.courseId,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      recurring: recurring ?? this.recurring,
      notes: notes ?? this.notes,
      domain: domain ?? this.domain,
      color: clearColor ? null : (color ?? this.color),
      allDay: allDay ?? this.allDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'courseId': courseId.isEmpty ? null : courseId,
      'type': type.index,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'daysOfWeek': daysOfWeek.join(','),
      'recurring': recurring ? 1 : 0,
      'notes': notes,
      'domain': domain.name,
      'color': color?.toARGB32(),
      'allDay': allDay ? 1 : 0,
    };
  }

  factory ScheduleEvent.fromMap(Map<String, dynamic> map) {
    List<int> parsedDays = [];
    final rawDays = map['daysOfWeek'];
    if (rawDays is List) {
      parsedDays =
          rawDays
              .where((e) => e != null)
              .map((e) => int.tryParse(e.toString()))
              .whereType<int>()
              .map((e) => ((e % 7) + 7) % 7)
              .toSet()
              .toList()
            ..sort();
    } else if (rawDays != null && rawDays.toString().isNotEmpty) {
      parsedDays =
          rawDays
              .toString()
              .split(',')
              .where((e) => e.trim().isNotEmpty)
              .map((e) => int.tryParse(e.trim()))
              .whereType<int>()
              .map((e) => ((e % 7) + 7) % 7)
              .toSet()
              .toList()
            ..sort();
    }

    int typeIndex = 0;
    final rawType = map['type'];
    if (rawType is num) {
      typeIndex = rawType.toInt();
    } else if (rawType != null) {
      typeIndex = int.tryParse(rawType.toString()) ?? 0;
    }

    final safeType = (typeIndex >= 0 && typeIndex < EventType.values.length)
        ? EventType.values[typeIndex]
        : EventType.other;

    final rawRecurring = map['recurring'];
    final bool isRecurring =
        rawRecurring == 1 ||
        rawRecurring == true ||
        rawRecurring == '1' ||
        rawRecurring == 'true';

    final domain = EventDomain.fromString(map['domain']?.toString());

    final rawAllDay = map['allDay'];
    final bool isAllDay =
        !isRecurring &&
        (rawAllDay == 1 ||
            rawAllDay == true ||
            rawAllDay == '1' ||
            rawAllDay == 'true');

    Color? parsedEventColor;
    final rawColor = map['color'];
    if (rawColor is int) {
      parsedEventColor = Color(rawColor);
    } else if (rawColor is num) {
      parsedEventColor = Color(rawColor.toInt());
    } else if (rawColor != null) {
      final parsed = int.tryParse(rawColor.toString());
      if (parsed != null) parsedEventColor = Color(parsed);
    }

    return ScheduleEvent(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      courseId: map['courseId']?.toString() ?? '',
      type: safeType,
      startTime:
          DateTime.tryParse(map['startTime']?.toString() ?? '') ??
          DateTime.now(),
      endTime:
          DateTime.tryParse(map['endTime']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 1)),
      location: map['location']?.toString() ?? '',
      daysOfWeek: parsedDays,
      recurring: isRecurring,
      notes: map['notes']?.toString() ?? '',
      domain: domain,
      color: parsedEventColor,
      allDay: isAllDay,
    );
  }
}
