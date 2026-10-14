import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/utils/bidi.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

void showExamCountdownSheet(
  BuildContext context,
  ScheduleEvent exam,
  Course? course,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => ExamCountdownSheet(exam: exam, course: course),
  );
}

class ExamCountdownSheet extends StatefulWidget {
  final ScheduleEvent exam;
  final Course? course;

  const ExamCountdownSheet({
    super.key,
    required this.exam,
    this.course,
  });

  @override
  State<ExamCountdownSheet> createState() => _ExamCountdownSheetState();
}

class _ExamCountdownSheetState extends State<ExamCountdownSheet> {
  late Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final course = widget.course;
    final exam = widget.exam;
    final errorColor = theme.colorScheme.error;
    final courseColor = exam.colorFor(course) ?? errorColor;

    final diff = exam.startTime.difference(_now);
    final isPast = diff.isNegative;
    final totalSeconds = math.max(0, diff.inSeconds);
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    // Credit-based study recommendation:
    // Approximately 8-10 hours per credit point (default 9h).
    final credits = (course?.credits != null && course!.credits > 0)
        ? course.credits
        : 3.0;
    final totalPrepHours = (credits * 9).round();
    final daysRemaining = math.max(1, diff.inDays);
    final dailyStudyHours = isPast
        ? '0.0'
        : (totalPrepHours / daysRemaining).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13131A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: courseColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.assignment_late_rounded,
                  color: courseColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('exam_countdown'),
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (course != null)
                      Text(
                        '${course.code.isNotEmpty ? '${course.code} • ' : ''}${course.name}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: courseColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Exam Title & Schedule Details Card
          GlassContainer(
            borderRadius: BorderRadius.circular(16),
            tintColor: courseColor,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BidiText(
                  exam.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${DateFormat.yMMMEd().format(exam.startTime)}  •  ${DateFormat.Hm().format(exam.startTime)} - ${DateFormat.Hm().format(exam.endTime)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (exam.location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        exam.location,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Countdown Digit Tiles
          if (isPast)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                l10n.translate('in_progress'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: courseColor,
                ),
              ),
            )
          else
            Row(
              children: [
                _buildCountdownBox(
                  context,
                  days.toString().padLeft(2, '0'),
                  'DAYS',
                  courseColor,
                ),
                const SizedBox(width: 8),
                _buildCountdownBox(
                  context,
                  hours.toString().padLeft(2, '0'),
                  'HOURS',
                  courseColor,
                ),
                const SizedBox(width: 8),
                _buildCountdownBox(
                  context,
                  minutes.toString().padLeft(2, '0'),
                  'MINS',
                  courseColor,
                ),
                const SizedBox(width: 8),
                _buildCountdownBox(
                  context,
                  seconds.toString().padLeft(2, '0'),
                  'SECS',
                  courseColor,
                ),
              ],
            ),
          const SizedBox(height: 18),

          // Recommended Study Plan Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E28)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('study_prep_recommended'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n
                            .translate('hours_recommended')
                            .replaceAll('{hours}', totalPrepHours.toString()),
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        '${l10n.translate('recommended_daily_study')}: ${l10n.translate('hours_per_day').replaceAll('{hours}', dailyStudyHours)} (${credits.toStringAsFixed(1)} credits)',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Button: Schedule Study Session
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              final prepTitle =
                  '${l10n.translate('study')}: ${course?.name ?? exam.title}';
              context.push(
                '/schedule/add',
                extra: {
                  'initialTitle': prepTitle,
                  'initialCourseId': exam.courseId,
                  'initialType': EventType.study,
                  'initialStart': DateTime.now().add(const Duration(hours: 1)),
                },
              );
            },
            icon: const Icon(Icons.alarm_add_rounded, size: 20),
            label: Text(
              l10n.translate('schedule_study_session'),
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: courseColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownBox(
    BuildContext context,
    String value,
    String label,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E28)
              : theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
