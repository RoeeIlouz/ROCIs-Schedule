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
  Color _selectedColor = Colors.blue;
  bool _isLoading = false;

  final List<Color> _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
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
      final course = Course(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        code: _codeController.text.trim().toUpperCase(),
        instructor: _instructorController.text.trim(),
        credits: int.parse(_creditsController.text.trim()),
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
                validator: (v) => (v?.isNotEmpty ?? false) ? null : 'Required',
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: l10n.translate('course_code'),
                hint: 'e.g. CS101',
                controller: _codeController,
                validator: (v) => (v?.isNotEmpty ?? false) ? null : 'Required',
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
                hint: '3',
                controller: _creditsController,
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (int.tryParse(v ?? '') != null) ? null : 'Invalid',
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
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                                    color: color.withOpacity(0.5),
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
