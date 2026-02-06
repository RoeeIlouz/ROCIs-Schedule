import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

enum ScheduleViewMode { daily, weekly, biweekly, monthly }

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  ScheduleViewMode _viewMode = ScheduleViewMode.daily;

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
          PopupMenuButton<ScheduleViewMode>(
            icon: const Icon(Icons.view_agenda),
            tooltip: 'View Mode',
            onSelected: (mode) => setState(() => _viewMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ScheduleViewMode.daily,
                child: Row(
                  children: [
                    Icon(
                      Icons.view_day,
                      color: _viewMode == ScheduleViewMode.daily
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.translate('view_daily')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ScheduleViewMode.weekly,
                child: Row(
                  children: [
                    Icon(
                      Icons.view_week,
                      color: _viewMode == ScheduleViewMode.weekly
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.translate('view_weekly')),
                  ],
                ),
              ),
              /*PopupMenuItem(
                value: ScheduleViewMode.biweekly,
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      color: _viewMode == ScheduleViewMode.biweekly
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.translate('view_biweekly')),
                  ],
                ),
              ),*/
              PopupMenuItem(
                value: ScheduleViewMode.monthly,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      color: _viewMode == ScheduleViewMode.monthly
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.translate('view_monthly')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildViewModeHeader(),
          Expanded(child: _buildScheduleView()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/events/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildViewModeHeader() {
    switch (_viewMode) {
      case ScheduleViewMode.daily:
        return _buildWeekStrip();
      case ScheduleViewMode.weekly:
      case ScheduleViewMode.biweekly:
        return _buildWeekNavigator();
      case ScheduleViewMode.monthly:
        return _buildMonthNavigator();
    }
  }

  Widget _buildScheduleView() {
    switch (_viewMode) {
      case ScheduleViewMode.daily:
        return _buildDailyView();
      case ScheduleViewMode.weekly:
        return _buildWeeklyView(1);
      case ScheduleViewMode.biweekly:
        return _buildWeeklyView(2);
      case ScheduleViewMode.monthly:
        return _buildMonthlyView();
    }
  }

  Widget _buildWeekNavigator() {
    final startOfWeek = _getStartOfWeek(_selectedDate);
    final endOfWeek = _viewMode == ScheduleViewMode.biweekly
        ? startOfWeek.add(const Duration(days: 13))
        : startOfWeek.add(const Duration(days: 6));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(
                  Duration(
                    days: _viewMode == ScheduleViewMode.biweekly ? 14 : 7,
                  ),
                );
              });
            },
          ),
          Text(
            '${DateFormat.MMMd().format(startOfWeek)} - ${DateFormat.MMMd().format(endOfWeek)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(
                  Duration(
                    days: _viewMode == ScheduleViewMode.biweekly ? 14 : 7,
                  ),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month - 1,
                  1,
                );
              });
            },
          ),
          Text(
            DateFormat.yMMMM().format(_selectedDate),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(
                  _selectedDate.year,
                  _selectedDate.month + 1,
                  1,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyView() {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<CourseProvider>(
      builder: (context, provider, child) {
        final dayEvents = _getEventsForDate(provider, _selectedDate);

        if (dayEvents.isEmpty) {
          return Center(child: Text(l10n.translate('no_events')));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: dayEvents.length,
          itemBuilder: (context, index) {
            final event = dayEvents[index];
            final course = _getCourseForEvent(provider, event);
            return _buildEventCard(event, course, provider);
          },
        );
      },
    );
  }

  Widget _buildWeeklyView(int weeks) {
    final l10n = AppLocalizations.of(context)!;
    final startOfWeek = _getStartOfWeek(_selectedDate);
    final days = List.generate(
      7 * weeks,
      (i) => startOfWeek.add(Duration(days: i)),
    );

    return Consumer<CourseProvider>(
      builder: (context, provider, child) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: days.length,
          itemBuilder: (context, index) {
            final date = days[index];
            final dayEvents = _getEventsForDate(provider, date);
            final isToday = DateUtils.isSameDay(date, DateTime.now());

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _getWeekdayName(date),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.MMMd().format(date),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      if (dayEvents.isNotEmpty) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${dayEvents.length}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dayEvents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      l10n.translate('no_events'),
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  ...dayEvents.map((event) {
                    final course = _getCourseForEvent(provider, event);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _buildCompactEventCard(event, course, provider),
                    );
                  }),
                if (index < days.length - 1)
                  const Divider(height: 1, indent: 12, endIndent: 12),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMonthlyView() {
    final l10n = AppLocalizations.of(context)!;
    final firstDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
    );
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;
    final totalCells = ((firstWeekday + daysInMonth) / 7).ceil() * 7;

    return Consumer<CourseProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Day headers
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _buildDayHeader(l10n.translate('sun')),
                  _buildDayHeader(l10n.translate('mon')),
                  _buildDayHeader(l10n.translate('tue')),
                  _buildDayHeader(l10n.translate('wed')),
                  _buildDayHeader(l10n.translate('thu')),
                  _buildDayHeader(l10n.translate('fri')),
                  _buildDayHeader(l10n.translate('sat')),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Calendar grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.8,
                ),
                itemCount: totalCells,
                itemBuilder: (context, index) {
                  final dayOffset = index - firstWeekday;
                  if (dayOffset < 0 || dayOffset >= daysInMonth) {
                    return const SizedBox();
                  }

                  final date = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    dayOffset + 1,
                  );
                  final dayEvents = _getEventsForDate(provider, date);
                  final isToday = DateUtils.isSameDay(date, DateTime.now());
                  final isSelected = DateUtils.isSameDay(date, _selectedDate);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = date;
                        _viewMode = ScheduleViewMode.daily;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.3)
                            : isToday
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1,
                              )
                            : null,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '${dayOffset + 1}',
                            style: TextStyle(
                              fontWeight: isToday || isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 2,
                              runSpacing: 2,
                              children: dayEvents.take(3).map((event) {
                                final course = _getCourseForEvent(
                                  provider,
                                  event,
                                );
                                return Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: course.color,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          if (dayEvents.length > 3)
                            Text(
                              '+${dayEvents.length - 3}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDayHeader(String day) {
    return Expanded(
      child: Center(
        child: Text(
          day,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  DateTime _getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  List<ScheduleEvent> _getEventsForDate(
    CourseProvider provider,
    DateTime date,
  ) {
    return provider.events.where((e) {
      if (e.recurring) {
        return e.daysOfWeek.contains(date.weekday % 7);
      }
      return DateUtils.isSameDay(e.startTime, date);
    }).toList()..sort(
      (a, b) =>
          a.startTime.hour * 60 +
          a.startTime.minute -
          (b.startTime.hour * 60 + b.startTime.minute),
    );
  }

  Course _getCourseForEvent(CourseProvider provider, ScheduleEvent event) {
    return provider.courses.firstWhere(
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
  }

  Widget _buildEventCard(
    ScheduleEvent event,
    Course course,
    CourseProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context, l10n, event.title);
      },
      onDismissed: (direction) {
        provider.deleteEvent(event.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('event_deleted'))),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(24),
          border: Border(left: BorderSide(color: course.color, width: 6)),
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
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                      size: 20,
                    ),
                    onPressed: () async {
                      final confirmed = await _showDeleteConfirmation(
                        context,
                        l10n,
                        event.title,
                      );
                      if (confirmed == true) {
                        provider.deleteEvent(event.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.translate('event_deleted')),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  Icon(
                    _getEventIcon(event.type),
                    color: course.color.withValues(alpha: 0.7),
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
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChip(
                    context,
                    _formatTime(context, event.startTime),
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
      ),
    );
  }

  Widget _buildCompactEventCard(
    ScheduleEvent event,
    Course course,
    CourseProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: course.color, width: 4)),
      ),
      child: Row(
        children: [
          Text(
            _formatTime(context, event.startTime),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              event.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            _getEventIcon(event.type),
            color: course.color.withValues(alpha: 0.7),
            size: 16,
          ),
        ],
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
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
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
