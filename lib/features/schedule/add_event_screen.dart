import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/app_button.dart';
import 'package:rocis_schedule/shared/widgets/app_text_field.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCourseId;
  EventType _selectedType = EventType.classType;
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  List<int> _selectedDays = [];
  bool _recurring = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startTime : _endTime),
    );
    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        final newDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          picked.hour,
          picked.minute,
        );
        if (isStart) {
          _startTime = newDateTime;
          if (_endTime.isBefore(_startTime)) {
            _endTime = _startTime.add(const Duration(hours: 1));
          }
        } else {
          _endTime = newDateTime;
        }
      });
    }
  }

  Future<void> _saveEvent() async {
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
      final event = ScheduleEvent(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        courseId: _selectedCourseId!,
        type: _selectedType,
        startTime: _startTime,
        endTime: _endTime,
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
        recurring: _recurring,
        daysOfWeek: _selectedDays,
      );

      await context.read<CourseProvider>().addEvent(event);
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
    final courses = context.watch<CourseProvider>().courses;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.translate('add_event'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: l10n.translate('event_title'),
                hint: 'e.g. Lecture, Midterm',
                controller: _titleController,
                validator: (v) => (v?.isNotEmpty ?? false) ? null : 'Required',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCourseId,
                decoration: InputDecoration(
                  labelText: l10n.translate('course'),
                ),
                items: courses.map((c) {
                  return DropdownMenuItem(value: c.id, child: Text(c.name));
                }).toList(),
                onChanged: (v) => setState(() => _selectedCourseId = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EventType>(
                value: _selectedType,
                decoration: InputDecoration(labelText: l10n.translate('type')),
                items: EventType.values.map((v) {
                  return DropdownMenuItem(
                    value: v,
                    child: Text(v.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text(l10n.translate('start_time')),
                      subtitle: Text(DateFormat.jm().format(_startTime)),
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text(l10n.translate('end_time')),
                      subtitle: Text(DateFormat.jm().format(_endTime)),
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(l10n.translate('recurring_event')),
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v),
              ),
              if (_recurring) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.translate('days_of_week'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (index) {
                    final isSelected = _selectedDays.contains(index);
                    return ChoiceChip(
                      label: Text(_getWeekdayName(index)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedDays.add(index);
                          } else {
                            _selectedDays.remove(index);
                          }
                        });
                      },
                    );
                  }),
                ),
              ],
              const SizedBox(height: 16),
              AppTextField(
                label: l10n.translate('location'),
                hint: 'Building, Room number',
                controller: _locationController,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: l10n.translate('notes'),
                hint: 'Add any details...',
                controller: _notesController,
              ),
              const SizedBox(height: 48),
              AppButton(
                text: l10n.translate('save_event'),
                isLoading: _isLoading,
                onPressed: _saveEvent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getWeekdayName(int index) {
    final l10n = AppLocalizations.of(context)!;
    if (l10n.locale.languageCode == 'he') {
      const days = ['א\'', 'ב\'', 'ג\'', 'ד\'', 'ה\'', 'ו\'', 'ש\''];
      return days[index % 7];
    }
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[index % 7];
  }
}
