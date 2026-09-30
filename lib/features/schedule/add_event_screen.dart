import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/event_collision_service.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/widgets/app_button.dart';
import 'package:rocis_schedule/shared/widgets/app_text_field.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';

class AddEventScreen extends StatefulWidget {
  /// The event to edit; null to create a new one.
  final ScheduleEvent? eventToEdit;

  /// Pre-fills a new event's date and start hour (e.g. a tapped grid slot).
  final DateTime? initialStart;

  const AddEventScreen({super.key, this.eventToEdit, this.initialStart});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  EventDomain _selectedDomain = EventDomain.academic;
  Color? _customColor;

  static const List<Color> _workColorPalette = [
    Color(0xFF0284C7), // Sky Blue (Default Work)
    Color(0xFF0D9488), // Teal
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF4F46E5), // Indigo
    Color(0xFF0891B2), // Cyan
    Color(0xFF475569), // Slate
  ];

  static const List<Color> _personalColorPalette = [
    Color(0xFF8B5CF6), // Purple (Default Personal)
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFFE11D48), // Rose
    Color(0xFFF97316), // Orange
  ];

  String? _selectedCourseId;
  EventType _selectedType = EventType.classType;
  DateTime _eventDate = DateTime.now();
  TimeOfDay _startTimeOfDay = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTimeOfDay = const TimeOfDay(hour: 10, minute: 30);
  final List<int> _selectedDays = [];
  bool _recurring = true;
  bool _isLoading = false;

  bool get _isEditing => widget.eventToEdit != null;

  @override
  void initState() {
    super.initState();
    final event = widget.eventToEdit;
    if (event != null) {
      _titleController.text = event.title;
      _locationController.text = event.location;
      _notesController.text = event.notes;
      _selectedDomain = event.domain;
      _customColor = event.color;
      _selectedCourseId = event.courseId.isEmpty ? null : event.courseId;
      _selectedType = event.type;
      _eventDate = event.startTime;
      _startTimeOfDay = TimeOfDay.fromDateTime(event.startTime);
      _endTimeOfDay = TimeOfDay.fromDateTime(event.endTime);
      _selectedDays.addAll(event.daysOfWeek);
      _recurring = event.recurring;
      return;
    }
    final start = widget.initialStart;
    if (start != null) {
      _eventDate = start;
      _startTimeOfDay = TimeOfDay.fromDateTime(start);
      _endTimeOfDay = TimeOfDay(hour: (start.hour + 1) % 24, minute: 0);
      _selectedDays.add(start.weekday % 7);
      return;
    }
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

  void _cancelOrClose() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/schedule');
    }
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
      // Editing an old event must not start before the picker's range.
      firstDate: _eventDate.isBefore(DateTime(DateTime.now().year - 1))
          ? _eventDate
          : DateTime(DateTime.now().year - 1),
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
    final courses = context.read<CourseProvider>().courses;
    final isAcademic = _selectedDomain == EventDomain.academic;
    final effectiveCourseId =
        _selectedCourseId ?? (courses.isNotEmpty ? courses.first.id : null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (isAcademic && effectiveCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.translate('select_course_error'))),
      );
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
        id: widget.eventToEdit?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        courseId: isAcademic ? (effectiveCourseId ?? '') : '',
        type: isAcademic ? _selectedType : EventType.other,
        startTime: startDateTime,
        endTime: endDateTime,
        location: _locationController.text.trim(),
        notes: _notesController.text.trim(),
        recurring: _recurring,
        daysOfWeek: _selectedDays,
        domain: _selectedDomain,
        color: isAcademic ? null : _customColor,
      );

      await context.read<CourseProvider>().addEvent(event);
      if (mounted) {
        _cancelOrClose();
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

  String _formatTimeOfDay(BuildContext context, TimeOfDay time) {
    bool use24 = false;
    try {
      use24 = Provider.of<ThemeProvider>(
        context,
        listen: false,
      ).use24HourFormat;
    } catch (_) {
      use24 = MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false;
    }
    final dt = DateTime(2026, 1, 1, time.hour, time.minute);
    if (use24) {
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
    // 2023-01-01 was a Sunday.
    return DateFormat.E().format(DateTime(2023, 1, 1 + index % 7));
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final courses = courseProvider.courses;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 768;

    final initialCourseId =
        (_selectedCourseId != null &&
            courses.any((c) => c.id == _selectedCourseId))
        ? _selectedCourseId
        : (courses.isNotEmpty ? courses.first.id : null);

    final coursesMap = {for (var c in courses) c.id: c};

    // Construct candidate event for live collision detection
    final candidateEvent = ScheduleEvent(
      id: '',
      title: _titleController.text.trim(),
      courseId: _selectedDomain == EventDomain.academic
          ? (initialCourseId ?? '')
          : '',
      type: _selectedDomain == EventDomain.academic
          ? _selectedType
          : EventType.other,
      startTime: _buildDateTime(_eventDate, _startTimeOfDay),
      endTime: _buildDateTime(_eventDate, _endTimeOfDay),
      location: _locationController.text.trim(),
      notes: _notesController.text.trim(),
      recurring: _recurring,
      daysOfWeek: _selectedDays,
      domain: _selectedDomain,
      color: _customColor,
    );

    final otherEvents = courseProvider.events
        .where((e) => e.id != widget.eventToEdit?.id)
        .toList();
    final detectedConflicts = EventCollisionService.findConflicts(
      candidate: candidateEvent,
      existingEvents: otherEvents,
    );
    final hasWorkAcademic = EventCollisionService.hasWorkAcademicConflict(
      candidate: candidateEvent,
      existingEvents: otherEvents,
    );

    final formContent = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Domain Segmented Button
          Center(
            child: SegmentedButton<EventDomain>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment<EventDomain>(
                  value: EventDomain.academic,
                  icon: const Icon(Icons.school_outlined, size: 16),
                  label: Text(l10n.translate('domain_academic')),
                ),
                ButtonSegment<EventDomain>(
                  value: EventDomain.work,
                  icon: const Icon(Icons.work_outline_rounded, size: 16),
                  label: Text(l10n.translate('domain_work')),
                ),
                ButtonSegment<EventDomain>(
                  value: EventDomain.personal,
                  icon: const Icon(Icons.person_outline_rounded, size: 16),
                  label: Text(l10n.translate('domain_personal')),
                ),
              ],
              selected: {_selectedDomain},
              onSelectionChanged: (newSelection) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedDomain = newSelection.first;
                  if (_selectedDomain == EventDomain.work) {
                    _customColor ??= _workColorPalette.first;
                  } else if (_selectedDomain == EventDomain.personal) {
                    _customColor ??= _personalColorPalette.first;
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 20),

          // Live Collision Detection Banner
          if (detectedConflicts.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (hasWorkAcademic ? Colors.red : Colors.orange)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (hasWorkAcademic ? Colors.red : Colors.orange)
                      .withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: hasWorkAcademic
                            ? Colors.red
                            : Colors.orange.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.translate('collision_warning'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: hasWorkAcademic
                                ? Colors.red
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.translate('collision_warning_desc'),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...detectedConflicts.take(3).map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: hasWorkAcademic ? Colors.red : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              EventCollisionService.formatConflictSummary(
                                c,
                                course: coursesMap[c.courseId],
                              ),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          if (_selectedDomain == EventDomain.academic && courses.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('no_courses_add_event_hint'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/courses/add'),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l10n.translate('add_course_first')),
                  ),
                ],
              ),
            ),

          // Title Field
          AppTextField(
            label: l10n.translate('event_title'),
            hint: _selectedDomain == EventDomain.academic
                ? l10n.translate('hint_event_academic')
                : (_selectedDomain == EventDomain.work
                      ? l10n.translate('hint_event_work')
                      : l10n.translate('hint_event_personal')),
            controller: _titleController,
            validator: (v) => (v != null && v.trim().isNotEmpty)
                ? null
                : l10n.translate('field_required'),
          ),
          const SizedBox(height: 16),

          // Domain-specific fields
          if (_selectedDomain == EventDomain.academic) ...[
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: initialCourseId,
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
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<EventType>(
                      initialValue: _selectedType,
                      decoration: InputDecoration(
                        labelText: l10n.translate('type'),
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          size: 20,
                        ),
                      ),
                      items: EventType.values.map((v) {
                        return DropdownMenuItem(
                          value: v,
                          child: Text(_getEventTypeName(v, l10n)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedType = v);
                      },
                    ),
                  ),
                ],
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: initialCourseId,
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
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EventType>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: l10n.translate('type'),
                  prefixIcon: const Icon(Icons.category_outlined, size: 20),
                ),
                items: EventType.values.map((v) {
                  return DropdownMenuItem(
                    value: v,
                    child: Text(_getEventTypeName(v, l10n)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedType = v);
                },
              ),
            ],
          ] else if (_selectedDomain == EventDomain.work) ...[
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AppTextField(
                      label: l10n.translate('workplace'),
                      hint: l10n.translate('workplace_hint'),
                      controller: _locationController,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('event_color'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          children: _workColorPalette.map((color) {
                            final isSelected = _customColor == color;
                            return Semantics(
                              button: true,
                              selected: isSelected,
                              label: AppLocalizations.of(
                                context,
                              )!.translate('color'),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _customColor = color);
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
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
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              AppTextField(
                label: l10n.translate('workplace'),
                hint: l10n.translate('workplace_hint'),
                controller: _locationController,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('event_color'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _workColorPalette.map((color) {
                  final isSelected = _customColor == color;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: AppLocalizations.of(context)!.translate('color'),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _customColor = color);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
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
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ] else ...[
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AppTextField(
                      label: l10n.translate('location'),
                      hint: l10n.translate('hint_place'),
                      controller: _locationController,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('event_color'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          children: _personalColorPalette.map((color) {
                            final isSelected = _customColor == color;
                            return Semantics(
                              button: true,
                              selected: isSelected,
                              label: AppLocalizations.of(
                                context,
                              )!.translate('color'),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _customColor = color);
                                },
                                child: Container(
                                  width: 32,
                                  height: 32,
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
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              AppTextField(
                label: l10n.translate('location'),
                hint: l10n.translate('hint_place'),
                controller: _locationController,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.translate('event_color'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: _personalColorPalette.map((color) {
                  final isSelected = _customColor == color;
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: AppLocalizations.of(context)!.translate('color'),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _customColor = color);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
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
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
          const SizedBox(height: 20),

          // Date & Time Container
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.translate('recurring_event'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    value: _recurring,
                    onChanged: (v) => setState(() => _recurring = v),
                  ),
                  const SizedBox(height: 12),

                  // If one-time event vs recurring
                  if (!_recurring) ...[
                    if (isWide)
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l10n.translate('date'),
                                  prefixIcon: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 20,
                                  ),
                                ),
                                child: Text(
                                  DateFormat.yMMMd().format(_eventDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: () => _pickTime(true),
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l10n.translate('start_time'),
                                  prefixIcon: const Icon(
                                    Icons.schedule_rounded,
                                    size: 20,
                                  ),
                                ),
                                child: Text(
                                  _formatTimeOfDay(context, _startTimeOfDay),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: () => _pickTime(false),
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: l10n.translate('end_time'),
                                  prefixIcon: const Icon(
                                    Icons.timer_off_outlined,
                                    size: 20,
                                  ),
                                ),
                                child: Text(
                                  _formatTimeOfDay(context, _endTimeOfDay),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: theme.colorScheme.surface,
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
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tileColor: theme.colorScheme.surface,
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tileColor: theme.colorScheme.surface,
                              leading: Icon(
                                Icons.timer_off_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(l10n.translate('end_time')),
                              subtitle: Text(
                                _formatTimeOfDay(context, _endTimeOfDay),
                              ),
                              onTap: () => _pickTime(false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    // Recurring: Start & End time
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickTime(true),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.translate('start_time'),
                                prefixIcon: const Icon(
                                  Icons.schedule_rounded,
                                  size: 20,
                                ),
                              ),
                              child: Text(
                                _formatTimeOfDay(context, _startTimeOfDay),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickTime(false),
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: l10n.translate('end_time'),
                                prefixIcon: const Icon(
                                  Icons.timer_off_outlined,
                                  size: 20,
                                ),
                              ),
                              child: Text(
                                _formatTimeOfDay(context, _endTimeOfDay),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.translate('days_of_week'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Location Field (for academic mode)
          if (_selectedDomain == EventDomain.academic) ...[
            AppTextField(
              label: l10n.translate('location'),
              hint: l10n.translate('hint_location'),
              controller: _locationController,
              prefixIcon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 16),
          ],

          // Notes Field
          AppTextField(
            label: l10n.translate('notes'),
            hint: l10n.translate('hint_event_notes'),
            controller: _notesController,
            maxLines: 3,
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
                SizedBox(
                  width: 170,
                  child: AppButton(
                    text: l10n.translate('save_event'),
                    isLoading: _isLoading,
                    onPressed: _saveEvent,
                  ),
                ),
              ],
            )
          else
            AppButton(
              text: l10n.translate('save_event'),
              isLoading: _isLoading,
              onPressed: _saveEvent,
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
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _cancelOrClose,
          ),
          title: Text(
            l10n.translate(_isEditing ? 'edit_event' : 'add_event'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
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
                              Icons.calendar_month_rounded,
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
                                  l10n.translate(
                                    _isEditing ? 'edit_event' : 'add_event',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Schedule academic classes, work shifts, or personal appointments',
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
          l10n.translate(_isEditing ? 'edit_event' : 'add_event'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: formContent,
      ),
    );
  }
}
