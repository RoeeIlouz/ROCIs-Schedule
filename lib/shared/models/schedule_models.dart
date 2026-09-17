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

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.instructor,
    required this.color,
    required this.credits,
    this.grade,
    this.semester = 'semester_1',
  });

  Course copyWith({
    String? id,
    String? name,
    String? code,
    String? instructor,
    Color? color,
    double? credits,
    double? grade,
    String? semester,
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

enum EventType { classType, exam, lab, study, other }

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
  final Color? color;

  Duration get duration => endTime.difference(startTime);
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
    );
  }
}
