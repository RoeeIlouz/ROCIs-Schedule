import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class CourseListScreen extends StatelessWidget {
  const CourseListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('my_courses'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l10n.translate('import_ics'),
            onPressed: () => _showIcsImportDialog(context, l10n),
          ),
        ],
      ),
      body: Consumer<CourseProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: theme.disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.translate('no_courses'),
                    style: TextStyle(
                      color: theme.disabledColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/courses/add'),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.translate('add_first_course')),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showIcsImportDialog(context, l10n),
                    icon: const Icon(Icons.file_download_outlined),
                    label: Text(l10n.translate('import_ics')),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _buildGpaSummaryCard(provider, l10n, theme),
              const SizedBox(height: 16),
              ...provider.courses.map((course) {
                final courseEvents = provider.getEventsByCourse(course.id);
                return _buildCourseCard(context, course, courseEvents, l10n, theme);
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/courses/add'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildGpaSummaryCard(
    CourseProvider provider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final gpa = provider.calculatedGpa;
    final avgGrade = provider.averageGrade;
    final totalCredits = provider.totalCredits;
    final creditsText = totalCredits % 1 == 0 ? totalCredits.toInt().toString() : totalCredits.toStringAsFixed(1);

    return GlassContainer(
      tintColor: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.translate('academic_overview'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricPill(
                  title: l10n.translate('total_credits'),
                  value: creditsText,
                  accentColor: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricPill(
                  title: l10n.translate('gpa'),
                  value: gpa != null ? gpa.toStringAsFixed(2) : '--',
                  accentColor: Colors.tealAccent.shade700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricPill(
                  title: l10n.translate('average_grade'),
                  value: avgGrade != null ? '${avgGrade.toStringAsFixed(1)}%' : '--',
                  accentColor: Colors.orangeAccent.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required String title,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(
    BuildContext context,
    Course course,
    List<ScheduleEvent> courseEvents,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Dismissible(
      key: Key(course.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(context, l10n, course.name);
      },
      onDismissed: (direction) {
        context.read<CourseProvider>().deleteCourse(course.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('course_deleted'))),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: GlassContainer(
          tintColor: course.color,
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: () => _showCourseDetails(context, course, courseEvents, l10n),
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: course.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: course.color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      course.code.isNotEmpty
                          ? course.code.substring(0, course.code.length > 3 ? 3 : course.code.length).toUpperCase()
                          : course.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: course.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        course.code,
                        style: TextStyle(
                          fontSize: 13,
                          color: course.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (course.instructor.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          course.instructor,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (course.grade != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${course.grade!.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.tealAccent,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${course.credits % 1 == 0 ? course.credits.toInt() : course.credits} ${l10n.translate('credits_label')}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${courseEvents.length} ${l10n.translate('events')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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

  void _showCourseDetails(
    BuildContext context,
    Course course,
    List<ScheduleEvent> events,
    AppLocalizations l10n,
  ) {
    final gradeController = TextEditingController(
      text: course.grade != null ? course.grade.toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          tintColor: course.color,
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: course.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      course.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${course.code}   ${course.credits} ${l10n.translate('credits_label')}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              if (course.instructor.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.translate('instructor')}: ${course.instructor}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Grade Setter
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: gradeController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.translate('grade'),
                        hintText: 'e.g. 92',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final parsed = double.tryParse(gradeController.text.trim());
                      context.read<CourseProvider>().updateCourseGrade(course.id, parsed);
                      Navigator.of(sheetContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: course.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.translate('set_grade')),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(
                l10n.translate('events'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (events.isEmpty)
                Text(
                  l10n.translate('no_events_course'),
                  style: TextStyle(color: Theme.of(context).disabledColor),
                )
              else
                ...events.map(
                  (event) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(_getEventIcon(event.type), color: course.color, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(
                                _formatEventTime(context, event),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIcsImportDialog(BuildContext context, AppLocalizations l10n) {
    final icsController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.translate('import_ics')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('import_ics_desc'),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: icsController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'BEGIN:VCALENDAR\nBEGIN:VEVENT\n...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = icsController.text.trim();
              if (text.isNotEmpty) {
                final result = IcsImportService.parseIcsContent(text);
                await context.read<CourseProvider>().importIcsTimetable(result);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Imported ${result.courses.length} courses and ${result.events.length} events!',
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(l10n.translate('import')),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(
    BuildContext context,
    AppLocalizations l10n,
    String courseName,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_course')),
        content: Text(
          l10n.translate('delete_course_confirm').replaceAll('{name}', courseName),
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

  String _formatEventTime(BuildContext context, ScheduleEvent event) {
    final themeProvider = context.read<ThemeProvider>();
    final use24Hour = themeProvider.use24HourFormat;

    String start;
    String end;

    if (use24Hour) {
      start = DateFormat.Hm().format(event.startTime);
      end = DateFormat.Hm().format(event.endTime);
    } else {
      start = DateFormat.jm().format(event.startTime);
      end = DateFormat.jm().format(event.endTime);
    }

    if (event.recurring && event.daysOfWeek.isNotEmpty) {
      final l10n = AppLocalizations.of(context)!;
      final weekdayNames = l10n.locale.languageCode == 'he'
          ? ['א\'', 'ב\'', 'ג\'', 'ד\'', 'ה\'', 'ו\'', 'ש\'']
          : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final days = event.daysOfWeek.map((day) => weekdayNames[((day % 7) + 7) % 7]).join(', ');
      return '$days   $start - $end';
    }
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatShortDate(event.startTime);
    return '$date   $start - $end';
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
