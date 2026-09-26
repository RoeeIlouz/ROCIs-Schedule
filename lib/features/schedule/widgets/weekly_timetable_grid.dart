import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';

/// Side-by-side lanes for overlapping events: each event gets a lane index
/// and the lane count of the cluster of events it overlaps with.
@visibleForTesting
Map<String, ({int lane, int lanes})> layoutEventLanes(
  List<ScheduleEvent> events,
) {
  final sorted = [...events]
    ..sort(
      (a, b) => _minuteOfDay(a.startTime).compareTo(_minuteOfDay(b.startTime)),
    );
  final result = <String, ({int lane, int lanes})>{};
  var cluster = <ScheduleEvent, int>{};
  var laneEnds = <int>[];
  var clusterEnd = -1;

  void closeCluster() {
    for (final entry in cluster.entries) {
      result[entry.key.id] = (lane: entry.value, lanes: laneEnds.length);
    }
    cluster = {};
    laneEnds = [];
  }

  for (final event in sorted) {
    final start = _minuteOfDay(event.startTime);
    final end = _minuteOfDay(event.endTime);
    if (start >= clusterEnd) closeCluster();
    var lane = laneEnds.indexWhere((laneEnd) => laneEnd <= start);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(end);
    } else {
      laneEnds[lane] = end;
    }
    cluster[event] = lane;
    if (end > clusterEnd) clusterEnd = end;
  }
  closeCluster();
  return result;
}

int _minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

class WeeklyTimetableGrid extends StatefulWidget {
  final List<ScheduleEvent> events;
  final Map<String, Course> courses;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final void Function(ScheduleEvent event, Course? course) onEventTap;
  final void Function(DateTime date, int hour)? onEmptySlotTap;
  final CourseProvider courseProvider;
  final bool use24HourFormat;

  const WeeklyTimetableGrid({
    super.key,
    required this.events,
    required this.courses,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onEventTap,
    this.onEmptySlotTap,
    required this.courseProvider,
    this.use24HourFormat = true,
  });

  @override
  State<WeeklyTimetableGrid> createState() => _WeeklyTimetableGridState();
}

class _WeeklyTimetableGridState extends State<WeeklyTimetableGrid> {
  // The grid shows at least 08:00-20:00 and grows to fit earlier or later
  // events that week.
  static const int _defaultStartHour = 8;
  static const int _defaultEndHour = 20;
  static const double _hourHeight = 64.0;
  static const double _timeColWidth = 58.0;

  late ScrollController _verticalScrollController;

