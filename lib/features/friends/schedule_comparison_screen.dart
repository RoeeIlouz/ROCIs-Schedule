import 'package:flutter/material.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:intl/intl.dart';

class ScheduleComparisonScreen extends StatelessWidget {
  final List<ScheduleEvent> myEvents;
  final List<ScheduleEvent> friendEvents;
  final String friendName;

  const ScheduleComparisonScreen({
    super.key,
    required this.myEvents,
    required this.friendEvents,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Comparison with $friendName')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Showing common free time and conflicting classes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 7, // Sun - Sat
              itemBuilder: (context, dayIndex) {
                final dayName = DateFormat.EEEE().format(
                  DateTime.now().subtract(
                    Duration(days: DateTime.now().weekday % 7 - dayIndex),
                  ),
                );
                final overlaps = _calculateOverlaps(dayIndex);

                return ExpansionTile(
                  title: Text(dayName),
                  children: overlaps
                      .map((o) => _OverlapTile(overlap: o))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TimeOverlap> _calculateOverlaps(int dayIndex) {
    // Basic logic: Find gaps where both are free
    // For now, let's just show a list of both people's events for that day
    final List<TimeOverlap> results = [];

    final myDayEvents = myEvents
        .where((e) => e.daysOfWeek.contains(dayIndex))
        .toList();
    final friendDayEvents = friendEvents
        .where((e) => e.daysOfWeek.contains(dayIndex))
        .toList();

    // Sort by start time
    myDayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
    friendDayEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Combine and identify conflicts vs free slots
    // This is a simplified version: just list the events
    for (var e in myDayEvents) {
      results.add(
        TimeOverlap(
          startTime: e.startTime,
          endTime: e.endTime,
          isConflict: true,
          label: 'My Class: ${e.title}',
        ),
      );
    }
    for (var e in friendDayEvents) {
      results.add(
        TimeOverlap(
          startTime: e.startTime,
          endTime: e.endTime,
          isConflict: true,
          label: '$friendName\'s Class: ${e.title}',
        ),
      );
    }

    results.sort((a, b) => a.startTime.compareTo(b.startTime));
    return results;
  }
}

class TimeOverlap {
  final DateTime startTime;
  final DateTime endTime;
  final bool isConflict;
  final String label;

  TimeOverlap({
    required this.startTime,
    required this.endTime,
    required this.isConflict,
    required this.label,
  });
}

class _OverlapTile extends StatelessWidget {
  final TimeOverlap overlap;
  const _OverlapTile({required this.overlap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        overlap.isConflict ? Icons.block : Icons.check_circle_outline,
        color: overlap.isConflict ? Colors.red : Colors.green,
      ),
      title: Text(overlap.label),
      subtitle: Text(
        '${DateFormat.jm().format(overlap.startTime)} - ${DateFormat.jm().format(overlap.endTime)}',
      ),
    );
  }
}
