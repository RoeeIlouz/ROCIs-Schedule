import 'package:cloud_firestore/cloud_firestore.dart';

enum SyncedTaskPriority { low, medium, high, urgent }

class SyncedTask {
  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;
  final bool isCompleted;
  final SyncedTaskPriority priority;

  const SyncedTask({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.isCompleted = false,
    this.priority = SyncedTaskPriority.medium,
  });

  factory SyncedTask.fromFirestore(Map<String, dynamic> data) {
    DateTime? parsedDate;
    final rawDate = data['dueDate'];
    if (rawDate != null) {
      if (rawDate is DateTime) {
        parsedDate = rawDate;
      } else if (rawDate is Timestamp) {
        parsedDate = rawDate.toDate();
      } else if (rawDate is String) {
        parsedDate = DateTime.tryParse(rawDate);
      }
    }

    final prioIndex = (data['priority'] is int) ? data['priority'] as int : 1;
    final priority =
        prioIndex >= 0 && prioIndex < SyncedTaskPriority.values.length
        ? SyncedTaskPriority.values[prioIndex]
        : SyncedTaskPriority.medium;

    return SyncedTask(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      dueDate: parsedDate,
      isCompleted: data['isCompleted'] == true,
      priority: priority,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'priority': priority.index,
    };
  }
}
