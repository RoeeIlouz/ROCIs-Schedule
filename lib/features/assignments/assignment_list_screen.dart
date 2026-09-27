import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:rocis_schedule/shared/widgets/bouncy_checkbox.dart';
import 'package:rocis_schedule/shared/widgets/command_palette_dialog.dart';
import 'package:rocis_schedule/shared/services/cross_app_bridge_service.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class AssignmentListScreen extends StatefulWidget {
  const AssignmentListScreen({super.key});

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  String _filter =
      'all'; // 'all', 'pending', 'completed', 'this_week', 'overdue'
  String _sortBy = 'dueDate'; // 'dueDate', 'priority'

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final assignmentProvider = context.watch<AssignmentProvider>();
    final courseProvider = context.watch<CourseProvider>();

    if (assignmentProvider.isLoading || courseProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allAssignments = assignmentProvider.assignments;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final in7Days = today.add(const Duration(days: 7));

    final totalPending = allAssignments.where((a) => !a.isCompleted).length;
    final totalCompleted = allAssignments.where((a) => a.isCompleted).length;
    final dueThisWeek = allAssignments.where((a) {
      if (a.isCompleted) return false;
      final d = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day);
      return !d.isBefore(today) && !d.isAfter(in7Days);
    }).length;
    final overdueCount = allAssignments.where((a) {
      if (a.isCompleted) return false;
      final d = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day);
      return d.isBefore(today);
    }).length;

    var assignments = allAssignments.toList();

    // Apply Filter
    if (_filter == 'pending') {
      assignments = assignments.where((a) => !a.isCompleted).toList();
    } else if (_filter == 'completed') {
      assignments = assignments.where((a) => a.isCompleted).toList();
    } else if (_filter == 'this_week') {
      assignments = assignments.where((a) {
        if (a.isCompleted) return false;
        final d = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day);
        return !d.isBefore(today) && !d.isAfter(in7Days);
      }).toList();
    } else if (_filter == 'overdue') {
      assignments = assignments.where((a) {
        if (a.isCompleted) return false;
        final d = DateTime(a.dueDate.year, a.dueDate.month, a.dueDate.day);
        return d.isBefore(today);
      }).toList();
    }

    // Apply Sort
    if (_sortBy == 'dueDate') {
      assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    } else if (_sortBy == 'priority') {
      assignments.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Match the navigation shell, which decides by window width.
        final isDesktop = MediaQuery.sizeOf(context).width >= 850;

        if (isDesktop) {
          return Scaffold(
            body: Column(
              children: [
                _buildDesktopAssignmentsHeader(
                  context: context,
                  totalPending: totalPending,
                  l10n: l10n,
                  theme: theme,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    children: [
                      _buildKpiSummaryRow(
                        totalPending: totalPending,
                        dueThisWeek: dueThisWeek,
                        overdueCount: overdueCount,
                        totalCompleted: totalCompleted,
                        l10n: l10n,
                        theme: theme,
                      ),
                      const SizedBox(height: 20),
                      if (assignments.isEmpty)
                        _buildEmptyState(theme, l10n)
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
                                    mainAxisExtent: 88,
                                  ),
                              itemCount: assignments.length,
                              itemBuilder: (context, index) {
                                final assignment = assignments[index];
                                final course = courseProvider.courses
                                    .where((c) => c.id == assignment.courseId)
                                    .firstOrNull;
                                return _buildAssignmentItem(
                                  context: context,
                                  assignment: assignment,
                                  course: course,
                                  assignmentProvider: assignmentProvider,
                                  themeProvider: themeProvider,
                                  l10n: l10n,
                                  theme: theme,
                                  isDesktop: true,
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
        final contentBottomPadding = 110.0;
        final fabBottomPadding = 84.0;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.translate('assignments'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: l10n.translate('search'),
                onPressed: () => CommandPaletteDialog.show(context),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: l10n.translate('sort_by'),
                onSelected: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _sortBy = val);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'dueDate',
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 18,
                          color: _sortBy == 'dueDate'
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.translate('sort_due_date')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'priority',
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 18,
                          color: _sortBy == 'priority'
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.translate('sort_priority')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    _buildFilterTab(
                      label: l10n.translate('filter_all'),
                      value: 'all',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterTab(
                      label: l10n.translate('filter_pending'),
                      value: 'pending',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterTab(
                      label: l10n.translate('filter_completed'),
                      value: 'completed',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: assignments.isEmpty
                    ? _buildEmptyState(theme, l10n)
                    : ListView.builder(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: contentBottomPadding,
                        ),
                        itemCount: assignments.length,
                        itemBuilder: (context, index) {
                          final assignment = assignments[index];
                          final course = courseProvider.courses
                              .where((c) => c.id == assignment.courseId)
                              .firstOrNull;

                          return Dismissible(
                            key: Key(assignment.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: AlignmentDirectional.centerEnd,
                              padding: const EdgeInsetsDirectional.only(
                                end: 20,
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await _showDeleteConfirmDialog(
                                context,
                                l10n,
                              );
                            },
                            onDismissed: (direction) {
                              assignmentProvider.deleteAssignment(
                                assignment.id,
                              );
                              _showDeletedSnackBar(
                                context,
                                l10n,
                                assignmentProvider,
                                assignment,
                              );
                            },
                            child: _buildAssignmentItem(
                              context: context,
                              assignment: assignment,
                              course: course,
                              assignmentProvider: assignmentProvider,
                              themeProvider: themeProvider,
                              l10n: l10n,
                              theme: theme,
                              isDesktop: false,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: Padding(
            padding: EdgeInsets.only(bottom: fabBottomPadding),
            child: FloatingActionButton(
              onPressed: () => context.push('/assignments/add'),
              child: const Icon(Icons.add_rounded),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopAssignmentsHeader({
    required BuildContext context,
    required int totalPending,
    required AppLocalizations l10n,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            l10n.translate('assignments'),
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
              '$totalPending',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 320,
            child: Row(
              children: [
                _buildFilterTab(
                  label: l10n.translate('filter_all'),
                  value: 'all',
                ),
                const SizedBox(width: 8),
                _buildFilterTab(
                  label: l10n.translate('filter_pending'),
                  value: 'pending',
                ),
                const SizedBox(width: 8),
                _buildFilterTab(
                  label: l10n.translate('filter_completed'),
                  value: 'completed',
                ),
              ],
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            tooltip: l10n.translate('sort_by'),
            onSelected: (val) {
              HapticFeedback.selectionClick();
              setState(() => _sortBy = val);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sortBy == 'dueDate'
                        ? Icons.event_outlined
                        : Icons.flag_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _sortBy == 'dueDate'
                        ? l10n.translate('sort_due_date')
                        : l10n.translate('sort_priority'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'dueDate',
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: _sortBy == 'dueDate'
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.translate('sort_due_date')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'priority',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 18,
                      color: _sortBy == 'priority'
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(l10n.translate('sort_priority')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          IconButton.outlined(
            icon: const Icon(Icons.search_rounded, size: 18),
            tooltip: l10n.translate('search'),
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => CommandPaletteDialog.show(context),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.translate('add_assignment')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => context.push('/assignments/add'),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiSummaryRow({
    required int totalPending,
    required int dueThisWeek,
    required int overdueCount,
    required int totalCompleted,
    required AppLocalizations l10n,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        _buildKpiCard(
          label: l10n.translate('filter_pending'),
          count: '$totalPending',
          icon: Icons.pending_actions_rounded,
          color: theme.colorScheme.primary,
          isSelected: _filter == 'pending',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _filter = _filter == 'pending' ? 'all' : 'pending');
          },
          theme: theme,
        ),
        const SizedBox(width: 14),
        _buildKpiCard(
          label: l10n.translate('due_this_week'),
          count: '$dueThisWeek',
          icon: Icons.calendar_today_rounded,
          color: const Color(0xFFF59E0B),
          isSelected: _filter == 'this_week',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(
              () => _filter = _filter == 'this_week' ? 'all' : 'this_week',
            );
          },
          theme: theme,
        ),
        const SizedBox(width: 14),
        _buildKpiCard(
          label: l10n.translate('overdue'),
          count: '$overdueCount',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFEF4444),
          isSelected: _filter == 'overdue',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _filter = _filter == 'overdue' ? 'all' : 'overdue');
          },
          theme: theme,
        ),
        const SizedBox(width: 14),
        _buildKpiCard(
          label: l10n.translate('filter_completed'),
          count: '$totalCompleted',
          icon: Icons.task_alt_rounded,
          color: const Color(0xFF10B981),
          isSelected: _filter == 'completed',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(
              () => _filter = _filter == 'completed' ? 'all' : 'completed',
            );
          },
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: isDark ? 0.2 : 0.12)
                  : (isDark ? const Color(0xFF18181B) : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? color
                    : (isDark
                          ? const Color(0xFF27272A)
                          : const Color(0xFFE4E4E7)),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        count,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentItem({
    required BuildContext context,
    required Assignment assignment,
    required Course? course,
    required AssignmentProvider assignmentProvider,
    required ThemeProvider themeProvider,
    required AppLocalizations l10n,
    required ThemeData theme,
    required bool isDesktop,
  }) {
    final courseColor = course?.color ?? theme.colorScheme.primary;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateOnly = DateTime(
      assignment.dueDate.year,
      assignment.dueDate.month,
      assignment.dueDate.day,
    );
    final isOverdue = !assignment.isCompleted && dueDateOnly.isBefore(today);

    return GlassContainer(
      margin: EdgeInsets.symmetric(vertical: isDesktop ? 0 : 6),
      padding: EdgeInsets.zero,
      tintColor: courseColor,
      border: Border.all(
        color: theme.brightness == Brightness.dark
            ? courseColor.withValues(alpha: 0.25)
            : courseColor.withValues(alpha: 0.18),
        width: 1.0,
      ),
      child: InkWell(
        onTap: () => context.push('/assignments/edit', extra: assignment),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3.5,
                height: 38,
                decoration: BoxDecoration(
                  color: courseColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              BouncyCheckbox(
                isChecked: assignment.isCompleted,
                activeColor: courseColor,
                onTap: () {
                  assignmentProvider.toggleAssignmentCompletion(assignment.id);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      assignment.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: assignment.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: assignment.isCompleted
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (course != null) ...[
                          Flexible(
                            child: Text(
                              course.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: courseColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(color: theme.disabledColor),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.event_outlined,
                          size: 13,
                          color: isOverdue
                              ? Colors.red
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.MMMd().format(assignment.dueDate),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isOverdue
                                ? Colors.red
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (themeProvider.enableTasksIntegration)
                IconButton(
                  icon: Icon(
                    Icons.outbox_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  tooltip: l10n.translate('send_to_tasks'),
                  onPressed: () async {
                    HapticFeedback.selectionClick();
                    final launched =
                        await CrossAppBridgeService.sendAssignmentToTasks(
                          assignment: assignment,
                          course: course,
                        );
                    if (context.mounted && launched) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.translate('exported_to_tasks')),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              _buildPriorityBadge(context, assignment.priority),
              if (isDesktop) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                  tooltip: l10n.translate('delete'),
                  onPressed: () async {
                    final confirm = await _showDeleteConfirmDialog(
                      context,
                      l10n,
                    );
                    if (confirm == true) {
                      assignmentProvider.deleteAssignment(assignment.id);
                      if (context.mounted) {
                        _showDeletedSnackBar(
                          context,
                          l10n,
                          assignmentProvider,
                          assignment,
                        );
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 64,
              color: theme.disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.translate('no_assignments'),
              style: TextStyle(color: theme.disabledColor, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab({required String label, required String value}) {
    final theme = Theme.of(context);
    final isSelected = _filter == value;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _filter = value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(
    BuildContext context,
    AssignmentPriority priority,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    String label;

    switch (priority) {
      case AssignmentPriority.high:
        color = const Color(0xFFEF4444);
        label = l10n.translate('high');
        break;
      case AssignmentPriority.medium:
        color = const Color(0xFFF59E0B);
        label = l10n.translate('medium');
        break;
      case AssignmentPriority.low:
        color = const Color(0xFF10B981);
        label = l10n.translate('low');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showDeletedSnackBar(
    BuildContext context,
    AppLocalizations l10n,
    AssignmentProvider provider,
    Assignment assignment,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.translate('assignment_deleted')),
        action: SnackBarAction(
          label: l10n.translate('undo'),
          onPressed: () => provider.addAssignment(assignment),
        ),
      ),
    );
  }

  Future<bool?> _showDeleteConfirmDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_assignment')),
        content: Text(l10n.translate('confirm_delete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.translate('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
