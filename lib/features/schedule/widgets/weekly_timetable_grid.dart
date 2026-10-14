import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/utils/bidi.dart';
import 'package:rocis_schedule/shared/utils/event_time_format.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

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

/// Rows for the all-day band: each day-spanning event gets the first row
/// that is free across all the week columns ([first]..[last], 0-6) it covers.
@visibleForTesting
List<({ScheduleEvent event, int first, int last, int row})> layoutSpanRows(
  List<ScheduleEvent> events,
  List<DateTime> weekDays,
) {
  final spans = <({ScheduleEvent event, int first, int last})>[];
  for (final event in events) {
    final first = weekDays.indexWhere(event.coversDay);
    if (first < 0) continue;
    final last = weekDays.lastIndexWhere(event.coversDay);
    spans.add((event: event, first: first, last: last));
  }
  // Earlier and longer bars first, so they settle in the top rows.
  spans.sort((a, b) {
    final byFirst = a.first.compareTo(b.first);
    return byFirst != 0
        ? byFirst
        : (b.last - b.first).compareTo(a.last - a.first);
  });
  final rowEnds = <int>[];
  return [
    for (final span in spans)
      () {
        var row = rowEnds.indexWhere((end) => end < span.first);
        if (row < 0) {
          row = rowEnds.length;
          rowEnds.add(span.last);
        } else {
          rowEnds[row] = span.last;
        }
        return (
          event: span.event,
          first: span.first,
          last: span.last,
          row: row,
        );
      }(),
  ];
}

class WeeklyTimetableGrid extends StatefulWidget {
  final List<ScheduleEvent> events;
  final Map<String, Course> courses;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final void Function(ScheduleEvent event, Course? course) onEventTap;
  final void Function(DateTime date, int hour)? onEmptySlotTap;
  final CourseProvider courseProvider;
  final bool use24HourFormat;

  /// Phone layout: a narrower time axis, shorter hours and event blocks that
  /// wrap the title instead of showing time and location.
  final bool compact;

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
    this.compact = false,
  });

  @override
  State<WeeklyTimetableGrid> createState() => _WeeklyTimetableGridState();
}

class _WeeklyTimetableGridState extends State<WeeklyTimetableGrid> {
  // The grid shows at least 08:00-20:00 and grows to fit earlier or later
  // events that week.
  static const int _defaultStartHour = 8;
  static const int _defaultEndHour = 20;
  double get _hourHeight => widget.compact ? 56.0 : 64.0;
  double get _timeColWidth => widget.compact ? 34.0 : 58.0;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final weekDays = _getWeekDays(widget.selectedDate);
    final now = DateTime.now();

