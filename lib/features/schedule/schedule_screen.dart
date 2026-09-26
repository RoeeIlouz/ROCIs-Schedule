import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:rocis_schedule/shared/widgets/command_palette_dialog.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:go_router/go_router.dart';
import 'package:rocis_schedule/shared/services/cross_app_bridge_service.dart';
import 'package:rocis_schedule/features/schedule/widgets/weekly_timetable_grid.dart';
import 'package:rocis_schedule/features/schedule/widgets/schedule_empty_states.dart';
import 'package:rocis_schedule/shared/widgets/account_button.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDate = DateTime.now();
  EventType? _selectedFilter;
  EventDomain? _selectedDomainFilter;
  bool _isTimetableGridView = true;
  bool _isEventOnDate(
    ScheduleEvent event,
    DateTime date,
    Map<String, Course> courses,
    CourseProvider courseProvider,
  ) => courseProvider.occursOn(event, date, courses);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final courseProvider = context.watch<CourseProvider>();

    if (courseProvider.isLoading) {
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

    // Filter events for the selected day and active domain/category filters
    final dayEvents =
        courseProvider.events.where((event) {
          if (!_isEventOnDate(event, _selectedDate, courses, courseProvider)) {
            return false;
          }
          if (_selectedDomainFilter != null &&
              event.domain != _selectedDomainFilter) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Match the navigation shell, which decides by window width; the side
        // panel only fits when this screen itself is wide enough.
        final isDesktop = MediaQuery.sizeOf(context).width >= 850;
        final showSidePanel = constraints.maxWidth >= 900;
        final contentBottomPadding = isDesktop ? 24.0 : 100.0;
        final fabBottomPadding = isDesktop ? 16.0 : 84.0;

        final isFirstRun =
            courseProvider.courses.isEmpty && courseProvider.events.isEmpty;
        final filtersActive =
            _selectedFilter != null || _selectedDomainFilter != null;

        Widget dayBody;
        if (isFirstRun) {
          dayBody = ScheduleWelcome(bottomPadding: contentBottomPadding);
        } else if (dayEvents.isEmpty) {
          final next = filtersActive
              ? null
              : _findNextEvent(courseProvider, courses);
          dayBody = FreeDayState(
            nextEvent: next?.event,
            nextDate: next?.date,
            nextCourse: courses[next?.event.courseId],
            onJumpTo: (date) => setState(() => _selectedDate = date),
            filtersActive: filtersActive,
            onClearFilters: () => setState(() {
              _selectedFilter = null;
              _selectedDomainFilter = null;
            }),
          );
        } else {
          dayBody = ListView.builder(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: contentBottomPadding,
            ),
            itemCount: dayEvents.length,
            itemBuilder: (context, index) {
              final event = dayEvents[index];
              final course = courses[event.courseId];
              return _buildEventCard(context, event, course);
            },
          );
        }

        Widget mainTimetableContent = Column(
          children: [
            if (upcomingExams.isNotEmpty && !isDesktop)
              _buildUpcomingExamsBanner(upcomingExams, courses, l10n),
            _buildWeekStrip(courseProvider.events, courses, courseProvider),
            const SizedBox(height: 6),
            if (!isFirstRun) ...[
              _buildFilterChips(l10n),
              const SizedBox(height: 8),
            ],
            Expanded(child: dayBody),
          ],
        );

        if (isDesktop) {
          final theme = Theme.of(context);
          final centerWorkspace = isFirstRun
              ? ScheduleWelcome(bottomPadding: contentBottomPadding)
              : _isTimetableGridView
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: WeeklyTimetableGrid(
                    events: courseProvider.events.where((event) {
                      if (_selectedDomainFilter != null &&
                          event.domain != _selectedDomainFilter) {
                        return false;
                      }
                      if (_selectedFilter != null &&
                          event.type != _selectedFilter) {
                        return false;
                      }
                      return true;
                    }).toList(),
                    courses: courses,
                    selectedDate: _selectedDate,
                    onDateSelected: (day) =>
                        setState(() => _selectedDate = day),
                    onEventTap: (event, course) =>
                        _showEventDetailsDialog(context, event, course, l10n),
                    onEmptySlotTap: (date, hour) => context.push(
                      '/schedule/add-event',
                      extra: DateTime(date.year, date.month, date.day, hour),
                    ),
                    courseProvider: courseProvider,
                    use24HourFormat: context
                        .watch<ThemeProvider>()
                        .use24HourFormat,
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: mainTimetableContent,
                  ),
                );

          return Scaffold(
            body: Column(
              children: [
                _buildDesktopHeader(
                  context,
                  l10n,
                  theme,
                  showFilters: !isFirstRun,
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: centerWorkspace),
                      if (showSidePanel) ...[
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        SizedBox(
                          width: 340,
                          child: _buildDesktopSidePanel(
                            context,
                            upcomingExams,
                            courses,
                            courseProvider,
                            dayEvents.length,
                            l10n,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        DateFormat('MMMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: l10n.translate('search'),
                onPressed: () => CommandPaletteDialog.show(context),
              ),
              if (!DateUtils.isSameDay(_selectedDate, DateTime.now()))
                IconButton(
                  icon: const Icon(Icons.today_rounded),
                  tooltip: l10n.translate('today'),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedDate = DateTime.now());
                  },
                ),
              const AccountButton(),
              const SizedBox(width: 4),
            ],
          ),
          body: mainTimetableContent,
          floatingActionButton: isFirstRun
              ? null
              : Padding(
                  padding: EdgeInsets.only(bottom: fabBottomPadding),
                  child: FloatingActionButton(
                    tooltip: l10n.translate('add_event'),
                    onPressed: () => context.push('/schedule/add-event'),
                    child: const Icon(Icons.add_rounded),
                  ),
                ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  /// Moves the selection a week back or forward.
  void _shiftWeek(int weeks) {
    HapticFeedback.selectionClick();
    setState(
      () => _selectedDate = _selectedDate.add(Duration(days: 7 * weeks)),
    );
  }

  /// The first event within a month after the selected day, for the free-day
  /// hint.
  ({ScheduleEvent event, DateTime date})? _findNextEvent(
    CourseProvider courseProvider,
    Map<String, Course> courses,
  ) {
    for (var offset = 1; offset <= 30; offset++) {
      final date = DateUtils.dateOnly(
        _selectedDate,
      ).add(Duration(days: offset));
      ScheduleEvent? earliest;
      for (final event in courseProvider.events) {
        if (!courseProvider.occursOn(event, date, courses)) continue;
        final minutes = event.startTime.hour * 60 + event.startTime.minute;
        if (earliest == null ||
            minutes <
                earliest.startTime.hour * 60 + earliest.startTime.minute) {
          earliest = event;
        }
      }
      if (earliest != null) return (event: earliest, date: date);
    }
    return null;
  }

  List<DateTime> _getWeekDays(DateTime reference) {
    final int differenceFromSunday = reference.weekday % 7;
    final sunday = reference.subtract(Duration(days: differenceFromSunday));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  Widget _buildDesktopHeader(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme, {
    required bool showFilters,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final weekDays = _getWeekDays(_selectedDate);
    final weekRangeText =
        '${DateFormat.MMMd().format(weekDays.first)} – ${DateFormat.yMMMd().format(weekDays.last)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1015) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, headerConstraints) {
          final toolbar = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: headerConstraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: l10n.translate('previous_week'),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _selectedDate = _selectedDate.subtract(
                              const Duration(days: 7),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: l10n.translate('next_week'),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _selectedDate = _selectedDate.add(
                              const Duration(days: 7),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        weekRangeText,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.today_rounded, size: 16),
                        label: Text(l10n.translate('today')),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedDate = DateTime.now());
                        },
                      ),
                      const SizedBox(width: 16),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: [
                          ButtonSegment<bool>(
                            value: true,
                            icon: const Icon(
                              Icons.calendar_view_week_rounded,
                              size: 16,
                            ),
                            label: Text(l10n.translate('week')),
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            icon: const Icon(
                              Icons.view_agenda_outlined,
                              size: 16,
                            ),
                            label: Text(
                              l10n.translate('academic_overview'),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ],
                        selected: {_isTimetableGridView},
                        onSelectionChanged: (newSelection) {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _isTimetableGridView = newSelection.first,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(l10n.translate('add_event')),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => context.push('/schedule/add-event'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
          if (!showFilters) return toolbar;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              toolbar,
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildDesktopFilterChips(l10n),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDesktopFilterChips(AppLocalizations l10n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterChip(
          visualDensity: VisualDensity.compact,
          label: Text(l10n.translate('filter_all')),
          selected: _selectedDomainFilter == null && _selectedFilter == null,
          onSelected: (_) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedDomainFilter = null;
              _selectedFilter = null;
            });
          },
        ),
        const SizedBox(width: 6),
        FilterChip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.school_outlined, size: 14),
          label: Text(l10n.translate('filter_academic')),
          selected: _selectedDomainFilter == EventDomain.academic,
          onSelected: (selected) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedDomainFilter = selected ? EventDomain.academic : null;
            });
          },
        ),
        const SizedBox(width: 6),
        FilterChip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.work_outline_rounded, size: 14),
          label: Text(l10n.translate('filter_work')),
          selected: _selectedDomainFilter == EventDomain.work,
          onSelected: (selected) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedDomainFilter = selected ? EventDomain.work : null;
            });
          },
        ),
        const SizedBox(width: 6),
        FilterChip(
          visualDensity: VisualDensity.compact,
          avatar: const Icon(Icons.person_outline_rounded, size: 14),
          label: Text(l10n.translate('filter_personal')),
          selected: _selectedDomainFilter == EventDomain.personal,
          onSelected: (selected) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedDomainFilter = selected ? EventDomain.personal : null;
            });
          },
        ),
        const SizedBox(width: 6),
        FilterChip(
          visualDensity: VisualDensity.compact,
          label: Text(l10n.translate('filter_classes')),
          selected: _selectedFilter == EventType.classType,
          onSelected: (selected) {
            HapticFeedback.selectionClick();
            setState(
              () => _selectedFilter = selected ? EventType.classType : null,
            );
          },
        ),
        const SizedBox(width: 6),
        FilterChip(
          visualDensity: VisualDensity.compact,
          label: Text(l10n.translate('filter_exams')),
          selected: _selectedFilter == EventType.exam,
          onSelected: (selected) {
            HapticFeedback.selectionClick();
            setState(() => _selectedFilter = selected ? EventType.exam : null);
          },
        ),
      ],
    );
  }

  void _showEventDetailsDialog(
    BuildContext context,
    ScheduleEvent event,
    Course? course,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final effectiveColor = (event.domain == EventDomain.academic)
        ? (course?.color ?? theme.colorScheme.primary)
        : (event.color ?? event.domain.defaultColor);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: effectiveColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                event.title.isNotEmpty ? event.title : (course?.name ?? ''),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.domain != EventDomain.academic) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(event.domain.icon, size: 14, color: effectiveColor),
                    const SizedBox(width: 6),
                    Text(
                      event.domain == EventDomain.work
                          ? l10n.translate('domain_work')
                          : l10n.translate('domain_personal'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: effectiveColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (course != null) ...[
              Text(
                course.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: effectiveColor,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat.Hm().format(event.startTime)} - ${DateFormat.Hm().format(event.endTime)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    event.domain == EventDomain.work
                        ? Icons.business_rounded
                        : Icons.place_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(event.location),
                ],
              ),
            ],
            if (event.domain == EventDomain.academic) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _getEventIcon(event.type),
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(_getEventTypeName(event.type, l10n)),
                ],
              ),
            ],
            if (event.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                event.notes,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            label: Text(
              l10n.translate('delete'),
              style: const TextStyle(color: Colors.red),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final confirmed = await _showDeleteConfirmation(
                context,
                l10n,
                event.title,
              );
              if (confirmed == true && context.mounted) {
                final provider = context.read<CourseProvider>()
                  ..deleteEvent(event.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.translate('event_deleted')),
                    action: SnackBarAction(
                      label: l10n.translate('undo'),
                      onPressed: () => provider.addEvent(event),
                    ),
                  ),
                );
              }
            },
          ),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(l10n.translate('edit')),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/schedule/edit-event', extra: event);
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.translate('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidePanel(
    BuildContext context,
    List<ScheduleEvent> upcomingExams,
    Map<String, Course> courses,
    CourseProvider courseProvider,
    int todayEventsCount,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Overview Card
          GlassContainer(
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.translate('academic_overview'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  DateFormat.yMMMMEEEEd().format(_selectedDate),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$todayEventsCount ${l10n.translate('events')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!DateUtils.isSameDay(_selectedDate, now))
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _selectedDate = DateTime.now());
                        },
                        icon: const Icon(Icons.restore_rounded, size: 16),
                        label: Text(
                          l10n.translate('today'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Upcoming Exams Section Header
          Row(
            children: [
              Icon(
                Icons.assignment_late_rounded,
                size: 18,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.translate('filter_exams'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (upcomingExams.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${upcomingExams.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Exams List or Empty
          if (upcomingExams.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.translate('no_events'),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...upcomingExams.map((exam) {
              final course = courses[exam.courseId];
              final diff = exam.startTime.difference(now);
              final daysLeft = diff.inDays;
              String timeText;
              if (diff.isNegative) {
                timeText = l10n.translate('in_progress');
              } else if (daysLeft == 0) {
                timeText = l10n
                    .translate('today_at')
                    .replaceAll(
                      '{time}',
                      DateFormat.Hm().format(exam.startTime),
                    );
              } else if (daysLeft == 1) {
                timeText = l10n.translate('tomorrow');
              } else {
                timeText = l10n
                    .translate('days_left')
                    .replaceAll('{days}', daysLeft.toString());
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: GlassContainer(
                  tintColor: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exam.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(
                                alpha: isDark ? 0.2 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              timeText,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (course != null)
                        Text(
                          course.name,
                          style: TextStyle(
                            color: course.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat.yMMMd().add_Hm().format(exam.startTime),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          FilterChip(
            label: Text(l10n.translate('filter_all')),
            selected: _selectedDomainFilter == null && _selectedFilter == null,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (_) {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedDomainFilter = null;
                _selectedFilter = null;
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.school_outlined, size: 14),
            label: Text(l10n.translate('filter_academic')),
            selected: _selectedDomainFilter == EventDomain.academic,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (selected) {
              HapticFeedback.selectionClick();
              setState(
                () => _selectedDomainFilter = selected
                    ? EventDomain.academic
                    : null,
              );
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.work_outline_rounded, size: 14),
            label: Text(l10n.translate('filter_work')),
            selected: _selectedDomainFilter == EventDomain.work,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (selected) {
              HapticFeedback.selectionClick();
              setState(
                () =>
                    _selectedDomainFilter = selected ? EventDomain.work : null,
              );
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.person_outline_rounded, size: 14),
            label: Text(l10n.translate('filter_personal')),
            selected: _selectedDomainFilter == EventDomain.personal,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (selected) {
              HapticFeedback.selectionClick();
              setState(
                () => _selectedDomainFilter = selected
                    ? EventDomain.personal
                    : null,
              );
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(l10n.translate('filter_classes')),
            selected: _selectedFilter == EventType.classType,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (selected) {
              HapticFeedback.selectionClick();
              setState(
                () => _selectedFilter = selected ? EventType.classType : null,
              );
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(l10n.translate('filter_exams')),
            selected: _selectedFilter == EventType.exam,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (selected) {
              HapticFeedback.selectionClick();
              setState(
                () => _selectedFilter = selected ? EventType.exam : null,
              );
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(l10n.translate('filter_labs')),
            selected: _selectedFilter == EventType.lab,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (selected) {
              HapticFeedback.selectionClick();
              setState(() => _selectedFilter = selected ? EventType.lab : null);
            },
          ),
        ],
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
          final theme = Theme.of(context);
          final errorColor = theme.colorScheme.error;
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
              tintColor: errorColor,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: errorColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.assignment_late_rounded,
                      color: errorColor,
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
                          style: TextStyle(
                            color: errorColor,
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
    final effectiveColor = (event.domain == EventDomain.academic)
        ? (course?.color ?? theme.colorScheme.primary)
        : (event.color ?? event.domain.defaultColor);

    return Dismissible(
      key: Key(event.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20.0),
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
        final provider = context.read<CourseProvider>()..deleteEvent(event.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('event_deleted')),
            action: SnackBarAction(
              label: l10n.translate('undo'),
              onPressed: () => provider.addEvent(event),
            ),
          ),
        );
      },
      child: GlassContainer(
        tintColor: effectiveColor,
        margin: const EdgeInsets.only(bottom: 12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? effectiveColor.withValues(alpha: 0.25)
              : effectiveColor.withValues(alpha: 0.18),
          width: 1.0,
        ),
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _showEventDetailsDialog(context, event, course, l10n),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3.5,
                      height: 42,
                      decoration: BoxDecoration(
                        color: effectiveColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (event.domain != EventDomain.academic) ...[
                                Icon(
                                  event.domain.icon,
                                  size: 14,
                                  color: effectiveColor,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  event.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (course != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              course.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: effectiveColor,
                              ),
                            ),
                          ] else if (event.domain != EventDomain.academic) ...[
                            const SizedBox(height: 2),
                            Text(
                              event.domain == EventDomain.work
                                  ? l10n.translate('domain_work')
                                  : l10n.translate('domain_personal'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: effectiveColor,
                              ),
                            ),
                          ],
                        ],
                      ),
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.location,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
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
                      '${_formatTime(context, event.startTime)} – ${_formatTime(context, event.endTime)}',
                      Icons.access_time_rounded,
                      effectiveColor.withValues(alpha: isDark ? 0.2 : 0.12),
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
                    if (context
                        .watch<ThemeProvider>()
                        .enableTasksIntegration) ...[
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.outbox_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        tooltip: l10n.translate('send_to_tasks'),
                        onPressed: () async {
                          HapticFeedback.selectionClick();
                          final launched =
                              await CrossAppBridgeService.sendEventToTasks(
                                event: event,
                                course: course,
                              );
                          if (context.mounted && launched) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.translate('exported_to_tasks'),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
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

  Widget _buildWeekStrip(
    List<ScheduleEvent> allEvents,
    Map<String, Course> courses,
    CourseProvider courseProvider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final startOfWeek = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday % 7),
    );

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // Seven equal columns fit any phone width; swiping changes the week.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 200) return;
        final forward = isRtl ? velocity > 0 : velocity < 0;
        _shiftWeek(forward ? 1 : -1);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: List.generate(7, (index) {
            final date = startOfWeek.add(Duration(days: index));
            final isSelected = DateUtils.isSameDay(date, _selectedDate);
            final isToday = DateUtils.isSameDay(date, DateTime.now());
            final dayEvents = allEvents
                .where((e) => _isEventOnDate(e, date, courses, courseProvider))
                .toList();
            final hasExam = dayEvents.any((e) => e.type == EventType.exam);

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedDate = date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 76,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
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
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.4,
                                  )
                                : theme.colorScheme.outlineVariant),
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
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
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
              ),
            );
          }),
        ),
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
