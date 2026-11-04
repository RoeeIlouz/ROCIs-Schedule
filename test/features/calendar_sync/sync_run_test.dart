import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rocis_schedule/features/calendar_sync/models/feed_entry.dart';
import 'package:rocis_schedule/features/calendar_sync/services/calendar_source.dart';
import 'package:rocis_schedule/features/calendar_sync/services/calendar_sync_service.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_store.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

class FakeSource implements CalendarSource {
  FetchResult result;
  FakeSource(this.result);
  @override
  String get id => 'fake';
  @override
  Future<FetchResult> fetch() async => result;
}

class FakeNotifier implements SyncNotifier {
  final List<List<SyncChange>> changeCalls = [];
  int loginCalls = 0;
  @override
  Future<void> changes(List<SyncChange> c) async => changeCalls.add(c);
  @override
  Future<void> loginExpired() async => loginCalls++;
}

String feed(List<String> events) =>
    'BEGIN:VCALENDAR\n${events.join('\n')}\nEND:VCALENDAR';

String ev(String uid, String day, String hour, {String room = '101'}) {
  final d = day.padLeft(2, '0');
  final h = hour.padLeft(2, '0');
  return 'BEGIN:VEVENT\nUID:$uid\nDTSTART:202611${d}T${h}0000\n'
      'DTEND:202611${d}T${h}5000\n'
      'SUMMARY:פיזיקה מר א\nDESCRIPTION:סוג מפגש: הרצאה\nLOCATION:$room\n'
      'END:VEVENT';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(CalendarSyncService, FakeNotifier, CourseProvider)> setup(
    String uid,
  ) async {
    await LocalDbService.clearCache();
    final db = await LocalDbService(uid).database;
    if (db != null) {
      await db.delete('events');
      await db.delete('courses');
    }
    final p = CourseProvider(uid);
    await p.loadData();
    final n = FakeNotifier();
    return (CalendarSyncService(p, SyncStore()), n, p);
  }

  test('first run applies silently; a later change notifies once', () async {
    final (svc, n, p) = await setup('run_basic');
    final src = FakeSource(FetchOk(feed([ev('1', '9', '9')])));
    var r = await svc.run(src, n);
    expect(r.status, SyncRunStatus.ok);
    expect(r.summary!.isFirstRun, isTrue);
    expect(n.changeCalls, isEmpty);
    expect(p.events, hasLength(1));

    src.result = FetchOk(feed([ev('1', '9', '9', room: '202')]));
    r = await svc.run(src, n);
    expect(n.changeCalls, hasLength(1));
    expect(n.changeCalls.single.single.kind, ChangeKind.roomChanged);
  });

  test('FetchOk with no changes does not notify', () async {
    final (svc, n, _) = await setup('run_nochange');
    final src = FakeSource(FetchOk(feed([ev('1', '9', '9')])));
    await svc.run(src, n);
    await svc.run(src, n);
    expect(n.changeCalls, isEmpty);
  });

  test('needs-login notifies once until a successful run', () async {
    final (svc, n, _) = await setup('run_login');
    final src = FakeSource(const FetchNeedsLogin());
    expect((await svc.run(src, n)).status, SyncRunStatus.needsLogin);
    await svc.run(src, n);
    expect(n.loginCalls, 1);

    src.result = FetchOk(feed([ev('1', '9', '9')]));
    await svc.run(src, n);
    src.result = const FetchNeedsLogin();
    await svc.run(src, n);
    expect(n.loginCalls, 2);
  });

  test('FetchFailed leaves everything untouched and silent', () async {
    final (svc, n, p) = await setup('run_fail');
    final src = FakeSource(FetchOk(feed([ev('1', '9', '9')])));
    await svc.run(src, n);
    src.result = const FetchFailed('timeout');
    final r = await svc.run(src, n);
    expect(r.status, SyncRunStatus.failed);
    expect(p.events, hasLength(1));
    expect(n.changeCalls, isEmpty);
    expect(n.loginCalls, 0);
  });

  test(
    'an empty parsed feed with a snapshot is a failure, nothing deleted',
    () async {
      final (svc, n, p) = await setup('run_empty');
      final src = FakeSource(FetchOk(feed([ev('1', '9', '9')])));
      await svc.run(src, n);
      src.result = FetchOk(feed([]));
      final r = await svc.run(src, n);
      expect(r.status, SyncRunStatus.failed);
      expect(p.events, hasLength(1));
    },
  );
}