  @override
  void initState() {
    super.initState();
    // Auto-scroll to near 08:00 - 09:00
    final initialOffset =
        ((DateTime.now().hour - _defaultStartHour).clamp(0, 5)) *
        _hourHeight *
        0.5;
    _verticalScrollController = ScrollController(
      initialScrollOffset: initialOffset,
    );
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// Calculates the 7 days (Sunday - Saturday) for the current week containing selectedDate
  List<DateTime> _getWeekDays(DateTime reference) {
    // Determine Sunday as the first day of the academic week
    final int differenceFromSunday = reference.weekday % 7;
    final sunday = reference.subtract(Duration(days: differenceFromSunday));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  bool _isEventOnDay(ScheduleEvent event, DateTime date) =>
      widget.courseProvider.occursOn(event, date, widget.courses);

  static int _minuteOf(DateTime t) => t.hour * 60 + t.minute;

  String _formatTime(DateTime t) => widget.use24HourFormat
      ? DateFormat.Hm().format(t)
      : DateFormat.jm().format(t);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final weekDays = _getWeekDays(widget.selectedDate);
    final now = DateTime.now();

    final weekEvents = {
      for (final day in weekDays)
        day: widget.events.where((e) => _isEventOnDay(e, day)).toList(),
    };
    var startHour = _defaultStartHour;
    var endHour = _defaultEndHour;
    for (final event in weekEvents.values.expand((e) => e)) {
      if (event.startTime.hour < startHour) startHour = event.startTime.hour;
      final endMinute = _minuteOf(event.endTime);
      final lastHour = (endMinute / 60).ceil();
      if (lastHour > endHour) endHour = lastHour.clamp(0, 24);
    }

    final Color gridLineColor = isDark
        ? const Color(0xFF27272A)
        : const Color(0xFFE4E4E7);
    final Color headerBgColor = isDark
        ? const Color(0xFF13141B)
        : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1015) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gridLineColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. Days of Week Header
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: headerBgColor,
              border: Border(bottom: BorderSide(color: gridLineColor)),
            ),
            child: Row(
              children: [
                // Empty corner box aligned with time axis
                SizedBox(
                  width: _timeColWidth,
                  child: Center(
                    child: Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: gridLineColor),
                // 7 Day Headers
                ...weekDays.map((day) {
                  final isToday = DateUtils.isSameDay(day, now);
                  final isSelected = DateUtils.isSameDay(
                    day,
                    widget.selectedDate,
                  );

                  return Expanded(
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onDateSelected(day);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.08,
                                )
                              : Colors.transparent,
                          border: isSelected
                              ? Border(
                                  bottom: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 2.5,
                                  ),
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('E').format(day).toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: isToday
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.6,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isToday || isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isToday
                                      ? theme.colorScheme.onPrimary
                                      : (isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // 2. Scrollable Time Grid Area
          Expanded(
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              child: SizedBox(
                height: (endHour - startHour) * _hourHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Time labels column
                    SizedBox(
                      width: _timeColWidth,
                      child: Column(
                        children: List.generate(endHour - startHour, (index) {
                          final hour = startHour + index;
                          return SizedBox(
                            height: _hourHeight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8, top: 4),
                              child: Text(
                                widget.use24HourFormat
                                    ? '${hour.toString().padLeft(2, '0')}:00'
                                    : DateFormat.j().format(
                                        DateTime(2026, 1, 1, hour),
                                      ),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: gridLineColor,
                    ),

                    // Day columns
                    ...weekDays.map((day) {
                      final dayEvents = weekEvents[day]!;
                      final lanes = layoutEventLanes(dayEvents);

                      return Expanded(
                        child: LayoutBuilder(
                          builder: (context, columnConstraints) => Stack(
                            children: [
                              // Horizontal hour gridlines & click-to-add slots
                              Column(
                                children: List.generate(endHour - startHour, (
                                  index,
                                ) {
                                  final hour = startHour + index;
                                  return InkWell(
                                    mouseCursor: SystemMouseCursors.click,
                                    onTap: widget.onEmptySlotTap != null
                                        ? () =>
                                              widget.onEmptySlotTap!(day, hour)
                                        : null,
                                    child: Container(
                                      height: _hourHeight,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: gridLineColor.withValues(
                                              alpha: isDark ? 0.6 : 0.7,
                                            ),
                                            width: 0.7,
                                          ),
                                          right: BorderSide(
                                            color: gridLineColor.withValues(
                                              alpha: isDark ? 0.6 : 0.7,
                                            ),
                                            width: 0.7,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),

                              // Event blocks overlaid on top
                              ...dayEvents.map((event) {
                                final course = widget.courses[event.courseId];
                                final effectiveColor =
                                    (event.domain == EventDomain.academic)
                                    ? (course?.color ??
                                          theme.colorScheme.primary)
                                    : (event.color ??
                                          event.domain.defaultColor);

                                final startMinutes =
                                    event.startTime.hour * 60 +
                                    event.startTime.minute;
                                final endMinutes =
                                    event.endTime.hour * 60 +
                                    event.endTime.minute;
                                final gridStartMinutes = startHour * 60;

                                final topOffset =
                                    ((startMinutes - gridStartMinutes) / 60.0) *
                                    _hourHeight;
                                final durationMinutes =
                                    (endMinutes - startMinutes).clamp(
                                      30,
                                      24 * 60,
                                    );
                                final blockHeight =
                                    (durationMinutes / 60.0) * _hourHeight -
                                    3.0;

                                final layout =
                                    lanes[event.id] ?? (lane: 0, lanes: 1);
                                final laneWidth =
                                    (columnConstraints.maxWidth - 4) /
                                    layout.lanes;

                                return PositionedDirectional(
                                  top: topOffset.clamp(0.0, double.infinity),
                                  start: 2 + layout.lane * laneWidth,
                                  width: laneWidth - (layout.lanes > 1 ? 2 : 0),
                                  height: blockHeight.clamp(
                                    28.0,
                                    24 * _hourHeight,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      mouseCursor: SystemMouseCursors.click,
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () =>
                                          widget.onEventTap(event, course),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Color.alphaBlend(
                                              effectiveColor.withValues(
                                                alpha: isDark ? 0.28 : 0.16,
                                              ),
                                              isDark
                                                  ? const Color(0xFF18181B)
                                                  : Colors.white,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: effectiveColor.withValues(
                                                alpha: 0.35,
                                              ),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: isDark ? 0.3 : 0.05,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              PositionedDirectional(
                                                start: 0,
                                                top: 0,
                                                bottom: 0,
                                                width: 3.5,
                                                child: Container(
                                                  color: effectiveColor,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsetsDirectional.only(
                                                      start: 7,
                                                      end: 6,
                                                      top: 4,
                                                      bottom: 4,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        if (event.domain !=
                                                            EventDomain
                                                                .academic) ...[
                                                          Icon(
                                                            event.domain.icon,
                                                            size: 11,
                                                            color:
                                                                effectiveColor,
                                                          ),
                                                          const SizedBox(
                                                            width: 3,
                                                          ),
                                                        ],
                                                        Expanded(
                                                          child: Text(
                                                            event
                                                                    .title
                                                                    .isNotEmpty
                                                                ? event.title
                                                                : (course?.name ??
                                                                      ''),
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 11,
                                                              color: isDark
                                                                  ? Colors.white
                                                                  : const Color(
                                                                      0xFF0F172A,
                                                                    ),
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (blockHeight >= 42) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: effectiveColor,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        maxLines: 1,
                                                      ),
                                                    ],
                                                    if (blockHeight >= 56 &&
                                                        event
                                                            .location
                                                            .isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .place_outlined,
                                                            size: 10,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 2,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              event.location,
                                                              style: TextStyle(
                                                                fontSize: 9.5,
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withValues(
                                                                      alpha:
                                                                          0.6,
                                                                    ),
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
