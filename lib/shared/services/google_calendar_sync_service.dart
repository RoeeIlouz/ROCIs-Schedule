import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:rocis_schedule/core/config/app_config.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/services/google_calendar_event_builder.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CalendarSyncStatus { off, syncing, synced, needsAccess, error }

/// Mirrors the schedule into a dedicated "ROCIs Schedule" calendar in the
/// user's Google account.
///
/// Uses the `calendar.app.created` scope, so it can only see and change the
/// calendar it created. Each sync reconciles the whole calendar: events are
/// written only when their content hash changed, and events no longer in the
/// schedule are deleted. Google event ids derive from schedule event ids, so
/// syncing is idempotent.
class GoogleCalendarSyncService extends ChangeNotifier {
  static const _base = 'https://www.googleapis.com/calendar/v3';
  static const _keyEnabled = 'gcal_sync_enabled';
  static const _keyCalendarId = 'gcal_calendar_id';
  static const _debounce = Duration(seconds: 3);
  static const _profileField = 'googleCalendarId';

  final AuthService _auth;
  final http.Client _http;
  final FirestoreService _firestore;
  CourseProvider? _courses;
  ThemeProvider? _theme;

  bool _enabled = false;
  String? _calendarId;
  CalendarSyncStatus _status = CalendarSyncStatus.off;
  int _syncedCount = 0;
  Timer? _debounceTimer;
  bool _running = false;
  bool _rerun = false;
  bool _disposed = false;

  /// Saved settings; every entry point awaits this so a late load can't
  /// overwrite a choice the user just made.
  late final Future<void> _ready = _load();

  GoogleCalendarSyncService(
    this._auth, {
    http.Client? client,
    FirestoreService? firestore,
  }) : _http = client ?? http.Client(),
       _firestore = firestore ?? FirestoreService() {
    _ready;
  }

  /// Calendar sync uses native Google Sign-In: Android builds from Google
  /// Play only (GitHub builds have no verified Android OAuth client).
  static bool get isSupported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      !AppConfig.isGithubBuild;

  bool get enabled => _enabled;
  CalendarSyncStatus get status => _status;
  int get syncedCount => _syncedCount;

