import 'package:uuid/uuid.dart';

enum AssignmentPriority { low, medium, high }

class Assignment {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool isCompleted;
  final AssignmentPriority priority;

  Assignment({
    String? id,
    required this.courseId,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.isCompleted = false,
    this.priority = AssignmentPriority.medium,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'priority': priority.index,
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'],
      courseId: map['courseId'],
      title: map['title'],
      description: map['description'] ?? '',
      dueDate: DateTime.parse(map['dueDate']),
      isCompleted: map['isCompleted'] == 1,
      priority: AssignmentPriority.values[map['priority'] ?? 1],
    );
  }

  Assignment copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
    AssignmentPriority? priority,
  }) {
    return Assignment(
      id: id,
      courseId: courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
    );
  }
}
