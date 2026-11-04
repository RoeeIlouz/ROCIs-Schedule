import 'dart:ui' show Color;

import 'package:uuid/uuid.dart';
import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';
import 'package:rocis_schedule/features/calendar_sync/services/afeka_classifier.dart';
import 'package:rocis_schedule/features/calendar_sync/services/calendar_source.dart';
import 'package:rocis_schedule/features/calendar_sync/services/feed_differ.dart';
import 'package:rocis_schedule/features/calendar_sync/services/feed_parser.dart';
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
    this.unmappedCourses = const [],
  });

  /// Calendar course names with no matching course yet; their sessions are
  /// held back until the user maps them (see [SyncStore.saveCourseMap]).
  final List<String> unmappedCourses;
}

/// Where sync results are shown to the user.
abstract class SyncNotifier {
  Future<void> changes(List<SyncChange> changes);
  Future<void> loginExpired();
}

enum SyncRunStatus { ok, needsLogin, failed }

class SyncRunResult {
  final SyncRunStatus status;
  final SyncSummary? summary;
  const SyncRunResult(this.status, [this.summary]);
}

/// Applies a parsed calendar feed to the schedule. Events it creates are
/// ordinary one-time [ScheduleEvent]s with deterministic ids, so the app
/// needs no extra schema and two devices converge on the same events.
class CalendarSyncService {
  final CourseProvider _provider;
  final SyncStore _store;
  final String cancelledLabel;

  /// When false (the app), a course name that matches none of the user's
  /// courses is not created behind their back; see [SyncSummary.unmappedCourses].
  final bool autoCreateCourses;

  CalendarSyncService(
    this._provider,
    this._store, {
    this.cancelledLabel = 'Cancelled',
    this.autoCreateCourses = true,
  });

  /// The one course whose name contains, or is contained in, [name]; null
  /// when none or several do (ambiguous matches are left to the user).
  static Course? _fuzzyMatch(String name, List<Course> courses) {
    final n = name.toLowerCase();
    if (n.length < 3) return null;
    final hits = courses.where((c) {
      final other = AfekaClassifier.normalizeName(c.name).toLowerCase();
      return other.length >= 3 && (other.contains(n) || n.contains(other));
    }).toList();
    return hits.length == 1 ? hits.single : null;
  }

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

    // Courses are matched to the user's existing ones, never overwritten:
    // saved mapping, then identical name, then a course this sync made, then
    // one unambiguous partial name match. A name that matches none is created
    // only if the user said so (or [autoCreateCourses]); otherwise its
    // entries wait in [SyncSummary.unmappedCourses] for the user to choose.
    final mapping = await _store.loadCourseMap(sourceId);
    final byId = {for (final c in _provider.courses) c.id: c};
    final byName = <String, Course>{
      for (final c in _provider.courses)
        AfekaClassifier.normalizeName(c.name): c,
    };
    final matchedExisting = <String>{};
    final newCourses = <Course>[];
    Course create(String name) {
      final created = Course(
        id: _courseId(sourceId, name),
        name: name,
        code: '',
        instructor: '',
        color: _palette[byName.length % _palette.length],
        credits: 0,
      );
      byName[name] = created;
      byId[created.id] = created;
      newCourses.add(created);
      return created;
    }

    Course? resolve(String rawName) {
      final name = AfekaClassifier.normalizeName(rawName);
      final mapped = mapping[name];
      Course? found = (mapped != null && mapped.isNotEmpty)
          ? byId[mapped]
          : null;
      found ??= byName[name] ?? byId[_courseId(sourceId, name)];
      if (found != null) {
        if (!newCourses.any((c) => c.id == found!.id)) {
          matchedExisting.add(found.id);
        }
        return found;
      }
      if (mapped == '') return create(name);
      final fuzzy = _fuzzyMatch(name, _provider.courses);
      if (fuzzy != null) {
        matchedExisting.add(fuzzy.id);
        return fuzzy;
      }
      return autoCreateCourses ? create(name) : null;
    }

    final unmapped = <String>{};
    current.removeWhere((k) {
      if (resolve(k.info.courseName) != null) return false;
      unmapped.add(AfekaClassifier.normalizeName(k.info.courseName));
      return true;
    });

    var previous = await _store.loadSnapshot(sourceId);
    // A snapshot written before the UTF-8 fix holds unreadable text: remove
    // what it created and start over as a first run.
    final legacy = previous.isNotEmpty && await _store.isLegacy(sourceId);
    final legacyPrevious = legacy ? previous : const <SyncKeyed>[];
    if (legacy) previous = const [];
    final isFirstRun = previous.isEmpty;
    final changes = FeedDiffer.diff(previous, current);

    final currentIds = _ids(sourceId, current);
    final previousIds = {
      ..._ids(sourceId, previous),
      ..._ids(sourceId, legacyPrevious),
    };

    final existingById = {for (final e in _provider.events) e.id: e};
    final upserts = <ScheduleEvent>[];
    for (var i = 0; i < current.length; i++) {
      final k = current[i];
      final course = resolve(k.info.courseName)!;
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

    final candidates = !await _store.replaceHandled(sourceId)
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

    // Courses the legacy snapshot created and nothing uses any more.
    for (final k in legacyPrevious) {
      final id = _courseId(
        sourceId,
        AfekaClassifier.normalizeName(k.info.courseName),
      );
      final exists = _provider.courses.any((c) => c.id == id);
      if (exists && !_provider.events.any((e) => e.courseId == id)) {
        await _provider.deleteCourse(id);
      }
    }

    return SyncSummary(
      changes: changes,
      isFirstRun: isFirstRun,
      replaceCandidates: candidates,
      unmappedCourses: unmapped.toList(),
    );
  }

  /// Fetches [source], applies the result and tells [notifier] what changed.
  /// A failed fetch or an empty feed never touches the schedule.
  Future<SyncRunResult> run(
    CalendarSource source,
    SyncNotifier notifier,
  ) async {
    final result = await source.fetch();
    switch (result) {
      case FetchNeedsLogin():
        if (!await _store.needsLogin(source.id)) {
          await _store.setNeedsLogin(source.id, true);
          await notifier.loginExpired();
        }
        return const SyncRunResult(SyncRunStatus.needsLogin);
      case FetchFailed():
        return const SyncRunResult(SyncRunStatus.failed);
      case FetchOk(:final body):
        try {
          final summary = await applyEntries(source.id, FeedParser.parse(body));
          await _store.setNeedsLogin(source.id, false);
          if (!summary.isFirstRun && summary.changes.isNotEmpty) {
            await notifier.changes(summary.changes);
          }
          return SyncRunResult(SyncRunStatus.ok, summary);
        } on FeedLooksEmpty {
          return const SyncRunResult(SyncRunStatus.failed);
        }
    }
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
