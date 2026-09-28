import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/courses/widgets/semester_dates_sheet.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:rocis_schedule/shared/widgets/command_palette_dialog.dart';
import 'package:rocis_schedule/shared/widgets/ics_import_dialog.dart';
import 'package:rocis_schedule/features/courses/screens/course_qr_scanner_screen.dart';
import 'package:rocis_schedule/features/courses/widgets/share_course_qr_sheet.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  String _selectedSemesterFilter = 'all';

  String _getSemesterDisplayName(String? id, AppLocalizations l10n) {
    if (id == null) return l10n.translate('first_semester');
    switch (id) {
      case 'semester_1':
        return l10n.translate('first_semester');
      case 'semester_2':
        return l10n.translate('second_semester');
      case 'semester_summer':
        return l10n.translate('summer_semester');
      default:
        return id;
    }
  }

  Future<void> _handleDeleteCourse(
    BuildContext context,
    Course course,
    AppLocalizations l10n,
  ) async {
    final confirmed = await _showDeleteConfirmation(context, l10n, course.name);
    if (confirmed == true && context.mounted) {
      await context.read<CourseProvider>().deleteCourse(course.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('course_deleted'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Match the navigation shell, which decides by window width.
        final isDesktop = MediaQuery.sizeOf(context).width >= 850;
        final contentBottomPadding = isDesktop ? 24.0 : 110.0;
        final fabBottomPadding = isDesktop ? 16.0 : 84.0;

        return Consumer<CourseProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (provider.courses.isEmpty) {
              return Scaffold(
                body: Center(
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
                        label: Text(l10n.translate('add_course')),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => CourseQrScannerScreen.open(context),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(l10n.translate('scan_course_qr')),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => showIcsImportDialog(context),
                        icon: const Icon(Icons.file_download_outlined),
                        label: Text(l10n.translate('import_ics')),
                      ),
                    ],
                  ),
                ),
              );
            }

            final filteredCourses = provider.getFilteredCourses(
              _selectedSemesterFilter,
            );

            if (isDesktop) {
              return Scaffold(
                body: Column(
                  children: [
                    _buildDesktopCoursesHeader(context, provider, l10n, theme),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        children: [
                          _buildGpaSummaryCard(provider, l10n, theme),
                          const SizedBox(height: 16),
                          if (filteredCourses.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(48),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.filter_list_off_rounded,
                                    size: 48,
                                    color: theme.disabledColor,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.translate('no_courses_semester'),
                                    style: TextStyle(
                                      color: theme.disabledColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        context.push('/courses/add'),
                                    icon: const Icon(Icons.add_rounded),
                                    label: Text(l10n.translate('add_course')),
                                  ),
                                ],
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, gridConstraints) {
                                final crossAxisCount =
                                    gridConstraints.maxWidth >= 1200 ? 3 : 2;
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 14,
                                        mainAxisSpacing: 14,
                                        mainAxisExtent: 130,
                                      ),
                                  itemCount: filteredCourses.length,
                                  itemBuilder: (context, index) {
                                    final course = filteredCourses[index];
                                    final courseEvents = provider
                                        .getEventsByCourse(course.id);
                                    return _buildCourseCard(
                                      context,
                                      course,
                                      courseEvents,
                                      l10n,
                                      theme,
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // Mobile Layout
            Widget mobileContent = ListView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: contentBottomPadding,
              ),
              children: [
                _buildSemesterFilterStrip(context, provider, l10n, theme),
                const SizedBox(height: 12),
                _buildGpaSummaryCard(provider, l10n, theme),
                const SizedBox(height: 16),
                if (filteredCourses.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          Icons.filter_list_off_rounded,
                          size: 48,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.translate('no_courses_semester'),
                          style: TextStyle(
                            color: theme.disabledColor,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/courses/add'),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l10n.translate('add_course')),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredCourses.map((course) {
                    final courseEvents = provider.getEventsByCourse(course.id);
                    return _buildCourseCard(
                      context,
                      course,
                      courseEvents,
                      l10n,
                      theme,
                    );
                  }),
              ],
            );

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  l10n.translate('my_courses'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    tooltip: l10n.translate('scan_course_qr'),
                    onPressed: () => CourseQrScannerScreen.open(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    tooltip: l10n.translate('search'),
                    onPressed: () => CommandPaletteDialog.show(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined),
                    tooltip: l10n.translate('import_ics'),
                    onPressed: () => showIcsImportDialog(context),
                  ),
                ],
              ),
              body: mobileContent,
              floatingActionButton: Padding(
                padding: EdgeInsets.only(bottom: fabBottomPadding),
                child: FloatingActionButton(
                  onPressed: () => context.push('/courses/add'),
                  child: const Icon(Icons.add_rounded),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDesktopCoursesHeader(
    BuildContext context,
    CourseProvider provider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final totalCourses = provider.courses.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1015) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            l10n.translate('my_courses'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$totalCourses',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: _buildSemesterFilterStrip(context, provider, l10n, theme),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: Text(l10n.translate('scan_course_qr')),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => CourseQrScannerScreen.open(context),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: Text(l10n.translate('import_ics')),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => showIcsImportDialog(context),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.translate('add_course')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => context.push('/courses/add'),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterFilterStrip(
    BuildContext context,
    CourseProvider provider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final semesters = provider.semesters.isNotEmpty
        ? provider.semesters
        : CourseProvider.defaultSemesters;

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text(l10n.translate('all_semesters')),
                  selected: _selectedSemesterFilter == 'all',
                  onSelected: (selected) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSemesterFilter = 'all');
                  },
                ),
                const SizedBox(width: 8),
                ...semesters.map((sem) {
                  final isSelected = _selectedSemesterFilter == sem.id;
                  final label = _getSemesterDisplayName(sem.id, l10n);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedSemesterFilter = selected ? sem.id : 'all';
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: l10n.translate('semester_dates'),
          icon: const Icon(Icons.calendar_month_rounded, size: 20),
          visualDensity: VisualDensity.compact,
          onPressed: () => SemesterDatesSheet.show(context),
        ),
      ],
    );
  }

  Widget _buildGpaSummaryCard(
    CourseProvider provider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final gpa = provider.getFilteredGpa(_selectedSemesterFilter);
    final avgGrade = provider.getFilteredAverageGrade(_selectedSemesterFilter);
    final totalCredits = provider.getFilteredCredits(_selectedSemesterFilter);
    final creditsText = totalCredits % 1 == 0
        ? totalCredits.toInt().toString()
        : totalCredits.toStringAsFixed(1);

    final titleSuffix = _selectedSemesterFilter != 'all'
        ? ' (${_getSemesterDisplayName(_selectedSemesterFilter, l10n)})'
        : '';

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
              Expanded(
                child: Text(
                  '${l10n.translate('academic_overview')}$titleSuffix',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                  accentColor: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricPill(
                  title: l10n.translate('average_grade'),
                  value: avgGrade != null
                      ? '${avgGrade.toStringAsFixed(1)}%'
                      : '--',
                  accentColor: Theme.of(context).colorScheme.secondary,
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
    final semesterName = _getSemesterDisplayName(course.semester, l10n);

    return Dismissible(
      key: Key(course.id),
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
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? course.color.withValues(alpha: 0.25)
                : course.color.withValues(alpha: 0.18),
            width: 1.0,
          ),
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: () =>
                _showCourseDetails(context, course, courseEvents, l10n),
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
                          ? course.code
                                .substring(
                                  0,
                                  course.code.length > 3
                                      ? 3
                                      : course.code.length,
                                )
                                .toUpperCase()
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            course.code,
                            style: TextStyle(
                              fontSize: 13,
                              color: course.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: course.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              semesterName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: course.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (course.instructor.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          course.instructor,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (course.grade != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${course.grade!.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, size: 20),
                          onSelected: (value) async {
                            if (value == 'share_qr') {
                              final events = context
                                  .read<CourseProvider>()
                                  .events
                                  .where((e) => e.courseId == course.id)
                                  .toList();
                              ShareCourseQrSheet.show(
                                context,
                                course: course,
                                events: events,
                              );
                            } else if (value == 'edit') {
                              context.push('/courses/edit', extra: course);
                            } else if (value == 'delete') {
                              await _handleDeleteCourse(context, course, l10n);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'share_qr',
                              child: Row(
                                children: [
                                  const Icon(Icons.qr_code_2_rounded, size: 18),
                                  const SizedBox(width: 10),
                                  Text(l10n.translate('share_course_qr')),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit_rounded, size: 18),
                                  const SizedBox(width: 10),
                                  Text(l10n.translate('edit_course')),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n.translate('delete_course'),
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
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
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
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
    final semesterName = _getSemesterDisplayName(course.semester, l10n);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
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
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    tooltip: l10n.translate('edit_course'),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.push('/courses/edit', extra: course);
                    },
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: Colors.red,
                    ),
                    tooltip: l10n.translate('delete_course'),
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _handleDeleteCourse(context, course, l10n);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${course.code}   ${course.credits} ${l10n.translate('credits_label')}',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: course.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: course.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      semesterName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: course.color,
                      ),
                    ),
                  ),
                ],
              ),
              if (course.instructor.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.translate('instructor')}: ${course.instructor}',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.translate('grade'),
                        hintText: '92',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final parsed = double.tryParse(
                        gradeController.text.trim(),
                      );
                      context.read<CourseProvider>().updateCourseGrade(
                        course.id,
                        parsed,
                      );
                      Navigator.of(sheetContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: course.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.translate('set_grade')),
                  ),
                ],
              ),
              const Divider(height: 32),
              Text(
                l10n.translate('events'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getEventIcon(event.type),
                          color: course.color,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatEventTime(context, event),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
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
          l10n
              .translate('delete_course_confirm')
              .replaceAll('{name}', courseName),
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
      final days = event.daysOfWeek
          .map((day) => weekdayNames[((day % 7) + 7) % 7])
          .join(', ');
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
