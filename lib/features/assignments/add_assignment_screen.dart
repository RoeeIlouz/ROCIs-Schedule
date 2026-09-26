import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/widgets/app_button.dart';
import 'package:rocis_schedule/shared/widgets/app_text_field.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class AddAssignmentScreen extends StatefulWidget {
  /// The assignment to edit; null to create a new one.
  final Assignment? assignmentToEdit;

  const AddAssignmentScreen({super.key, this.assignmentToEdit});

  @override
  State<AddAssignmentScreen> createState() => _AddAssignmentScreenState();
}

class _AddAssignmentScreenState extends State<AddAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCourseId;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  AssignmentPriority _priority = AssignmentPriority.medium;
  bool _isLoading = false;

  bool get _isEditing => widget.assignmentToEdit != null;

  @override
  void initState() {
    super.initState();
    final assignment = widget.assignmentToEdit;
    if (assignment != null) {
      _titleController.text = assignment.title;
      _descriptionController.text = assignment.description;
      _selectedCourseId = assignment.courseId;
      _selectedDate = assignment.dueDate;
      _priority = assignment.priority;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _cancelOrClose() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/assignments');
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      // Editing an old assignment must not start before the picker's range.
      firstDate: _earliest(
        _selectedDate,
        DateTime.now().subtract(const Duration(days: 30)),
      ),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  static DateTime _earliest(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  Future<void> _saveAssignment() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate() || _selectedCourseId == null) {
      if (_selectedCourseId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('select_course_error'))),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final assignment = Assignment(
        id: widget.assignmentToEdit?.id,
        isCompleted: widget.assignmentToEdit?.isCompleted ?? false,
        courseId: _selectedCourseId!,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        dueDate: _selectedDate,
        priority: _priority,
      );

      await context.read<AssignmentProvider>().addAssignment(assignment);
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/assignments');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getPriorityColor(AssignmentPriority p) {
    switch (p) {
      case AssignmentPriority.low:
        return const Color(0xFF10B981); // Emerald
      case AssignmentPriority.medium:
        return const Color(0xFFF59E0B); // Amber
      case AssignmentPriority.high:
        return const Color(0xFFEF4444); // Red
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseProvider>().courses;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 720;
    if (courses.isEmpty) return _buildNeedsCourse(l10n, theme);

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title Field
          AppTextField(
            label: l10n.translate('title'),
            hint: l10n.translate('hint_assignment_title'),
            controller: _titleController,
            validator: (v) => (v != null && v.trim().isNotEmpty)
                ? null
                : l10n.translate('field_required'),
          ),
          const SizedBox(height: 20),

          // Course and Due Date
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCourseId,
                    decoration: InputDecoration(
                      labelText: l10n.translate('course'),
                      prefixIcon: const Icon(Icons.school_outlined, size: 20),
                    ),
                    items: courses.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: c.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Text(c.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedCourseId = v),
                    validator: (v) => v == null
                        ? l10n.translate('select_course_error')
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l10n.translate('due_date'),
                        prefixIcon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 20,
                        ),
                        suffixIcon: const Icon(Icons.arrow_drop_down, size: 22),
                      ),
                      child: Text(
                        DateFormat.yMMMd().format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedCourseId,
              decoration: InputDecoration(
                labelText: l10n.translate('course'),
                prefixIcon: const Icon(Icons.school_outlined, size: 20),
              ),
              items: courses.map((c) {
                return DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: c.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(c.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedCourseId = v),
              validator: (v) =>
                  v == null ? l10n.translate('select_course_error') : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.translate('due_date'),
                  prefixIcon: const Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                  ),
                  suffixIcon: const Icon(Icons.arrow_drop_down, size: 22),
                ),
                child: Text(
                  DateFormat.yMMMd().format(_selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Priority Section
          Text(
            l10n.translate('priority'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SegmentedButton<AssignmentPriority>(
            segments: [
              ButtonSegment(
                value: AssignmentPriority.low,
                icon: Icon(
                  Icons.circle,
                  size: 10,
                  color: _getPriorityColor(AssignmentPriority.low),
                ),
                label: Text(l10n.translate('low')),
              ),
              ButtonSegment(
                value: AssignmentPriority.medium,
                icon: Icon(
                  Icons.circle,
                  size: 10,
                  color: _getPriorityColor(AssignmentPriority.medium),
                ),
                label: Text(l10n.translate('medium')),
              ),
              ButtonSegment(
                value: AssignmentPriority.high,
                icon: Icon(
                  Icons.circle,
                  size: 10,
                  color: _getPriorityColor(AssignmentPriority.high),
                ),
                label: Text(l10n.translate('high')),
              ),
            ],
            selected: {_priority},
            onSelectionChanged: (v) => setState(() => _priority = v.first),
          ),
          const SizedBox(height: 20),

          // Description Field
          AppTextField(
            label: l10n.translate('description'),
            hint: l10n.translate('hint_assignment_notes'),
            controller: _descriptionController,
            maxLines: 4,
          ),
          const SizedBox(height: 32),

          // Action Buttons
          if (isWide)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _cancelOrClose,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(l10n.translate('cancel')),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _saveAssignment,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(l10n.translate('save_assignment')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            )
          else
            AppButton(
              text: l10n.translate('save_assignment'),
              isLoading: _isLoading,
              onPressed: _saveAssignment,
            ),
        ],
      ),
    );

    if (isWide) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _cancelOrClose,
          ),
          title: Text(
            l10n.translate(_title),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Material(
                color: theme.colorScheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.assignment_add,
                              color: theme.colorScheme.onPrimaryContainer,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.translate(_title),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.translate('assignment_form_subtitle'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 24),
                      formContent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate(_title))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: formContent,
      ),
    );
  }

  String get _title => _isEditing ? 'edit_assignment' : 'add_assignment';

  /// Assignments belong to a course, so without one the form can't be saved.
  Widget _buildNeedsCourse(AppLocalizations l10n, ThemeData theme) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate(_title))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('no_courses_assignment_hint'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/courses/add'),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.translate('add_course_first')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
