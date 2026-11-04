import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';

/// Reads the meaning of an Afeka Yedion calendar entry from its Hebrew
/// title and description.
class AfekaClassifier {
  static final _bidi = RegExp('[\u200E\u200F\u202A-\u202E\u2066-\u2069]');
  static final _cancelled = RegExp(r'\*+\s*השיעור מבוטל\s*\*+');
  static final _examPrefix = RegExp(r'^מבחן מועד \d+ בחינה\s*');
  static final _lecturerStart = RegExp(
    r'''(?:^|\s)(?:ד"ר|ד״ר|מר|גב'|גברת|פרופ'|פרופ)\s''',
  );

  static String normalizeName(String raw) =>
      raw.replaceAll(_bidi, '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static Classified classify(FeedEntry e) {
    if (e.transparent) {
      return const Classified(
          courseName: '', lecturer: '', kind: EntryKind.skip);
    }

    var title = normalizeName(e.summary);
    final cancelled = _cancelled.hasMatch(title);
    title = normalizeName(title.replaceAll(_cancelled, ''));

    final isExam = _examPrefix.hasMatch(title);
    if (isExam) title = title.replaceFirst(_examPrefix, '');

    var course = title;
    var lecturer = '';
    final m = _lecturerStart.firstMatch(title);
    if (m != null) {
      // A title that begins with the lecturer has no course part to keep.
      if (m.start > 0) {
        course = title.substring(0, m.start).trim();
        lecturer = title.substring(m.start).trim();
      }
    }

    final desc = normalizeName(e.description);
    if (isExam) {
      final registered =
          desc.contains('רשום למבחן') && !desc.contains('לא רשום למבחן');
      return Classified(
        courseName: course,
        lecturer: lecturer,
        kind: EntryKind.exam,
        cancelled: cancelled,
        registered: registered,
      );
    }

    final EntryKind kind;
    if (desc.contains('הרצאה')) {
      kind = EntryKind.lecture;
    } else if (desc.contains('מעבדה')) {
      kind = EntryKind.lab;
    } else if (desc.contains('תרגול')) {
      kind = EntryKind.practice;
    } else {
      kind = EntryKind.lecture;
    }
    return Classified(
      courseName: course,
      lecturer: lecturer,
      kind: kind,
      cancelled: cancelled,
    );
  }
}
