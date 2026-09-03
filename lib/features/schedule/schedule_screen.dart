import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  EventType? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final courseProvider = context.watch<CourseProvider?>();

    if (courseProvider == null || courseProvider.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.translate('loading')),
            ],
          ),
        ),
      );
    }

    final courses = {for (var c in courseProvider.courses) c.id: c};
    final dayOfWeek = _selectedDate.weekday % 7;

    // Filter events for the selected day and active category filter
    final dayEvents =
        courseProvider.events.where((event) {
          final matchesDay = event.recurring
              ? event.daysOfWeek.contains(dayOfWeek)
              : DateUtils.isSameDay(event.startTime, _selectedDate);
          if (!matchesDay) {
            return false;
          }
          if (_selectedFilter != null && event.type != _selectedFilter) {
            return false;
          }
          return true;
        }).toList()..sort((a, b) {
          final timeA = a.startTime.hour * 60 + a.startTime.minute;
          final timeB = b.startTime.hour * 60 + b.startTime.minute;
          return timeA.compareTo(timeB);
        });

    final upcomingExams = courseProvider.events.where((e) {
      if (e.type != EventType.exam) return false;
      final now = DateTime.now();
      return e.startTime.isAfter(now.subtract(const Duration(hours: 2))) &&
          e.startTime.isBefore(now.add(const Duration(days: 30)));
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('MMMM yyyy').format(_selectedDate),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: l10n.translate('today'),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDate = DateTime.now());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (upcomingExams.isNotEmpty)
            _buildUpcomingExamsBanner(upcomingExams, courses, l10n),
          _buildWeekStrip(courseProvider.events),
          const SizedBox(height: 6),
          _buildFilterChips(l10n),
          const SizedBox(height: 8),
          Expanded(
            child: dayEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy_outlined,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.translate('no_events'),
                          style: TextStyle(
                            color: Theme.of(context).disabledColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: dayEvents.length,
                    itemBuilder: (context, index) {
                      final event = dayEvents[index];
                      final course = courses[event.courseId];
                      return _buildEventCard(context, event, course);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/schedule/add'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n) {
    final filters = [
      (null, l10n.translate('filter_all')),
      (EventType.classType, l10n.translate('filter_classes')),
      (EventType.exam, l10n.translate('filter_exams')),
      (EventType.lab, l10n.translate('filter_labs')),
      (EventType.study, l10n.translate('filter_study')),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (type, label) = filters[index];
          final isSelected = _selectedFilter == type;
          return FilterChip(
            label: Text(label),
            selected: isSelected,
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(() => _selectedFilter = type);
            },
          );
        },
      ),
    );
  }

  Widget _buildUpcomingExamsBanner(
    List<ScheduleEvent> exams,
    Map<String, Course> courses,
    AppLocalizations l10n,
  ) {
    return SizedBox(
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: exams.length,
        itemBuilder: (context, index) {
          final exam = exams[index];
          final course = courses[exam.courseId];
          final diff = exam.startTime.difference(DateTime.now());
          final daysLeft = diff.inDays;
          String timeText;
          if (diff.isNegative) {
            timeText = l10n.translate('in_progress');
          } else if (daysLeft == 0) {
            timeText = l10n
                .translate('today_at')
                .replaceAll('{time}', DateFormat.Hm().format(exam.startTime));
          } else if (daysLeft == 1) {
            timeText = l10n.translate('tomorrow');
          } else {
            timeText = l10n
                .translate('days_left')
                .replaceAll('{days}', daysLeft.toString());
          }

          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12),
            child: GlassContainer(
              tintColor: const Color(0xFFFF5252),
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.assignment_late_rounded,
                      color: Color(0xFFFF5252),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          exam.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (course != null)
                          Text(
                            course.name,
                            style: TextStyle(
                              color: course.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          timeText,
                          style: const TextStyle(
                            color: Color(0xFFFF5252),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  String _getEventTypeName(EventType type, AppLocalizations l10n) {
    switch (type) {
      case EventType.classType:
        return l10n.translate('class_type');
      case EventType.exam:
        return l10n.translate('exam');
      case EventType.lab:
        return l10n.translate('lab');
      case EventType.study:
        return l10n.translate('study');
      case EventType.other:
        return l10n.translate('other');
    }
  }

  Widget _buildEventCard(
    BuildContext context,
    ScheduleEvent event,
    Course? course,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final courseColor = course?.color ?? theme.colorScheme.primary;

    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context, l10n, event.title);
      },
      onDismissed: (direction) {
        context.read<CourseProvider>().deleteEvent(event.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('event_deleted'))),
        );
      },
      child: GlassContainer(
        tintColor: courseColor,
        margin: const EdgeInsets.only(bottom: 12),
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 38,
                  decoration: BoxDecoration(
                    color: courseColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: courseColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (course != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          course.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: courseColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  _getEventIcon(event.type),
                  color: courseColor.withValues(alpha: 0.8),
                  size: 22,
                ),
              ],
            ),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    event.location,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _buildChip(
                  context,
                  _formatTime(context, event.startTime),
                  Icons.access_time_rounded,
                  courseColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  isDark ? Colors.white : Colors.black87,
                ),
                const SizedBox(width: 8),
                _buildChip(
                  context,
                  _getEventTypeName(event.type, l10n),
                  Icons.label_outline_rounded,
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime time) {
    final themeProvider = context.read<ThemeProvider>();
    if (themeProvider.use24HourFormat) {
      return DateFormat.Hm().format(time);
    }
    return DateFormat.jm().format(time);
  }

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    AppLocalizations l10n,
    String eventTitle,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_event')),
        content: Text(
          l10n
              .translate('delete_event_confirm')
              .replaceAll('{title}', eventTitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(List<ScheduleEvent> allEvents) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday % 7),
    );

    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = startOfWeek.add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final isToday = DateUtils.isSameDay(date, DateTime.now());
          final dayOfWeek = date.weekday % 7;
          final dayEvents = allEvents.where((e) {
            if (e.recurring) return e.daysOfWeek.contains(dayOfWeek);
            return DateUtils.isSameDay(e.startTime, date);
          }).toList();
          final hasExam = dayEvents.any((e) => e.type == EventType.exam);

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDate = date);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isToday
                          ? theme.colorScheme.primary.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            )
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isToday
                            ? theme.colorScheme.primary.withValues(alpha: 0.4)
                            : (isDark ? Colors.white10 : Colors.black12)),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getWeekdayName(date),
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (dayEvents.isNotEmpty)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : (hasExam
                                  ? const Color(0xFFEF4444)
                                  : theme.colorScheme.primary),
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 5),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fgColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 11,
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
