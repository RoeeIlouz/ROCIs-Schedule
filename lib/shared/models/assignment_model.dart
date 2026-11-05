import 'dart:convert';

import 'package:uuid/uuid.dart';

enum AssignmentPriority { low, medium, high }

/// Metadata for a file attached to an [Assignment].
///
/// The bytes live in `users/{uid}/assignments/{assignmentId}/attachments/{id}`
/// (already compressed to fit a Firestore document); only this small record
/// travels with the assignment itself.
class AssignmentAttachment {
  final String id;
  final String name;
  final String mime;

  /// Size of the stored (compressed) bytes.
  final int size;

  /// True when the stored bytes are gzip-compressed and must be inflated
  /// before use. Images are re-encoded instead and are never gzipped.
  final bool gzipped;

  const AssignmentAttachment({
    required this.id,
    required this.name,
    required this.mime,
    required this.size,
    this.gzipped = false,
  });

  bool get isImage => mime.startsWith('image/');

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'mime': mime,
    'size': size,
    'gz': gzipped,
  };

  factory AssignmentAttachment.fromMap(Map<String, dynamic> map) {
    return AssignmentAttachment(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      mime: map['mime']?.toString() ?? 'application/octet-stream',
      size: (map['size'] as num?)?.toInt() ?? 0,
      gzipped: map['gz'] == true || map['gz'] == 1,
    );
  }

  static List<AssignmentAttachment> listFromRaw(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return const [];
      }
    }
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => AssignmentAttachment.fromMap(Map<String, dynamic>.from(m)))
        .where((a) => a.id.isNotEmpty)
        .toList();
  }
}

class Assignment {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool isCompleted;
  final AssignmentPriority priority;

  /// The lecture (a [ScheduleEvent] id) this assignment was given in, and the
  /// date of that session. Both are set together or not at all.
  final String? lectureEventId;
  final DateTime? lectureDate;

  final List<AssignmentAttachment> attachments;

  Assignment({
    String? id,
    required this.courseId,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.isCompleted = false,
    this.priority = AssignmentPriority.medium,
    this.lectureEventId,
    this.lectureDate,
    this.attachments = const [],
  }) : id = id ?? const Uuid().v4();

  bool get hasLecture => lectureEventId != null && lectureDate != null;

  /// Map for Firestore, where attachments are a native list.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseId': courseId,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'priority': priority.index,
      'lectureEventId': lectureEventId,
      'lectureDate': lectureDate?.toIso8601String(),
      'attachments': attachments.map((a) => a.toMap()).toList(),
    };
  }

  /// Map for SQLite, which can't hold a list column.
  Map<String, dynamic> toDbMap() {
    return {
      ...toMap(),
      'attachments': jsonEncode(attachments.map((a) => a.toMap()).toList()),
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    final lectureDate = map['lectureDate'];
    final lectureEventId = map['lectureEventId']?.toString();
    final parsedLectureDate = lectureDate is String && lectureDate.isNotEmpty
        ? DateTime.tryParse(lectureDate)
        : null;
    final linked =
        lectureEventId != null &&
        lectureEventId.isNotEmpty &&
        parsedLectureDate != null;
    return Assignment(
      id: map['id'],
      courseId: map['courseId'],
      title: map['title'],
      description: map['description'] ?? '',
      dueDate: DateTime.parse(map['dueDate']),
      isCompleted: map['isCompleted'] == 1,
      priority: AssignmentPriority.values[map['priority'] ?? 1],
      lectureEventId: linked ? lectureEventId : null,
      lectureDate: linked ? parsedLectureDate : null,
      attachments: AssignmentAttachment.listFromRaw(map['attachments']),
    );
  }

  Assignment copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    bool? isCompleted,
    AssignmentPriority? priority,
    String? lectureEventId,
    DateTime? lectureDate,
    bool clearLecture = false,
    List<AssignmentAttachment>? attachments,
  }) {
    return Assignment(
      id: id,
      courseId: courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      lectureEventId: clearLecture
          ? null
          : (lectureEventId ?? this.lectureEventId),
      lectureDate: clearLecture ? null : (lectureDate ?? this.lectureDate),
      attachments: attachments ?? this.attachments,
    );
  }
}
