import 'dart:convert';

import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last synced snapshot and sync settings per source id.
class SyncStore {
  static String _snapKey(String id) => 'calsync.snapshot.$id';
  static String _lastKey(String id) => 'calsync.last.$id';
  static String _verKey(String id) => 'calsync.ver.$id';
  static String _loginKey(String id) => 'calsync.needsLogin.$id';

  Future<List<SyncKeyed>> loadSnapshot(String sourceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapKey(sourceId));
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map((j) => _fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSnapshot(String sourceId, List<SyncKeyed> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _snapKey(sourceId),
      jsonEncode(list.map(_toJson).toList()),
    );
    await prefs.setString(_lastKey(sourceId), DateTime.now().toIso8601String());
    await prefs.setInt(_verKey(sourceId), formatVersion);
  }

  /// Calendar course name (normalized) to the user's course id; an empty id
  /// means "create a new course".
  Future<Map<String, String>> loadCourseMap(String sourceId) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      'calsync.map.$sourceId',
    );
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveCourseMap(String sourceId, Map<String, String> map) async =>
      (await SharedPreferences.getInstance()).setString(
        'calsync.map.$sourceId',
        jsonEncode(map),
      );

  /// Whether the user already answered "replace your weekly sessions?".
  Future<bool> replaceHandled(String sourceId) async =>
      (await SharedPreferences.getInstance()).getBool(
        'calsync.replaced.$sourceId',
      ) ??
      false;

  Future<void> setReplaceHandled(String sourceId) async =>
      (await SharedPreferences.getInstance()).setBool(
        'calsync.replaced.$sourceId',
        true,
      );

  /// Snapshots saved before [formatVersion] 2 were decoded as Latin-1.
  static const formatVersion = 2;

  Future<bool> isLegacy(String sourceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_verKey(sourceId)) != formatVersion;
  }

  Future<DateTime?> lastSync(String sourceId) async {
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(prefs.getString(_lastKey(sourceId)) ?? '');
  }

  Future<bool> needsLogin(String sourceId) async =>
      (await SharedPreferences.getInstance()).getBool(_loginKey(sourceId)) ??
      false;

  Future<void> setNeedsLogin(String sourceId, bool value) async =>
      (await SharedPreferences.getInstance()).setBool(
        _loginKey(sourceId),
        value,
      );

  static Map<String, dynamic> _toJson(SyncKeyed k) => {
    'key': k.key,
    'uid': k.entry.uid,
    'summary': k.entry.summary,
    'description': k.entry.description,
    'location': k.entry.location,
    'start': k.entry.start.toIso8601String(),
    'end': k.entry.end.toIso8601String(),
    'course': k.info.courseName,
    'lecturer': k.info.lecturer,
    'kind': k.info.kind.name,
    'cancelled': k.info.cancelled,
    'registered': k.info.registered,
  };

  static SyncKeyed _fromJson(Map<String, dynamic> j) => SyncKeyed(
    j['key'] as String,
    FeedEntry(
      uid: j['uid'] as String,
      summary: j['summary'] as String,
      description: j['description'] as String,
      location: j['location'] as String,
      start: DateTime.parse(j['start'] as String),
      end: DateTime.parse(j['end'] as String),
    ),
    Classified(
      courseName: j['course'] as String,
      lecturer: j['lecturer'] as String,
      kind: EntryKind.values.byName(j['kind'] as String),
      cancelled: j['cancelled'] as bool,
      registered: j['registered'] as bool,
    ),
  );
}
