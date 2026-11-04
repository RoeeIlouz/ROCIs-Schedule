import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';

/// Why a calendar link could not be synced. [l10nKey] is the message shown.
enum CalendarSyncFailure {
  invalidUrl('calendar_sync_invalid_url'),
  network('calendar_sync_network_error'),
  notCalendar('calendar_sync_not_calendar'),
  empty('calendar_sync_empty');

  const CalendarSyncFailure(this.l10nKey);
  final String l10nKey;
}

class CalendarSyncException implements Exception {
  final CalendarSyncFailure failure;
  const CalendarSyncException(this.failure);

  @override
  String toString() => 'CalendarSyncException(${failure.name})';
}

/// What a sync changed.
class SubscriptionSyncResult {
  final int added;
  final int updated;
  final int removed;

  const SubscriptionSyncResult({
    this.added = 0,
    this.updated = 0,
    this.removed = 0,
  });

  bool get changed => added + updated + removed > 0;
}

/// A live (subscribed) calendar, such as the Afeka calendar feed: the link is
/// remembered and re-read to keep the timetable current.
///
/// Items that come from the link get ids starting with [idPrefix]; sync only
/// ever updates or removes those, never courses or events the user made.
class CalendarSubscriptionService {
  static const idPrefix = 'sub_';

  /// How long a sync stays fresh for the automatic (on open / resume) check.
  static const staleAfter = Duration(hours: 1);

  static const _timeout = Duration(seconds: 20);

  static bool isSubscriptionId(String id) => id.startsWith(idPrefix);

  /// The https/http address for what the user pasted, or null if it is not
  /// one. `webcal://` (what calendar apps hand out) is read over https.
  static Uri? normalizeUrl(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower.startsWith('webcals://')) {
      text = 'https://${text.substring('webcals://'.length)}';
    } else if (lower.startsWith('webcal://')) {
      text = 'https://${text.substring('webcal://'.length)}';
    }
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    return uri;
  }

  /// Downloads and parses the calendar at [url].
  ///
  /// Throws [CalendarSyncException]. A feed with no usable events counts as a
  /// failure ([CalendarSyncFailure.empty]) so a bad response can never be
  /// mistaken for "everything was deleted".
  static Future<IcsImportResult> fetch(
    String url, {
    http.Client? client,
  }) async {
    final uri = normalizeUrl(url);
    if (uri == null) {
      throw const CalendarSyncException(CalendarSyncFailure.invalidUrl);
    }

    final httpClient = client ?? http.Client();
    final String body;
    try {
      final response = await httpClient
          .get(uri, headers: const {'Accept': 'text/calendar, */*'})
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw const CalendarSyncException(CalendarSyncFailure.network);
      }
      // Calendars are UTF-8 (Hebrew titles); http would guess Latin-1.
      body = utf8.decode(response.bodyBytes, allowMalformed: true);
    } on CalendarSyncException {
      rethrow;
    } catch (_) {
      throw const CalendarSyncException(CalendarSyncFailure.network);
    } finally {
      if (client == null) httpClient.close();
    }

    if (!body.contains('BEGIN:VCALENDAR')) {
      throw const CalendarSyncException(CalendarSyncFailure.notCalendar);
    }
    final result = IcsImportService.parseIcsContent(body, idPrefix: idPrefix);
    if (result.events.isEmpty) {
      throw const CalendarSyncException(CalendarSyncFailure.empty);
    }
    return result;
  }

  // The link is stored per user, on this device.
  static String _urlKey(String uid) => 'calendar_subscription_url_$uid';
  static String _lastSyncKey(String uid) => 'calendar_subscription_sync_$uid';

  static Future<String?> savedUrl(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey(uid));
    return (url == null || url.isEmpty) ? null : url;
  }

  static Future<void> saveUrl(String uid, String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey(uid), url.trim());
  }

  static Future<DateTime?> lastSync(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastSyncKey(uid));
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<void> markSynced(String uid, DateTime when) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey(uid), when.millisecondsSinceEpoch);
  }

  /// Forgets the link. Courses and events already synced stay.
  static Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_urlKey(uid));
    await prefs.remove(_lastSyncKey(uid));
  }
}
