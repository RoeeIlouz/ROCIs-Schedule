import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:rocis_schedule/features/calendar_sync/services/feed_parser.dart';

sealed class FetchResult {
  const FetchResult();
}

class FetchOk extends FetchResult {
  final String body;
  const FetchOk(this.body);
}

/// The feed wants a (new) sign-in. Never to be parsed as an empty calendar.
class FetchNeedsLogin extends FetchResult {
  const FetchNeedsLogin();
}

class FetchFailed extends FetchResult {
  /// Safe to show or log: never contains the URL or cookies.
  final String reason;
  const FetchFailed(this.reason);
}

abstract class CalendarSource {
  String get id;
  Future<FetchResult> fetch();
}

const _timeout = Duration(seconds: 20);
const _maxRedirects = 5;

bool _looksLikeLoginHost(Uri u) {
  final h = u.host.toLowerCase();
  return h.startsWith('sso.') ||
      h.contains('login') ||
      u.path.toLowerCase().contains('login');
}

/// Fetches [url], following redirects by hand so a [cookie] is only sent to
/// the original host. [loginOnHtml] turns a 200 non-calendar page (a login
/// form) into [FetchNeedsLogin].
Future<FetchResult> _get(
  http.Client client,
  Uri url, {
  String? cookie,
  required bool loginOnHtml,
}) async {
  try {
    var target = url;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      final req = http.Request('GET', target)..followRedirects = false;
      if (cookie != null && target.host == url.host) {
        req.headers['cookie'] = cookie;
      }
      final streamed = await client.send(req).timeout(_timeout);
      final res = await http.Response.fromStream(streamed).timeout(_timeout);

      if (res.statusCode >= 300 && res.statusCode < 400) {
        final loc = res.headers['location'];
        if (loc == null) return const FetchFailed('redirect without target');
        target = target.resolve(loc);
        if (_looksLikeLoginHost(target)) return const FetchNeedsLogin();
        continue;
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return const FetchNeedsLogin();
      }
      if (res.statusCode != 200) {
        return FetchFailed('http ${res.statusCode}');
      }
      // Calendars are UTF-8; the server may omit the charset, in which case
      // `res.body` would decode the Hebrew as Latin-1.
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (FeedParser.looksLikeCalendar(body)) return FetchOk(body);
      return loginOnHtml
          ? const FetchNeedsLogin()
          : const FetchFailed('response is not a calendar');
    }
    return const FetchFailed('too many redirects');
  } on TimeoutException {
    return const FetchFailed('timeout');
  } catch (_) {
    return const FetchFailed('network error');
  }
}

/// A public `.ics` link that needs no sign-in.
class PublicIcsSource implements CalendarSource {
  final Uri url;
  final http.Client _client;

  PublicIcsSource(this.url, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => 'public:${url.host}';

  @override
  Future<FetchResult> fetch() => _get(_client, url, loginOnHtml: false);
}

/// Afeka Yedion: a personal feed link that only answers a signed-in session.
/// [cookieHeader] supplies the session cookies (null = not signed in).
class AfekaSource implements CalendarSource {
  final Uri feedUrl;
  final Future<String?> Function() cookieHeader;
  final http.Client _client;

  AfekaSource(this.feedUrl, this.cookieHeader, {http.Client? client})
    : _client = client ?? http.Client();

  @override
  String get id => 'afeka';

  @override
  Future<FetchResult> fetch() async {
    final cookie = await cookieHeader();
    if (cookie == null || cookie.isEmpty) return const FetchNeedsLogin();
    return _get(_client, feedUrl, cookie: cookie, loginOnHtml: true);
  }
}
