import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rocis_schedule/features/calendar_sync/services/calendar_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncKind { off, afeka, publicIcs }

/// What the user set up. The feed link (it carries a personal token) and the
/// Afeka session cookies live in secure storage and are never logged.
class SyncConfig {
  static const _kind = 'calsync.kind';
  static const _uid = 'calsync.uid';
  static const _url = 'calsync.feedUrl';
  static const _cookie = 'calsync.cookie';

  final FlutterSecureStorage _secure;

  SyncConfig({FlutterSecureStorage? secure})
    : _secure = secure ?? const FlutterSecureStorage();

  Future<SyncKind> kind() async {
    final prefs = await SharedPreferences.getInstance();
    return SyncKind.values.asNameMap()[prefs.getString(_kind)] ?? SyncKind.off;
  }

  Future<String?> userId() async =>
      (await SharedPreferences.getInstance()).getString(_uid);

  Future<String?> feedUrl() => _read(_url);

  Future<String?> cookieHeader() => _read(_cookie);

  Future<void> saveCookieHeader(String? value) =>
      value == null ? _delete(_cookie) : _write(_cookie, value);

  Future<void> enable({
    required SyncKind kind,
    required String userId,
    required String feedUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kind, kind.name);
    await prefs.setString(_uid, userId);
    await _write(_url, feedUrl);
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kind, SyncKind.off.name);
    await _delete(_cookie);
  }

  /// The source for the saved setup, or null when sync is off or incomplete.
  Future<CalendarSource?> buildSource() async {
    final kind = await this.kind();
    final raw = await feedUrl();
    final url = raw == null ? null : Uri.tryParse(raw);
    if (kind == SyncKind.off || url == null || !url.hasScheme) return null;
    return kind == SyncKind.afeka
        ? AfekaSource(url, cookieHeader)
        : PublicIcsSource(url);
  }

  Future<String?> _read(String key) async {
    try {
      return await _secure.read(key: key);
    } catch (e) {
      debugPrint('SyncConfig: secure read failed');
      return null;
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (e) {
      debugPrint('SyncConfig: secure write failed');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (e) {
      debugPrint('SyncConfig: secure delete failed');
    }
  }
}
