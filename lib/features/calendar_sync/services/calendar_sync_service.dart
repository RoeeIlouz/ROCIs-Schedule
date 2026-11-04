import 'dart:ui' show Color;

import 'package:uuid/uuid.dart';
import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';
import 'package:rocis_schedule/features/calendar_sync/services/afeka_classifier.dart';
import 'package:rocis_schedule/features/calendar_sync/services/feed_differ.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_store.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

class SyncSummary {
  final List<SyncChange> changes;
  final bool isFirstRun;

  /// Existing weekly sessions of matched courses that the dated sessions
  /// would replace. Never deleted until [CalendarSyncService.applyReplacement].
  final List<ScheduleEvent> replaceCandidates;

  const SyncSummary({
    required this.changes,
    required this.isFirstRun,
    this.replaceCandidates = const [],
  });
}

/// Applies a parsed calendar feed to the schedule. Events it creates are
/// ordinary one-time [ScheduleEvent]s with deterministic ids, so the app
/// needs no extra schema and two devices converge on the same events.
class CalendarSyncService {
  final CourseProvider _provider;
  final SyncStore _store;
  final String cancelledLabel;

  CalendarSyncService(
    this._provider,
    this._store, {
    this.cancelledLabel = 'Cancelled',
  });

  static const _cancelledColor = Color(0xFF9E9E9E);
  static const _palette = [
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
  ];

  static String syncedEventId(String sourceId, String key, int occurrence) =>
      const Uuid().v5(Namespace.url.value, 'event|$sourceId|$key|$occurrence');

  static String _courseId(String sourceId, String name) =>
      const Uuid().v5(Namespace.url.value, 'course|$sourceId|$name');

  /// Ids for a keyed list; entries sharing a key get increasing occurrences.
  static List<String> _ids(String sourceId, List<SyncKeyed> list) {
    final seen = <String, int>{};
    return [
      for (final k in list)
        syncedEventId(
          sourceId,
          k.key,
          seen.update(k.key, (n) => n + 1, ifAbsent: () => 0),
        ),
    ];
  }

  Future<SyncSummary> applyEntries(
    String sourceId,
    List<FeedEntry> feed,
  ) async {
    final current = <SyncKeyed>[];
    for (final entry in feed) {
      final info = AfekaClassifier.classify(entry);
      if (info.kind == EntryKind.skip) continue;
      if (info.kind == EntryKind.exam && !info.registered) continue;
      current.add(SyncKeyed(FeedDiffer.keyFor(info, entry), entry, info));
    }

    final previous = await _store.loadSnapshot(sourceId);
    final isFirstRun = previous.isEmpty;
    final changes = FeedDiffer.diff(previous, current);

    final currentIds = _ids(sourceId, current);
    final previousIds = _ids(sourceId, previous).toSet();

    // Courses: match by normalized name, else create.
    final byName = <String, Course>{
      for (final c in _provider.courses)
        AfekaClassifier.normalizeName(c.name): c,
    };
    final matchedExisting = <String>{};
    final newCourses = <Course>[];
    Course courseFor(String rawName) {
      final name = AfekaClassifier.normalizeName(rawName);
      final found = byName[name];
      if (found != null) {
        matchedExisting.add(found.id);
        return found;
      }
      final created = Course(
        id: _courseId(sourceId, name),
        name: name,
        code: '',
        instructor: '',
        color: _palette[(byName.length) % _palette.length],
        credits: 0,
      );
      byName[name] = created;
      newCourses.add(created);
      return created;
    }

    final existingById = {for (final e in _provider.events) e.id: e};
    final upserts = <ScheduleEvent>[];
    for (var i = 0; i < current.length; i++) {
      final k = current[i];
      final course = courseFor(k.info.courseName);
      final existing = existingById[currentIds[i]];
      final cancelled = k.info.cancelled;
      final wanted = ScheduleEvent(
        id: currentIds[i],
        title: cancelled ? '$cancelledLabel ${course.name}' : course.name,
        courseId: course.id,
        type: switch (k.info.kind) {
          EntryKind.exam => EventType.exam,
          EntryKind.lab => EventType.lab,
          _ => EventType.classType,
        },
        startTime: k.entry.start,
        endTime: k.entry.end,
        location: AfekaClassifier.normalizeName(k.entry.location),
        notes: AfekaClassifier.normalizeName(k.info.lecturer),
        color: cancelled ? _cancelledColor : existing?.color,
      );
      if (existing == null || !_same(existing, wanted)) upserts.add(wanted);
    }

    final currentIdSet = currentIds.toSet();
    final deleteIds = [
      for (final id in previousIds)
        if (!currentIdSet.contains(id) && existingById.containsKey(id)) id,
    ];

    final candidates = isFirstRun
        ? _provider.events
              .where(
                (e) =>
                    e.recurring &&
                    e.domain == EventDomain.academic &&
                    matchedExisting.contains(e.courseId),
              )
              .toList()
        : <ScheduleEvent>[];

    await _provider.applySyncBatch(
      courses: newCourses,
      upserts: upserts,
      deleteIds: deleteIds,
    );
    await _store.saveSnapshot(sourceId, current);

    return SyncSummary(
      changes: changes,
      isFirstRun: isFirstRun,
      replaceCandidates: candidates,
    );
  }

  /// Deletes the weekly sessions the user agreed to replace.
  Future<void> applyReplacement(List<String> eventIds) =>
      _provider.applySyncBatch(
        courses: const [],
        upserts: const [],
        deleteIds: eventIds,
      );

  static bool _same(ScheduleEvent a, ScheduleEvent b) =>
      a.title == b.title &&
      a.courseId == b.courseId &&
      a.type == b.type &&
      a.startTime == b.startTime &&
      a.endTime == b.endTime &&
      a.location == b.location &&
      a.notes == b.notes &&
      a.color == b.color;
}
