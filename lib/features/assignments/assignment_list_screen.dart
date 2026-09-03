import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:rocis_schedule/shared/services/cross_app_bridge_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class AssignmentListScreen extends StatefulWidget {
  const AssignmentListScreen({super.key});

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreenState();
}

class _AssignmentListScreenState extends State<AssignmentListScreen> {
  String _filter = 'all'; // 'all', 'pending', 'completed'
  String _sortBy = 'dueDate'; // 'dueDate', 'priority'

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final assignmentProvider = context.watch<AssignmentProvider?>();
    final courseProvider = context.watch<CourseProvider?>();

    if (assignmentProvider == null || courseProvider == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    var assignments = assignmentProvider.assignments.toList();

    // Apply Filter
    if (_filter == 'pending') {
      assignments = assignments.where((a) => !a.isCompleted).toList();
    } else if (_filter == 'completed') {
      assignments = assignments.where((a) => a.isCompleted).toList();
    }

    // Apply Sort
    if (_sortBy == 'dueDate') {
      assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    } else if (_sortBy == 'priority') {
      assignments.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('assignments'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                ? Center(
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
                          style: TextStyle(
                            color: theme.disabledColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: assignments.length,
                    itemBuilder: (context, index) {
                      final assignment = assignments[index];
                      final course = courseProvider.courses
                          .where((c) => c.id == assignment.courseId)
                          .firstOrNull;
                      final courseColor =
                          course?.color ?? theme.colorScheme.primary;

                      return Dismissible(
                        key: Key(assignment.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
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
                          return await _showDeleteConfirmDialog(context, l10n);
                        },
                        onDismissed: (direction) {
                          assignmentProvider.deleteAssignment(assignment.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.translate('delete'))),
                          );
                        },
                        child: GlassContainer(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          tintColor: courseColor,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Transform.scale(
                                scale: 1.1,
                                child: Checkbox(
                                  value: assignment.isCompleted,
                                  activeColor: courseColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  onChanged: (v) {
                                    HapticFeedback.lightImpact();
                                    assignmentProvider
                                        .toggleAssignmentCompletion(
                                          assignment.id,
                                        );
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      assignment.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        decoration: assignment.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: assignment.isCompleted
                                            ? theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.5)
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (course != null) ...[
                                          Text(
                                            course.name,
                                            style: TextStyle(
                                              color: courseColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '•',
                                            style: TextStyle(
                                              color: theme.disabledColor,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Icon(
                                          Icons.event_outlined,
                                          size: 13,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          DateFormat.MMMd().format(
                                            assignment.dueDate,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
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
                                      await CrossAppBridgeService.sendAssignmentToTasks(
                                        assignment: assignment,
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
                              _buildPriorityBadge(context, assignment.priority),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/assignments/add'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildFilterTab({required String label, required String value}) {
    final theme = Theme.of(context);
    final isSelected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _filter = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
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
    );
  }

  Widget _buildPriorityBadge(
    BuildContext context,
    AssignmentPriority priority,
  ) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String label;

    switch (priority) {
      case AssignmentPriority.high:
        color = const Color(0xFFFF5252);
        label = l10n.translate('high');
        break;
      case AssignmentPriority.medium:
        color = const Color(0xFFFFAB40);
        label = l10n.translate('medium');
        break;
      case AssignmentPriority.low:
        color = const Color(0xFF69F0AE);
        label = l10n.translate('low');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
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