  /// A short technical reason for the last failure, shown to help support.
  String? get lastError => _lastError;
  String? _lastError;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = isSupported && (prefs.getBool(_keyEnabled) ?? false);
    _calendarId = prefs.getString(_keyCalendarId);
    if (_enabled) {
      _setStatus(CalendarSyncStatus.synced);
      _scheduleSync();
    }
  }

  /// Follows the providers of the current user (they change on sign-in).
  void attach(CourseProvider courses, ThemeProvider theme) {
    if (!identical(_courses, courses)) {
      _courses?.removeListener(_scheduleSync);
      _courses = courses..addListener(_scheduleSync);
      _scheduleSync();
    }
    _theme = theme;
  }

  /// Asks for access, creates the calendar and runs the first sync.
  /// Returns false if the user declined.
  Future<bool> enable() async {
    await _ready;
    _lastError = null;
    final headers = await _auth.googleCalendarHeaders(interactive: true);
    if (headers == null) {
      _lastError = _auth.lastCalendarAuthError ?? 'cancelled';
      return false;
    }
    _enabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, true);
    await syncNow();
    return _status == CalendarSyncStatus.synced;
  }

  /// Stops syncing; with [removeCalendar] also deletes the calendar and its
  /// events from Google Calendar.
  Future<void> disable({required bool removeCalendar}) async {
    await _ready;
    _debounceTimer?.cancel();
    _enabled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, false);
    final id = _calendarId;
    if (removeCalendar && id != null) {
      try {
        await _send('DELETE', '/calendars/${Uri.encodeComponent(id)}');
        await _forgetCalendar();
      } on _HttpFailure catch (e) {
        if (e.statusCode == 404 || e.statusCode == 410) {
          await _forgetCalendar();
        } else {
          // Keep the id: forgetting it would leave the calendar behind and
          // make the next sync create a duplicate.
          _lastError = e.reason;
          debugPrint('Calendar removal failed: $e');
        }
      } catch (e) {
        _lastError = e.toString();
        debugPrint('Calendar removal failed: $e');
      }
    }
    _setStatus(CalendarSyncStatus.off);
  }

  void _scheduleSync() {
    if (!_enabled || _disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, syncNow);
  }

  /// Reconciles the Google calendar with the schedule.
  Future<void> syncNow() async {
    await _ready;
    if (!_enabled || _disposed) return;
    final courses = _courses;
    if (courses == null || courses.isLoading) {
      _scheduleSync();
      return;
    }
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    _setStatus(CalendarSyncStatus.syncing);
    try {
      do {
        _rerun = false;
        await _reconcile(courses);
      } while (_rerun && !_disposed);
      _lastError = null;
      _setStatus(CalendarSyncStatus.synced);
    } on _NeedsAccess {
      _lastError = _auth.lastCalendarAuthError ?? 'access not granted';
      _setStatus(CalendarSyncStatus.needsAccess);
    } catch (e) {
      debugPrint('Google Calendar sync failed: $e');
      _lastError = e is _HttpFailure ? e.reason : e.toString();
      _setStatus(CalendarSyncStatus.error);
    } finally {
      _running = false;
    }
  }

  Future<void> _reconcile(CourseProvider provider) async {
    final timeZone = await _deviceTimeZone();
    final calendarId = await _ensureCalendar(timeZone);
    final eventsPath = '/calendars/${Uri.encodeComponent(calendarId)}/events';

    // Desired state.
    final courses = {for (final c in provider.courses) c.id: c};
    final labels = _labels();
    final reminder = _theme?.reminderLeadMinutes ?? 15;
    final desired = <String, Map<String, dynamic>>{};
    for (final event in provider.events) {
      final course = courses[event.courseId];
      // Same bounds as the schedule screen (CourseProvider.occursOn): a
      // course without a semester repeats without an end date.
      final semester = provider.getSemesterById(course?.semester);
      desired[GoogleCalendarEventBuilder.googleEventId(
        event.id,
      )] = GoogleCalendarEventBuilder.build(
        event: event,
        course: course,
        semester: semester,
        timeZone: timeZone,
        reminderMinutes: reminder,
        labels: labels,
      );
    }

    // Current state (id -> content hash).
    final existing = <String, String?>{};
    String? pageToken;
    do {
      final page = await _send(
        'GET',
        eventsPath,
        query: {
          'maxResults': '2500',
          'showDeleted': 'false',
          'fields': 'items(id,extendedProperties),nextPageToken',
          'pageToken': ?pageToken,
        },
      );
      for (final item in (page['items'] as List? ?? const [])) {
        final map = item as Map<String, dynamic>;
        final private = (map['extendedProperties'] as Map?)?['private'] as Map?;
        existing[map['id'] as String] = private?['rocisHash'] as String?;
      }
      pageToken = page['nextPageToken'] as String?;
    } while (pageToken != null);

    for (final entry in desired.entries) {
      final hash =
          (entry.value['extendedProperties'] as Map)['private']['rocisHash'];
      final path = '$eventsPath/${entry.key}';
      if (!existing.containsKey(entry.key)) {
        try {
          await _send(
            'POST',
            eventsPath,
            body: {...entry.value, 'id': entry.key},
          );
        } on _HttpFailure catch (e) {
          // A previously deleted event keeps its id; updating restores it.
          if (e.statusCode != 409) rethrow;
          await _send('PUT', path, body: entry.value);
        }
      } else if (existing[entry.key] != hash) {
        await _send('PUT', path, body: entry.value);
      }
    }
    for (final id in existing.keys) {
      if (desired.containsKey(id)) continue;
      try {
        await _send('DELETE', '$eventsPath/$id');
      } on _HttpFailure catch (e) {
        if (e.statusCode != 404 && e.statusCode != 410) rethrow;
      }
    }
    _syncedCount = desired.length;
  }

  /// The app's calendar: the one remembered on this device or in the user's
  /// profile, or a new one if it no longer exists. The Calendar scope can't
  /// list calendars, so remembering the id is what prevents duplicates.
  Future<String> _ensureCalendar(String timeZone) async {
    for (final id in {?_calendarId, ?await _profileCalendarId()}) {
      try {
        await _send('GET', '/calendars/${Uri.encodeComponent(id)}');
        await _rememberCalendar(id);
        return id;
      } on _HttpFailure catch (e) {
        if (e.statusCode != 404 && e.statusCode != 410) rethrow;
      }
    }
    final created = await _send(
      'POST',
      '/calendars',
      body: {
        'summary': 'ROCIs Schedule',
        'description': _l10n().translate('gcal_calendar_desc'),
        'timeZone': timeZone,
      },
    );
    final newId = created['id'] as String;
    await _rememberCalendar(newId);
    return newId;
  }

  Future<String?> _profileCalendarId() async {
    final uid = _auth.user?.uid;
    if (uid == null) return null;
    try {
      final profile = await _firestore.getProfile(uid);
      final data = profile?.data() as Map<String, dynamic>?;
      return data?[_profileField] as String?;
    } catch (e) {
      debugPrint('Reading calendar id from profile failed: $e');
      return null;
    }
  }

  Future<void> _rememberCalendar(String id) async {
    final changed = _calendarId != id;
    _calendarId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCalendarId, id);
    final uid = _auth.user?.uid;
    if (changed && uid != null) {
      unawaited(
        _firestore
            .updateProfile(uid, {_profileField: id})
            .catchError((Object e) => debugPrint('Saving calendar id: $e')),
      );
    }
  }

  Future<void> _forgetCalendar() async {
    _calendarId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCalendarId);
    final uid = _auth.user?.uid;
    if (uid != null) {
      unawaited(
        _firestore
            .updateProfile(uid, {_profileField: null})
            .catchError((Object e) => debugPrint('Clearing calendar id: $e')),
      );
    }
  }

  Future<String> _deviceTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone().timeout(
        const Duration(seconds: 2),
      );
      if (info.identifier.isNotEmpty) return info.identifier;
    } catch (e) {
      debugPrint('Time zone lookup failed: $e');
    }
    return 'UTC';
  }

  /// Sends a Calendar API request, refreshing the token once on 401.
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final headers = await _auth.googleCalendarHeaders(
        interactive: false,
        refresh: attempt > 0,
      );
      if (headers == null) throw const _NeedsAccess();
      final request =
          http.Request(
              method,
              Uri.parse('$_base$path').replace(queryParameters: query),
            )
            ..headers.addAll({
              ...headers,
              'Content-Type': 'application/json; charset=utf-8',
            });
      // Titles and descriptions carry "·", "—" and Hebrew/Arabic text.
      if (body != null) request.bodyBytes = utf8.encode(jsonEncode(body));
      final response = await http.Response.fromStream(
        await _http.send(request),
      );
      if (response.statusCode == 401 && attempt == 0) continue;
      // 403 also covers rate limits; only permission failures need the
      // user to reconnect.
      if (response.statusCode == 401 ||
          (response.statusCode == 403 &&
              response.body.contains('insufficientPermissions'))) {
        throw const _NeedsAccess();
      }
      if (response.statusCode >= 300) {
        throw _HttpFailure(response.statusCode, response.body);
      }
      return response.body.isEmpty
          ? const {}
          : jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw const _NeedsAccess();
  }

  AppLocalizations _l10n() {
    final locale = _theme?.locale ?? PlatformDispatcher.instance.locale;
    final supported = AppLocalizations.supportedLocales.any(
      (l) => l.languageCode == locale.languageCode,
    );
    return AppLocalizations(supported ? locale : const Locale('en'));
  }

  CalendarEventLabels _labels() {
    final l10n = _l10n();
    return CalendarEventLabels(
      course: l10n.translate('course'),
      instructor: l10n.translate('instructor'),
      type: l10n.translate('type'),
      credits: l10n.translate('credits_label'),
      semester: l10n.translate('semester'),
      category: l10n.translate('gcal_category'),
      footer: l10n.translate('gcal_footer'),
      typeName: (type) => l10n.translate(switch (type) {
        EventType.classType => 'class_type',
        EventType.exam => 'exam',
        EventType.lab => 'lab',
        EventType.study => 'study',
        EventType.other => 'other',
      }),
      domainName: (domain) => l10n.translate(switch (domain) {
        EventDomain.academic => 'domain_academic',
        EventDomain.work => 'domain_work',
        EventDomain.personal => 'domain_personal',
      }),
    );
  }

  void _setStatus(CalendarSyncStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _courses?.removeListener(_scheduleSync);
    _http.close();
    super.dispose();
  }
}

class _NeedsAccess implements Exception {
  const _NeedsAccess();
}

class _HttpFailure implements Exception {
  final int statusCode;
  final String body;
  const _HttpFailure(this.statusCode, this.body);

  /// Google's own error message, e.g. that the Calendar API is disabled.
  String get reason {
    try {
      final error = (jsonDecode(body) as Map)['error'] as Map;
      return 'HTTP $statusCode: ${error['message']}';
    } catch (_) {
      return 'HTTP $statusCode';
    }
  }

  @override
  String toString() => 'HTTP $statusCode: $body';
}
