import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';
import 'package:rocis_schedule/features/calendar_sync/services/afeka_classifier.dart';

/// Thrown when a fetch parsed to nothing although we hold a snapshot: the
/// caller must treat it as a failed fetch, never as "everything was deleted".
class FeedLooksEmpty implements Exception {
  const FeedLooksEmpty();
  @override
  String toString() => 'FeedLooksEmpty';
}

class FeedDiffer {
  /// `normalizedCourse|startIso|kind`
  static String keyFor(Classified c, FeedEntry e) =>
      '${AfekaClassifier.normalizeName(c.courseName)}'
      '|${e.start.toIso8601String()}|${c.kind.name}';

  static List<SyncChange> diff(
    List<SyncKeyed> previous,
    List<SyncKeyed> current,
  ) {
    if (current.isEmpty && previous.isNotEmpty) throw const FeedLooksEmpty();

    final prev = _group(previous);
    final cur = _group(current);
    final changes = <SyncChange>[];
    final removed = <SyncKeyed>[];
    final added = <SyncKeyed>[];

    for (final key in {...prev.keys, ...cur.keys}) {
      final p = prev[key] ?? const <SyncKeyed>[];
      final c = cur[key] ?? const <SyncKeyed>[];
      final shared = p.length < c.length ? p.length : c.length;
      for (var i = 0; i < shared; i++) {
        changes.addAll(_fieldChanges(p[i], c[i]));
      }
      removed.addAll(p.skip(shared));
      added.addAll(c.skip(shared));
    }

    // Pair leftovers of the same course and kind as moves.
    final unmatchedAdded = [...added];
    for (final r in removed) {
      SyncKeyed? best;
      for (final a in unmatchedAdded) {
        if (a.info.kind != r.info.kind) continue;
        if (AfekaClassifier.normalizeName(a.info.courseName) !=
            AfekaClassifier.normalizeName(r.info.courseName)) {
          continue;
        }
        if (best == null || _gap(a, r) < _gap(best, r)) {
          best = a;
        }
      }
      if (best != null) {
        unmatchedAdded.remove(best);
        changes.add(
          SyncChange(
            ChangeKind.moved,
            best.info.courseName,
            best.entry.start,
            r.entry.start.toIso8601String(),
          ),
        );
      } else {
        changes.add(
          SyncChange(ChangeKind.removed, r.info.courseName, r.entry.start),
        );
      }
    }
    for (final a in unmatchedAdded) {
      changes.add(
        SyncChange(ChangeKind.added, a.info.courseName, a.entry.start),
      );
    }
    return changes;
  }

  static Duration _gap(SyncKeyed a, SyncKeyed b) =>
      a.entry.start.difference(b.entry.start).abs();

  static Map<String, List<SyncKeyed>> _group(List<SyncKeyed> list) {
    final m = <String, List<SyncKeyed>>{};
    for (final e in list) {
      (m[e.key] ??= []).add(e);
    }
    return m;
  }

  static List<SyncChange> _fieldChanges(SyncKeyed p, SyncKeyed c) {
    final out = <SyncChange>[];
    final course = c.info.courseName;
    final when = c.entry.start;
    if (!p.info.cancelled && c.info.cancelled) {
      out.add(SyncChange(ChangeKind.cancelled, course, when));
    } else if (p.info.cancelled && !c.info.cancelled) {
      out.add(SyncChange(ChangeKind.restored, course, when));
    }
    final oldRoom = AfekaClassifier.normalizeName(p.entry.location);
    final newRoom = AfekaClassifier.normalizeName(c.entry.location);
    if (oldRoom != newRoom) {
      out.add(
        SyncChange(
          ChangeKind.roomChanged,
          course,
          when,
          '$oldRoom -> $newRoom',
        ),
      );
    }
    final oldLec = AfekaClassifier.normalizeName(p.info.lecturer);
    final newLec = AfekaClassifier.normalizeName(c.info.lecturer);
    if (oldLec != newLec) {
      out.add(
        SyncChange(
          ChangeKind.lecturerChanged,
          course,
          when,
          '$oldLec -> $newLec',
        ),
      );
    }
    return out;
  }
}
