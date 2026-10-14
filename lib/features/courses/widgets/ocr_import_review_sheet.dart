import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/courses/services/ocr_timetable_parser.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

class OcrImportReviewSheet extends StatefulWidget {
  final OcrTimetableResult result;

  const OcrImportReviewSheet({
    super.key,
    required this.result,
  });

  static Future<bool?> show(
    BuildContext context, {
    required OcrTimetableResult result,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OcrImportReviewSheet(result: result),
    );
  }

  @override
  State<OcrImportReviewSheet> createState() => _OcrImportReviewSheetState();
}

class _OcrImportReviewSheetState extends State<OcrImportReviewSheet> {
  late List<ScannedCourseDraft> _drafts;
  late String _selectedSemester;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _drafts = List.from(widget.result.drafts);
    _selectedSemester = 'semester_1';
  }

  int get _selectedCount => _drafts.where((d) => d.isSelected).length;

  String _formatDayOfWeek(int dow, BuildContext context) {
    final isHebrew = Localizations.localeOf(context).languageCode == 'he';
    switch (dow) {
      case 0:
        return isHebrew ? 'ראשון' : 'Sun';
      case 1:
        return isHebrew ? 'שני' : 'Mon';
      case 2:
        return isHebrew ? 'שלישי' : 'Tue';
      case 3:
        return isHebrew ? 'רביעי' : 'Wed';
      case 4:
        return isHebrew ? 'חמישי' : 'Thu';
      case 5:
        return isHebrew ? 'שישי' : 'Fri';
      case 6:
        return isHebrew ? 'שבת' : 'Sat';
      default:
        return '';
    }
  }

  String _formatTimeRange(DateTime start, DateTime end, BuildContext context) {
    final timeFormat = DateFormat.jm(Localizations.localeOf(context).toString());
    return '${timeFormat.format(start)} – ${timeFormat.format(end)}';
  }

  Future<void> _handleImport() async {
    if (_isImporting || _selectedCount == 0) return;

    setState(() => _isImporting = true);
    HapticFeedback.mediumImpact();

    try {
      final provider = context.read<CourseProvider>();
      final selectedDrafts = _drafts.where((d) => d.isSelected).toList();

      for (final draft in selectedDrafts) {
        final courseToSave = draft.course.copyWith(semester: _selectedSemester);
        await provider.addCourse(courseToSave);
        for (final event in draft.events) {
          await provider.addEvent(event);
        }
      }

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.translate('ics_imported')
                  .replaceAll('{courses}', '$selectedDrafts.length')
                  .replaceAll(
                    '{events}',
                    '${selectedDrafts.fold(0, (acc, d) => acc + d.events.length)}',
                  ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = theme.colorScheme.primary;

    final provider = context.watch<CourseProvider>();
    final availableSemesters = provider.semesters.isNotEmpty
        ? provider.semesters
        : CourseProvider.defaultSemesters;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        tintColor: primary,
        opacity: 0.22,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Sheet Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.document_scanner_rounded,
                        color: primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('scan_timetable_title'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_drafts.length} courses, ${widget.result.totalEvents} sessions detected',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Target Semester Selector
                Text(
                  l10n.translate('target_semester'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: availableSemesters.map((s) {
                      final isSelected = _selectedSemester == s.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(s.name),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedSemester = s.id);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Scanned Courses List
                Text(
                  l10n.translate('detected_courses'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),

                if (_drafts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        l10n.translate('no_courses_found_ocr'),
                        style: TextStyle(color: theme.disabledColor),
                      ),
                    ),
                  )
                else
                  ..._drafts.map((draft) {
                    final course = draft.course;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassContainer(
                        tintColor: course.color,
                        padding: const EdgeInsets.all(14),
                        borderRadius: BorderRadius.circular(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: draft.isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      draft.isSelected = val ?? false;
                                    });
                                  },
                                ),
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: course.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    course.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                if (course.code.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: course.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      course.code,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: course.color,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (draft.events.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 48, top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: draft.events.map((event) {
                                    final dowStr = event.daysOfWeek.isNotEmpty
                                        ? _formatDayOfWeek(event.daysOfWeek.first, context)
                                        : '';
                                    final timeStr = _formatTimeRange(
                                      event.startTime,
                                      event.endTime,
                                      context,
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          Icon(
                                            event.type.icon,
                                            size: 14,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '$dowStr  $timeStr',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          if (event.location.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '•  ${event.location}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.colorScheme.outline,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                // Import Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isImporting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(l10n.translate('cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: _isImporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_done_rounded),
                        label: Text(
                          '${l10n.translate('import')} ($_selectedCount)',
                        ),
                        onPressed: (_isImporting || _selectedCount == 0)
                            ? null
                            : _handleImport,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
