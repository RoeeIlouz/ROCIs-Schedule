import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class AssignmentListScreen extends StatelessWidget {
  const AssignmentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final assignmentProvider = context.watch<AssignmentProvider?>();
    final courseProvider = context.watch<CourseProvider>();

    if (assignmentProvider == null) {
      return Scaffold(body: Center(child: Text(l10n.translate('loading'))));
    }

    final assignments = assignmentProvider.assignments;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('assignments'))),
      body: assignments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.translate('no_assignments')),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                final assignment = assignments[index];
                // Gracefully handle missing courses (can happen during sync or if course was deleted)
                final course = courseProvider.courses
                    .where((c) => c.id == assignment.courseId)
                    .firstOrNull;

                // Skip assignments with missing courses
                if (course == null) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Checkbox(
                        value: assignment.isCompleted,
                        onChanged: (v) {
                          assignmentProvider.toggleAssignmentCompletion(
                            assignment.id,
                          );
                        },
                      ),
                      title: Text(
                        assignment.title,
                        style: TextStyle(
                          decoration: assignment.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('unknown_course'),
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            '${l10n.translate('due_date')}: ${DateFormat.yMMMd().format(assignment.dueDate)}',
                          ),
                        ],
                      ),
                      trailing: _buildPriorityChip(
                        context,
                        assignment.priority,
                      ),
                      onLongPress: () {
                        _showDeleteDialog(
                          context,
                          assignmentProvider,
                          assignment.id,
                        );
                      },
                    ),
                  );
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Checkbox(
                      value: assignment.isCompleted,
                      onChanged: (v) {
                        assignmentProvider.toggleAssignmentCompletion(
                          assignment.id,
                        );
                      },
                    ),
                    title: Text(
                      assignment.title,
                      style: TextStyle(
                        decoration: assignment.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: TextStyle(color: course.color),
                        ),
                        Text(
                          '${l10n.translate('due_date')}: ${DateFormat.yMMMd().format(assignment.dueDate)}',
                        ),
                      ],
                    ),
                    trailing: _buildPriorityChip(context, assignment.priority),
                    onLongPress: () {
                      _showDeleteDialog(
                        context,
                        assignmentProvider,
                        assignment.id,
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/assignments/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPriorityChip(BuildContext context, AssignmentPriority priority) {
    final l10n = AppLocalizations.of(context)!;
    Color color;
    String label;

    switch (priority) {
      case AssignmentPriority.high:
        color = Colors.red;
        label = l10n.translate('high');
        break;
      case AssignmentPriority.medium:
        color = Colors.orange;
        label = l10n.translate('medium');
        break;
      case AssignmentPriority.low:
        color = Colors.green;
        label = l10n.translate('low');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    AssignmentProvider provider,
    String id,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('delete_assignment')),
        content: Text(l10n.translate('confirm_delete')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              provider.deleteAssignment(id);
              Navigator.pop(context);
            },
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