    // Holidays and other day-spanning events go in a band above the hours.
    final spanRows = layoutSpanRows(
      widget.events.where((e) => e.spansDays).toList(),
      weekDays,
    );
    final weekEvents = {
      for (final day in weekDays)
        day: widget.events
            .where((e) => !e.spansDays && _isEventOnDay(e, day))
            .toList(),
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
    final compact = widget.compact;
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
            height: compact ? 56 : 60,
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
                      size: compact ? 15 : 18,
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
                        padding: EdgeInsets.symmetric(
                          vertical: compact ? 4 : 6,
                        ),
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
                              DateFormat(
                                compact ? 'EEEEE' : 'E',
                              ).format(day).toUpperCase(),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: compact ? 10 : 11,
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
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 5 : 7,
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
                                  fontSize: compact ? 12 : 13,
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

          if (spanRows.isNotEmpty)
            _buildAllDayBand(spanRows, gridLineColor, headerBgColor),

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
                              padding: EdgeInsetsDirectional.only(
                                end: compact ? 4 : 8,
                                top: 4,
                              ),
                              child: Text(
                                widget.use24HourFormat
                                    ? (compact
                                          ? hour.toString().padLeft(2, '0')
                                          : '${hour.toString().padLeft(2, '0')}:00')
                                    : DateFormat.j().format(
                                        DateTime(2026, 1, 1, hour),
                                      ),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  fontSize: compact ? 9.5 : 11,
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
                                final startMinutes = _minuteOf(event.startTime);
                                final endMinutes = _minuteOf(event.endTime);
                                final topOffset =
                                    ((startMinutes - startHour * 60) / 60.0) *
                                    _hourHeight;
                                final durationMinutes =
                                    (endMinutes - startMinutes).clamp(
                                      30,
                                      24 * 60,
                                    );
                                final blockHeight =
                                    ((durationMinutes / 60.0) * _hourHeight -
                                            3.0)
                                        .clamp(28.0, 24 * _hourHeight);

                                final layout =
                                    lanes[event.id] ?? (lane: 0, lanes: 1);
                                final laneWidth =
                                    (columnConstraints.maxWidth - 4) /
                                    layout.lanes;

                                return PositionedDirectional(
                                  top: topOffset.clamp(0.0, double.infinity),
                                  start: 2 + layout.lane * laneWidth,
                                  width: laneWidth - (layout.lanes > 1 ? 2 : 0),
                                  height: blockHeight,
                                  child: _EventBlock(
                                    event: event,
                                    course: course,
                                    height: blockHeight,
                                    compact: compact,
                                    use24HourFormat: widget.use24HourFormat,
                                    hasConflict: layout.lanes > 1,
                                    onTap: () =>
                                        widget.onEventTap(event, course),
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

  /// Bars for all-day and multi-day events, each spanning the days it covers
  /// this week. Scrolls when there are more than a few rows.
  Widget _buildAllDayBand(
    List<({ScheduleEvent event, int first, int last, int row})> spanRows,
    Color gridLineColor,
    Color backgroundColor,
  ) {
    final theme = Theme.of(context);
    final compact = widget.compact;
    final rowHeight = compact ? 20.0 : 24.0;
    const rowGap = 2.0;
    final rows = spanRows.map((s) => s.row).reduce(math.max) + 1;
    final contentHeight = rows * (rowHeight + rowGap) + 4;

    return Container(
      constraints: BoxConstraints(maxHeight: 3.5 * (rowHeight + rowGap) + 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: gridLineColor)),
      ),
      child: SingleChildScrollView(
        child: SizedBox(
          height: contentHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _timeColWidth,
                child: Tooltip(
                  message: AppLocalizations.of(context)!.translate('all_day'),
                  child: Icon(
                    Icons.wb_sunny_rounded,
                    size: compact ? 13 : 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              VerticalDivider(width: 1, thickness: 1, color: gridLineColor),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dayWidth = constraints.maxWidth / 7;
                    return Stack(
                      children: [
                        for (final span in spanRows)
                          PositionedDirectional(
                            top: 2 + span.row * (rowHeight + rowGap),
                            start: span.first * dayWidth + 2,
                            width: (span.last - span.first + 1) * dayWidth - 4,
                            height: rowHeight,
                            child: _EventBlock(
                              event: span.event,
                              course: widget.courses[span.event.courseId],
                              height: rowHeight,
                              compact: compact,
                              use24HourFormat: widget.use24HourFormat,
                              onTap: () => widget.onEventTap(
                                span.event,
                                widget.courses[span.event.courseId],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _eventColor(ScheduleEvent event, Course? course, ThemeData theme) =>
    event.colorFor(course) ?? theme.colorScheme.primary;

/// One event in the grid. Tall blocks also show the start time and location;
/// pressing and holding shows a preview until released, and so does resting
/// the mouse on it (web and desktop).
class _EventBlock extends StatefulWidget {
  final ScheduleEvent event;
  final Course? course;
  final double height;
  final bool compact;
  final bool use24HourFormat;
  final bool hasConflict;
  final VoidCallback onTap;

  const _EventBlock({
    required this.event,
    required this.course,
    required this.height,
    required this.compact,
    required this.use24HourFormat,
    this.hasConflict = false,
    required this.onTap,
  });

  @override
  State<_EventBlock> createState() => _EventBlockState();
}

class _EventBlockState extends State<_EventBlock> {
  OverlayEntry? _peek;
  Timer? _hoverTimer;

  /// Hovering waits a moment so sweeping the mouse across the grid doesn't
  /// flash previews.
  static const _hoverDelay = Duration(milliseconds: 450);

  String _formatTime(DateTime t) =>
      formatClockTime(t, use24HourFormat: widget.use24HourFormat);

  void _showPeek({bool fromHover = false}) {
    final overlay = Overlay.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.hasSize) return;
    if (!fromHover) HapticFeedback.mediumImpact();
    final anchor =
        box.localToGlobal(
          Offset.zero,
          ancestor: overlay.context.findRenderObject(),
        ) &
        box.size;
    _hidePeek();
    _peek = OverlayEntry(
      builder: (_) => _EventPeek(
        anchor: anchor,
        event: widget.event,
        course: widget.course,
        use24HourFormat: widget.use24HourFormat,
        dimBackground: !fromHover,
        hasConflict: widget.hasConflict,
      ),
    );
    overlay.insert(_peek!);
  }

  void _hidePeek() {
    _hoverTimer?.cancel();
    _hoverTimer = null;
    _peek
      ?..remove()
      ..dispose();
    _peek = null;
  }

  @override
  void dispose() {
    _hidePeek();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final event = widget.event;
    final course = widget.course;
    final compact = widget.compact;
    final height = widget.height;
    final color = _eventColor(event, course, theme);

    final showTime = height >= (compact ? 70 : 42);
    final showLocation =
        event.location.isNotEmpty && height >= (compact ? 95 : 56);
    final titleLines = compact
        ? ((height - 6 - (showTime ? 12 : 0) - (showLocation ? 12 : 0)) ~/ 11.4)
              .clamp(1, 6)
        : 1;
    final secondaryColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    // All-day bars are a single line, shorter than any timed block.
    final verticalPadding = height < 28 ? 2.0 : (compact ? 3.0 : 4.0);
    final title = event.title.isNotEmpty ? event.title : (course?.name ?? '');
    final layoutDirection = Directionality.of(context);
    final layoutStart = layoutDirection == TextDirection.rtl
        ? TextAlign.right
        : TextAlign.left;

    return MouseRegion(
      onEnter: (_) {
        _hoverTimer?.cancel();
        _hoverTimer = Timer(_hoverDelay, () {
          if (mounted) _showPeek(fromHover: true);
        });
      },
      onExit: (_) => _hidePeek(),
      child: GestureDetector(
        onLongPressStart: (_) => _showPeek(),
        onLongPressEnd: (_) => _hidePeek(),
        onLongPressCancel: _hidePeek,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              _hidePeek();
              widget.onTap();
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    color.withValues(alpha: isDark ? 0.28 : 0.16),
                    isDark ? const Color(0xFF18181B) : Colors.white,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
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
                      child: Container(color: color),
                    ),
                    if (widget.hasConflict)
                      PositionedDirectional(
                        top: 2,
                        end: 2,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.priority_high_rounded,
                            size: compact ? 7.5 : 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: compact ? 5.5 : 7,
                        end: compact ? 2 : 6,
                        top: verticalPadding,
                        bottom: verticalPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      end: compact ? 2 : 3,
                                    ),
                                    child: Icon(
                                      event.iconFor(course),
                                      size: compact ? 9.5 : 11,
                                      color: color,
                                    ),
                                  ),
                                ),
                                TextSpan(text: title),
                              ],
                            ),
                            // The title reads in its own direction (Hebrew
                            // with English words, or the reverse) but stays
                            // aligned with the grid.
                            textDirection:
                                textDirectionOf(title) ?? layoutDirection,
                            textAlign: layoutStart,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 9.5 : 11,
                              height: compact ? 1.2 : null,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            maxLines: titleLines,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showTime) ...[
                            SizedBox(height: compact ? 1 : 2),
                            Text(
                              compact
                                  ? _formatTime(event.startTime)
                                  : '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
                              style: TextStyle(
                                fontSize: compact ? 8.5 : 10,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ],
                          if (showLocation) ...[
                            SizedBox(height: compact ? 1 : 2),
                            Row(
                              children: [
                                if (!compact) ...[
                                  Icon(
                                    Icons.place_outlined,
                                    size: 10,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                Expanded(
                                  child: BidiText(
                                    event.location,
                                    style: TextStyle(
                                      fontSize: compact ? 8.5 : 9.5,
                                      color: secondaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

/// The press-and-hold (or hover) preview: a card beside the event with its
/// full details. It ignores pointers, so releasing the finger or moving the
/// mouse away always dismisses it.
class _EventPeek extends StatelessWidget {
  final Rect anchor;
  final ScheduleEvent event;
  final Course? course;
  final bool use24HourFormat;

  /// Dims the screen behind the card; off for hover, where it would flicker.
  final bool dimBackground;
  final bool hasConflict;

  const _EventPeek({
    required this.anchor,
    required this.event,
    required this.course,
    required this.use24HourFormat,
    this.dimBackground = true,
    this.hasConflict = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final course = this.course;
    final color = _eventColor(event, course, theme);
    final secondary = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    final title = event.title.isNotEmpty ? event.title : (course?.name ?? '');
    final academic = event.domain == EventDomain.academic;
    final subtitle = academic
        ? [
            if (course != null && course.name != title) course.name,
            l10n.translate(event.type.l10nKey),
          ].join(' · ')
        : l10n.translate(
            event.domain == EventDomain.work
                ? 'domain_work'
                : 'domain_personal',
          );

    Widget detail(IconData icon, String text, {int maxLines = 2}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: secondary),
          const SizedBox(width: 8),
          Expanded(
            child: BidiText(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );

    final card = GlassContainer(
      tintColor: color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: 0.35)),
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(event.iconFor(course), size: 20, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BidiText(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          detail(
            event.allDay ? Icons.wb_sunny_rounded : Icons.access_time_rounded,
            formatEventTimeRange(event, l10n, use24HourFormat: use24HourFormat),
          ),
          if (event.location.isNotEmpty)
            detail(
              event.domain == EventDomain.work
                  ? Icons.business_rounded
                  : Icons.place_outlined,
              event.location,
            ),
          if (academic && course != null && course.instructor.isNotEmpty)
            detail(Icons.person_outline_rounded, course.instructor),
          if (event.notes.isNotEmpty)
            detail(Icons.notes_rounded, event.notes, maxLines: 4),
          if (hasConflict) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.translate('schedule_conflicts_detected'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const gutter = 16.0;
        const gap = 8.0;
        final size = constraints.biggest;
        final padding = MediaQuery.paddingOf(context);
        final width = math.min(320.0, size.width - 2 * gutter);
        final left = (anchor.center.dx - width / 2)
            .clamp(gutter, math.max(gutter, size.width - gutter - width))
            .toDouble();
        // Open on the side of the event with more room.
        final spaceAbove = anchor.top - padding.top - gap;
        final spaceBelow = size.height - padding.bottom - anchor.bottom - gap;
        final above = spaceAbove > spaceBelow;

        return IgnorePointer(
          child: Stack(
            children: [
              if (dimBackground)
                Positioned.fill(
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
                ),
              Positioned(
                left: left,
                width: width,
                top: above ? null : anchor.bottom + gap,
                bottom: above ? size.height - anchor.top + gap : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(0.0, above ? spaceAbove : spaceBelow),
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.92, end: 1),
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: ((t - 0.92) / 0.08).clamp(0.0, 1.0),
                      child: Transform.scale(scale: t, child: child),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: card,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
