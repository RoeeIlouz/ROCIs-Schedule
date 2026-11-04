import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rocis_schedule/features/calendar_sync/services/calendar_source.dart';

const _ics = 'BEGIN:VCALENDAR\nBEGIN:VEVENT\nEND:VEVENT\nEND:VCALENDAR';

void main() {
  final url = Uri.parse('https://yedion.example.ac.il/feed?token=SECRET');

  AfekaSource afeka(http.Client c, {String? cookie = 'sid=abc'}) =>
      AfekaSource(url, () async => cookie, client: c);

  test('200 with BEGIN:VCALENDAR gives FetchOk', () async {
    final r = await afeka(
      MockClient((_) async => http.Response(_ics, 200)),
    ).fetch();
    expect(r, isA<FetchOk>());
    expect((r as FetchOk).body, _ics);
  });

  test('redirect to an sso host gives FetchNeedsLogin', () async {
    final r = await afeka(
      MockClient(
        (_) async => http.Response(
          '',
          302,
          headers: {'location': 'https://sso.example.ac.il/login'},
        ),
      ),
    ).fetch();
    expect(r, isA<FetchNeedsLogin>());
  });

  test('200 html login page gives FetchNeedsLogin, never FetchOk', () async {
    final r = await afeka(
      MockClient((_) async => http.Response('<html>login</html>', 200)),
    ).fetch();
    expect(r, isA<FetchNeedsLogin>());
  });

  test('missing cookie gives FetchNeedsLogin without any request', () async {
    var called = false;
    final r = await afeka(
      MockClient((_) async {
        called = true;
        return http.Response(_ics, 200);
      }),
      cookie: null,
    ).fetch();
    expect(r, isA<FetchNeedsLogin>());
    expect(called, isFalse);
  });

  test('network errors give FetchFailed', () async {
    final r = await afeka(
      MockClient((_) async => throw const SocketException('down')),
    ).fetch();
    expect(r, isA<FetchFailed>());
    final t = await afeka(
      MockClient((_) async {
        throw TimeoutException('slow');
      }),
    ).fetch();
    expect(t, isA<FetchFailed>());
  });

  test('server error gives FetchFailed', () async {
    final r = await afeka(
      MockClient((_) async => http.Response('x', 500)),
    ).fetch();
    expect(r, isA<FetchFailed>());
  });

  test(
    'request carries the Cookie header; failure reason never has it',
    () async {
      String? sent;
      await afeka(
        MockClient((req) async {
          sent = req.headers['cookie'];
          return http.Response(_ics, 200);
        }),
      ).fetch();
      expect(sent, 'sid=abc');

      final r =
          await afeka(MockClient((_) async => http.Response('x', 500))).fetch()
              as FetchFailed;
      expect(r.reason, isNot(contains('sid=abc')));
      expect(r.reason, isNot(contains('SECRET')));
    },
  );

  test('cookie is not forwarded to a different host', () async {
    final seen = <String, String?>{};
    await afeka(
      MockClient((req) async {
        seen[req.url.host] = req.headers['cookie'];
        if (req.url.host == 'yedion.example.ac.il') {
          return http.Response(
            '',
            302,
            headers: {'location': 'https://other.example.com/x'},
          );
        }
        return http.Response(_ics, 200);
      }),
    ).fetch();
    expect(seen['other.example.com'], isNull);
  });

  test('public source accepts a calendar and rejects html', () async {
    final ok = await PublicIcsSource(
      url,
      client: MockClient((_) async => http.Response(_ics, 200)),
    ).fetch();
    expect(ok, isA<FetchOk>());
    final bad = await PublicIcsSource(
      url,
      client: MockClient((_) async => http.Response('<html/>', 200)),
    ).fetch();
    expect(bad, isA<FetchFailed>());
  });
}
