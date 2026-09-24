import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/courses/widgets/semester_dates_sheet.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/app_button.dart';
import 'package:rocis_schedule/shared/widgets/app_text_field.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';

class AddCourseScreen extends StatefulWidget {
  final Course? courseToEdit;

  const AddCourseScreen({super.key, this.courseToEdit});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _instructorController;
  late final TextEditingController _creditsController;
  late Color _selectedColor;
  late String _selectedSemester;
  bool _isLoading = false;

  final List<Color> _colors = const [
    Color(0xFF6366F1), // Indigo
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Rose
    Color(0xFF8B5CF6), // Violet
    Color(0xFF14B8A6), // Teal
    Color(0xFFEC4899), // Pink
  ];

  @override
  void initState() {
    super.initState();
    final editing = widget.courseToEdit;
    _nameController = TextEditingController(text: editing?.name ?? '');
    _codeController = TextEditingController(text: editing?.code ?? '');
    _instructorController = TextEditingController(
      text: editing?.instructor ?? '',
    );
    _creditsController = TextEditingController(
      text: editing != null
          ? (editing.credits % 1 == 0
                ? editing.credits.toInt().toString()
                : editing.credits.toString())
          : '',
    );
    _selectedColor = editing?.color ?? const Color(0xFF6366F1);
    _selectedSemester = editing?.semester ?? 'semester_1';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _instructorController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  void _cancelOrClose() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/courses');
    }
  }

  String _getSemesterName(
    String id,
    String defaultName,
    AppLocalizations l10n,
  ) {
    switch (id) {
      case 'semester_1':
        return l10n.translate('first_semester');
      case 'semester_2':
        return l10n.translate('second_semester');
      case 'semester_summer':
        return l10n.translate('summer_semester');
      default:
        return defaultName;
    }
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final creditsValue =
          double.tryParse(_creditsController.text.trim()) ?? 3.0;

      if (widget.courseToEdit != null) {
        final updated = widget.courseToEdit!.copyWith(
          name: _nameController.text.trim(),
          code: _codeController.text.trim().toUpperCase(),
          instructor: _instructorController.text.trim(),
          credits: creditsValue,
          color: _selectedColor,
          semester: _selectedSemester,
        );
        await context.read<CourseProvider>().updateCourse(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('course_updated'))),
          );
          _cancelOrClose();
        }
      } else {
        final course = Course(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          code: _codeController.text.trim().toUpperCase(),
          instructor: _instructorController.text.trim(),
          credits: creditsValue,
          color: _selectedColor,
          semester: _selectedSemester,
        );
        await context.read<CourseProvider>().addCourse(course);
        if (mounted) _cancelOrClose();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEditing = widget.courseToEdit != null;
    final isWide = MediaQuery.of(context).size.width >= 720;
    final provider = context.watch<CourseProvider>();
    final semesters = provider.semesters.isNotEmpty
        ? provider.semesters
        : CourseProvider.defaultSemesters;

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Course Name & Code Row
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    label: l10n.translate('course_name'),
                    hint: 'e.g. Computer Science 101',
                    controller: _nameController,
                    validator: (v) => (v != null && v.trim().isNotEmpty)
                        ? null
                        : l10n.translate('field_required'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    label: l10n.translate('course_code'),
                    hint: 'e.g. CS101',
                    controller: _codeController,
                    validator: (v) => (v != null && v.trim().isNotEmpty)
                        ? null
                        : l10n.translate('field_required'),
                  ),
                ),
              ],
            )
          else ...[
            AppTextField(
              label: l10n.translate('course_name'),
              hint: 'e.g. Computer Science 101',
              controller: _nameController,
              validator: (v) => (v != null && v.trim().isNotEmpty)
                  ? null
                  : l10n.translate('field_required'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: l10n.translate('course_code'),
              hint: 'e.g. CS101',
              controller: _codeController,
              validator: (v) => (v != null && v.trim().isNotEmpty)
                  ? null
                  : l10n.translate('field_required'),
            ),
          ],
          const SizedBox(height: 16),

          // Instructor & Credits Row
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    label: l10n.translate('instructor'),
                    hint: 'Dr. Jane Doe',
                    controller: _instructorController,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    label: l10n.translate('credits_label'),
                    hint: '3.0',
                    controller: _creditsController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l10n.translate('field_required');
                      }
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null || parsed <= 0) {
                        return l10n.translate('invalid_number');
                      }
                      return null;
                    },
                  ),
                ),
              ],
            )
          else ...[
            AppTextField(
              label: l10n.translate('instructor'),
              hint: 'Dr. Jane Doe',
              controller: _instructorController,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: l10n.translate('credits_label'),
              hint: '3.0',
              controller: _creditsController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return l10n.translate('field_required');
                }
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) {
                  return l10n.translate('invalid_number');
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 16),

          // Semester Selector
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: semesters.any((s) => s.id == _selectedSemester)
                      ? _selectedSemester
                      : (semesters.isNotEmpty
                            ? semesters.first.id
                            : 'semester_1'),
                  decoration: InputDecoration(
                    labelText: l10n.translate('semester'),
                    prefixIcon: const Icon(Icons.school_outlined, size: 20),
                  ),
                  items: semesters.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text(_getSemesterName(s.id, s.name, l10n)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSemester = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: l10n.translate('semester_dates'),
                icon: const Icon(Icons.calendar_month_rounded),
                onPressed: () => SemesterDatesSheet.show(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Color Palette Section
          Text(
            l10n.translate('course_color'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _colors.map((color) {
              final isSelected = _selectedColor == color;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedColor = color);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: theme.colorScheme.onSurface,
                            width: 2.5,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 36),

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
                  onPressed: _isLoading ? null : _saveCourse,
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
                  label: Text(
                    isEditing
                        ? l10n.translate('save_course')
                        : l10n.translate('save_course'),
                  ),
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
              text: l10n.translate('save_course'),
              isLoading: _isLoading,
              onPressed: _saveCourse,
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
            isEditing
                ? l10n.translate('edit_course')
                : l10n.translate('add_course'),
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
                              Icons.school_rounded,
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
                                  isEditing
                                      ? l10n.translate('edit_course')
                                      : l10n.translate('add_course'),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Set up course credentials, credit load, and calendar color',
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
      appBar: AppBar(
        title: Text(
          isEditing
              ? l10n.translate('edit_course')
              : l10n.translate('add_course'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: formContent,
      ),
    );
  }
}
