import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
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
                                    formatTime: _formatTime,
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
}

Color _eventColor(ScheduleEvent event, Course? course, ThemeData theme) =>
    event.domain == EventDomain.academic
    ? (course?.color ?? theme.colorScheme.primary)
    : (event.color ?? event.domain.defaultColor);

/// One event in the grid. Tall blocks also show the start time and location;
/// pressing and holding shows a preview until released.
class _EventBlock extends StatefulWidget {
  final ScheduleEvent event;
  final Course? course;
  final double height;
  final bool compact;
  final String Function(DateTime) formatTime;
  final VoidCallback onTap;

  const _EventBlock({
    required this.event,
    required this.course,
    required this.height,
    required this.compact,
    required this.formatTime,
    required this.onTap,
  });

  @override
  State<_EventBlock> createState() => _EventBlockState();
}

class _EventBlockState extends State<_EventBlock> {
  OverlayEntry? _peek;

  void _showPeek() {
    final overlay = Overlay.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.hasSize) return;
    HapticFeedback.mediumImpact();
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
        formatTime: widget.formatTime,
      ),
    );
    overlay.insert(_peek!);
  }

  void _hidePeek() {
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

    return GestureDetector(
      onLongPressStart: (_) => _showPeek(),
      onLongPressEnd: (_) => _hidePeek(),
      onLongPressCancel: _hidePeek,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
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
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
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
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: compact ? 5.5 : 7,
                      end: compact ? 2 : 6,
                      top: compact ? 3 : 4,
                      bottom: compact ? 3 : 4,
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
                              TextSpan(
                                text: event.title.isNotEmpty
                                    ? event.title
                                    : (course?.name ?? ''),
                              ),
                            ],
                          ),
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
                                ? widget.formatTime(event.startTime)
                                : '${widget.formatTime(event.startTime)} - ${widget.formatTime(event.endTime)}',
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
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 2),
                              ],
                              Expanded(
                                child: Text(
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
    );
  }
}

/// The press-and-hold preview: a card beside the held event with its full
/// details. It ignores touches, so releasing the finger always dismisses it.
class _EventPeek extends StatelessWidget {
  final Rect anchor;
  final ScheduleEvent event;
  final Course? course;
  final String Function(DateTime) formatTime;

  const _EventPeek({
    required this.anchor,
    required this.event,
    required this.course,
    required this.formatTime,
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
            child: Text(
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
                    Text(
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
            Icons.access_time_rounded,
            '${formatTime(event.startTime)} - ${formatTime(event.endTime)}',
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
