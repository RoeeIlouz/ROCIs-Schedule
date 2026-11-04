import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/calendar_sync/services/sync_scheduler.dart';

void main() {
  final now = DateTime(2026, 11, 5, 12);

  test('never synced is due', () {
    expect(SyncScheduler.isDue(null, now), isTrue);
  });

  test('5h59m ago is not due', () {
    expect(
      SyncScheduler.isDue(
        now.subtract(const Duration(hours: 5, minutes: 59)),
        now,
      ),
      isFalse,
    );
  });

  test('6h ago is due', () {
    expect(
      SyncScheduler.isDue(now.subtract(const Duration(hours: 6)), now),
      isTrue,
    );
  });
}
