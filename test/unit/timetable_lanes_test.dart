import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/schedule/widgets/weekly_timetable_grid.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

ScheduleEvent _event(String id, int startHour, int endHour) => ScheduleEvent(
  id: id,
  courseId: '',
  title: id,
  type: EventType.other,
  startTime: DateTime(2026, 10, 4, startHour),
  endTime: DateTime(2026, 10, 4, endHour),
  location: '',
);

void main() {
  test('Non-overlapping events each take the full width', () {
    final lanes = layoutEventLanes([_event('a', 9, 10), _event('b', 10, 11)]);
    expect(lanes['a'], (lane: 0, lanes: 1));
    expect(lanes['b'], (lane: 0, lanes: 1));
  });

  test('Overlapping events sit side by side', () {
    final lanes = layoutEventLanes([_event('a', 9, 11), _event('b', 10, 12)]);
    expect(lanes['a'], (lane: 0, lanes: 2));
    expect(lanes['b'], (lane: 1, lanes: 2));
  });

  test('A freed lane is reused within the same overlap cluster', () {
    final lanes = layoutEventLanes([
      _event('long', 9, 13),
      _event('first', 9, 10),
      _event('second', 11, 12),
    ]);
    expect(lanes['long']!.lanes, 2);
    expect(lanes['first']!.lane, lanes['second']!.lane);
    expect(lanes['first']!.lane, isNot(lanes['long']!.lane));
  });
}
