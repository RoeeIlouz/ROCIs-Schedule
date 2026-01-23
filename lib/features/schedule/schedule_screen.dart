import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('schedule')),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: l10n.translate('today'),
            onPressed: () => setState(() => _selectedDate = DateTime.now()),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWeekStrip(),
          Expanded(
            child: Consumer<CourseProvider>(
              builder: (context, provider, child) {
                final dayEvents = provider.events.where((e) {
                  if (e.recurring) {
                    return e.daysOfWeek.contains(_selectedDate.weekday % 7);
                  }
                  return DateUtils.isSameDay(e.startTime, _selectedDate);
                }).toList();

                if (dayEvents.isEmpty) {
                  return Center(child: Text(l10n.translate('no_events')));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: dayEvents.length,
                  itemBuilder: (context, index) {
                    final event = dayEvents[index];
                    final course = provider.courses.firstWhere(
                      (c) => c.id == event.courseId,
                      orElse: () => Course(
                        id: 'unknown',
                        name: 'Unknown',
                        code: '???',
                        instructor: '',
                        color: Colors.grey,
                        credits: 0,
                      ),
                    );
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(24),
                        border: Border(
                          left: BorderSide(color: course.color, width: 6),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    event.title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _getEventIcon(event.type),
                                  color: course.color.withOpacity(0.7),
                                  size: 20,
                                ),
                              ],
                            ),
                            if (event.location.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                event.location,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildChip(
                                  context,
                                  _formatTime(event.startTime),
                                  Icons.access_time,
                                  const Color(0xFF261D18),
                                  const Color(0xFFE9B79B),
                                ),
                                const SizedBox(width: 8),
                                _buildChip(
                                  context,
                                  event.type.name.toUpperCase(),
                                  Icons.label_outline,
                                  const Color(0xFF18221D),
                                  const Color(0xFF9BE9BC),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/events/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat.jm().format(time);
  }

  Widget _buildWeekStrip() {
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday % 7),
    );
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = startOfWeek.add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final isToday = DateUtils.isSameDay(date, DateTime.now());

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE9B7B7)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: Colors.white24, width: 1)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getWeekdayName(date),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.black
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.black
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    String label,
    IconData icon,
    Color bgColor,
    Color fgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekdayName(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    if (l10n.locale.languageCode == 'he') {
      const days = ['א\'', 'ב\'', 'ג\'', 'ד\'', 'ה\'', 'ו\'', 'ש\''];
      return days[date.weekday % 7];
    }
    return DateFormat.E().format(date);
  }

  IconData _getEventIcon(EventType type) {
    switch (type) {
      case EventType.classType:
        return Icons.class_outlined;
      case EventType.exam:
        return Icons.assignment_outlined;
      case EventType.lab:
        return Icons.science_outlined;
      case EventType.study:
        return Icons.menu_book_outlined;
      case EventType.other:
        return Icons.event_outlined;
    }
  }
}
