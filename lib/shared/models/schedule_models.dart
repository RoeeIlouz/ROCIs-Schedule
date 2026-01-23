import 'package:flutter/material.dart';

class Course {
  final String id;
  final String name;
  final String code;
  final String instructor;
  final Color color;
  final int credits;

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.instructor,
    required this.color,
    required this.credits,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'instructor': instructor,
      'color': color.value,
      'credits': credits,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'],
      name: map['name'],
      code: map['code'],
      instructor: map['instructor'],
      color: Color(map['color']),
      credits: map['credits'],
    );
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'courseId': courseId,
      'type': type.index,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      'daysOfWeek': daysOfWeek.join(','),
      'recurring': recurring ? 1 : 0,
      'notes': notes,
    };
  }

  factory ScheduleEvent.fromMap(Map<String, dynamic> map) {
    return ScheduleEvent(
      id: map['id'],
      title: map['title'],
      courseId: map['courseId'],
      type: EventType.values[map['type']],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      location: map['location'],
      daysOfWeek: map['daysOfWeek']
          .toString()
          .split(',')
          .where((e) => e.isNotEmpty)
          .map(int.parse)
          .toList(),
      recurring: map['recurring'] == 1,
      notes: map['notes'],
    );
  }
}
