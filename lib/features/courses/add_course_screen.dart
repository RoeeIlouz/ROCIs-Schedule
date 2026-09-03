import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/app_button.dart';
import 'package:rocis_schedule/shared/widgets/app_text_field.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';

class AddCourseScreen extends StatefulWidget {
  const AddCourseScreen({super.key});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _instructorController = TextEditingController();
  final _creditsController = TextEditingController();
  Color _selectedColor = const Color(0xFF6366F1);
  bool _isLoading = false;

  final List<Color> _colors = const [
    Color(0xFF6366F1), // Primary Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEC4899), // Pink
    Color(0xFF3B82F6), // Blue
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _instructorController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final creditsValue =
          double.tryParse(_creditsController.text.trim()) ?? 3.0;
      final course = Course(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        code: _codeController.text.trim().toUpperCase(),
        instructor: _instructorController.text.trim(),
        credits: creditsValue,
        color: _selectedColor,
      );

      await context.read<CourseProvider>().addCourse(course);
      if (mounted) context.pop();
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('add_course'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),
              Text(
                l10n.translate('course_color'),
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final color = _colors[index];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: _selectedColor == color
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: _selectedColor == color
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 48),
              AppButton(
                text: l10n.translate('save_course'),
                isLoading: _isLoading,
                onPressed: _saveCourse,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
