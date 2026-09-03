import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/app_button.dart';
import 'package:rocis_schedule/shared/widgets/app_text_field.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
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
  DateTime _eventDate = DateTime.now();
  TimeOfDay _startTimeOfDay = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTimeOfDay = const TimeOfDay(hour: 10, minute: 30);
  final List<int> _selectedDays = [];
  bool _recurring = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startTimeOfDay = TimeOfDay(
      hour: now.hour,
      minute: (now.minute ~/ 15) * 15,
    );
    _endTimeOfDay = TimeOfDay(
      hour: (now.hour + 1) % 24,
      minute: (now.minute ~/ 15) * 15,
    );
    _selectedDays.add(now.weekday % 7);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime _buildDateTime(DateTime baseDate, TimeOfDay time) {
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTimeOfDay : _endTimeOfDay;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTimeOfDay = picked;
          final startMinutes = picked.hour * 60 + picked.minute;
          final endMinutes = _endTimeOfDay.hour * 60 + _endTimeOfDay.minute;
          if (endMinutes <= startMinutes) {
            _endTimeOfDay = TimeOfDay(
              hour: (picked.hour + 1) % 24,
              minute: picked.minute,
            );
          }
        } else {
          _endTimeOfDay = picked;
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

    if (_recurring && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('select_days_error'))),
      );
      return;
    }

    final startDateTime = _buildDateTime(_eventDate, _startTimeOfDay);
    final endDateTime = _buildDateTime(_eventDate, _endTimeOfDay);

    if (endDateTime.isBefore(startDateTime) ||
        endDateTime.isAtSameMomentAs(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('invalid_time_range'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();
    try {
      final event = ScheduleEvent(
        id: const Uuid().v4(),
        title: _titleController.text.trim(),
        courseId: _selectedCourseId!,
        type: _selectedType,
        startTime: startDateTime,
        endTime: endDateTime,
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

  String _getEventTypeName(EventType type, AppLocalizations l10n) {
    switch (type) {
      case EventType.classType:
        return l10n.translate('class_type');
      case EventType.exam:
        return l10n.translate('exam');
      case EventType.lab:
        return l10n.translate('lab');
      case EventType.study:
        return l10n.translate('study');
      case EventType.other:
        return l10n.translate('other');
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseProvider>().courses;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('add_event'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: l10n.translate('event_title'),
                hint: 'e.g. Lecture, Midterm Exam',
                controller: _titleController,
                validator: (v) => (v != null && v.trim().isNotEmpty)
                    ? null
                    : l10n.translate('field_required'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCourseId,
                decoration: InputDecoration(
                  labelText: l10n.translate('course'),
                ),
                items: courses.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
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
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EventType>(
                initialValue: _selectedType,
                decoration: InputDecoration(labelText: l10n.translate('type')),
                items: EventType.values.map((v) {
                  return DropdownMenuItem(
                    value: v,
                    child: Text(_getEventTypeName(v, l10n)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedType = v;
                      if (v == EventType.exam) {
                        _recurring = false;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: Text(l10n.translate('recurring_event')),
                value: _recurring,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: theme.colorScheme.surfaceContainerLow,
                onChanged: (v) => setState(() => _recurring = v),
              ),
              if (!_recurring) ...[
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: theme.colorScheme.surfaceContainerLow,
                  leading: Icon(
                    Icons.calendar_today_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.translate('date')),
                  subtitle: Text(
                    DateFormat.yMMMMEEEEd().format(_eventDate),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: _pickDate,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      tileColor: theme.colorScheme.surfaceContainerLow,
                      leading: Icon(
                        Icons.schedule_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(l10n.translate('start_time')),
                      subtitle: Text(
                        _formatTimeOfDay(context, _startTimeOfDay),
                      ),
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      tileColor: theme.colorScheme.surfaceContainerLow,
                      leading: Icon(
                        Icons.timer_off_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(l10n.translate('end_time')),
                      subtitle: Text(_formatTimeOfDay(context, _endTimeOfDay)),
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              if (_recurring) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.translate('days_of_week'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final isSelected = _selectedDays.contains(index);
                    return FilterChip(
                      label: Text(_getWeekdayName(index)),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primary.withValues(
                        alpha: 0.2,
                      ),
                      checkmarkColor: theme.colorScheme.primary,
                      onSelected: (selected) {
                        HapticFeedback.selectionClick();
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
                maxLines: 3,
              ),
              const SizedBox(height: 36),
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

  String _formatTimeOfDay(BuildContext context, TimeOfDay time) {
    final themeProvider = context.read<ThemeProvider>();
    final dt = DateTime(2026, 1, 1, time.hour, time.minute);
    if (themeProvider.use24HourFormat) {
      return DateFormat.Hm().format(dt);
    }
    return DateFormat.jm().format(dt);
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
