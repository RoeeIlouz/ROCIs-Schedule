/// One event of a calendar feed, as published (no app-specific meaning yet).
class FeedEntry {
  final String uid;
  final String summary;
  final String description;
  final String location;
  final DateTime start;
  final DateTime end;

  /// `TRANSP:TRANSPARENT` - the feed marks it as not blocking time
  /// (holidays, semester markers).
  final bool transparent;

  const FeedEntry({
    required this.uid,
    required this.summary,
    required this.start,
    required this.end,
    this.description = '',
    this.location = '',
    this.transparent = false,
  });
}

enum EntryKind { lecture, practice, lab, exam, skip }

/// What a [FeedEntry] means for the schedule.
class Classified {
  final String courseName;
  final String lecturer;
  final EntryKind kind;
  final bool cancelled;
  final bool registered;

  const Classified({
    required this.courseName,
    required this.lecturer,
    required this.kind,
    this.cancelled = false,
    this.registered = true,
  });
}

/// A classified entry with the stable key used to match it across fetches.
class SyncKeyed {
  final String key;
  final FeedEntry entry;
  final Classified info;

  const SyncKeyed(this.key, this.entry, this.info);
}

enum ChangeKind {
  added,
  removed,
  moved,
  roomChanged,
  lecturerChanged,
  cancelled,
  restored,
}

class SyncChange {
  final ChangeKind kind;
  final String course;
  final DateTime when;
  final String? detail;

  const SyncChange(this.kind, this.course, this.when, [this.detail]);

  @override
  String toString() => 'SyncChange($kind, $course, $when, $detail)';
}
