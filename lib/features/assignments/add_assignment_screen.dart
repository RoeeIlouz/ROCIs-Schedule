import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/assignments/attachment_compressor.dart';
import 'package:rocis_schedule/features/assignments/attachment_viewer.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/guest_data_migrator.dart';
import 'package:rocis_schedule/shared/widgets/app_button.dart';
import 'package:rocis_schedule/shared/widgets/app_text_field.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

/// Values a new assignment starts with, e.g. when it is created from a
/// lecture: that lecture's course, event and session date.
class AssignmentPrefill {
  final String courseId;
  final String? lectureEventId;
  final DateTime? lectureDate;

  const AssignmentPrefill({
    required this.courseId,
    this.lectureEventId,
    this.lectureDate,
  });
}

class AddAssignmentScreen extends StatefulWidget {
  /// The assignment to edit; null to create a new one.
  final Assignment? assignmentToEdit;

  /// Starting values for a new assignment. Ignored when editing.
  final AssignmentPrefill? prefill;

  const AddAssignmentScreen({super.key, this.assignmentToEdit, this.prefill});

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

  /// The lecture this assignment was given in (event + the session's date).
  String? _lectureEventId;
  DateTime? _lectureDate;

  /// Attachments already saved, ones picked in this session, and saved ones
  /// the user removed. Changes only apply when the form is saved.
  late List<AssignmentAttachment> _attachments;
  final List<PreparedAttachment> _added = [];
  final List<AssignmentAttachment> _removed = [];
  int _preparing = 0;

  /// Files bigger than this are refused before being read into memory.
  static const _maxPickBytes = 25 * 1024 * 1024;

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
      _lectureEventId = assignment.lectureEventId;
      _lectureDate = assignment.lectureDate;
    } else if (widget.prefill case final prefill?) {
      _selectedCourseId = prefill.courseId;
      if (prefill.lectureEventId != null && prefill.lectureDate != null) {
        _lectureEventId = prefill.lectureEventId;
        _lectureDate = DateUtils.dateOnly(prefill.lectureDate!);
      }
    }
    _attachments = [...?assignment?.attachments];
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

  void _onCourseChanged(String? courseId) {
    setState(() {
      if (courseId != _selectedCourseId) {
        // A lecture belongs to one course; drop the link when it changes.
        _lectureEventId = null;
        _lectureDate = null;
      }
      _selectedCourseId = courseId;
    });
  }

  ScheduleEvent? _lectureEvent(CourseProvider provider) {
    final id = _lectureEventId;
    if (id == null) return null;
    for (final e in provider.events) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> _pickLecture() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final courseId = _selectedCourseId;
    if (courseId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.translate('select_course_error'))),
      );
      return;
    }
    final provider = context.read<CourseProvider>();
    final events = provider.getEventsByCourse(courseId);
    if (events.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.translate('no_lectures_for_course'))),
      );
      return;
    }

    final choice = await showModalBottomSheet<({ScheduleEvent? event})>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.translate('choose_lecture'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            for (final e in events)
              ListTile(
                leading: const Icon(Icons.event_rounded),
                title: Text(e.title),
                subtitle: Text(_eventSummary(e)),
                selected: e.id == _lectureEventId,
                onTap: () => Navigator.pop(sheetContext, (event: e)),
              ),
            if (_lectureEventId != null)
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: Text(l10n.translate('no_lecture_linked')),
                onTap: () => Navigator.pop(sheetContext, (event: null)),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final event = choice.event;
    if (event == null) {
      setState(() {
        _lectureEventId = null;
        _lectureDate = null;
      });
      return;
    }

    // Only days the lecture actually takes place can be picked.
    final courseMap = {for (final c in provider.courses) c.id: c};
    bool occurs(DateTime d) => provider.occursOn(event, d, courseMap);
    final today = DateUtils.dateOnly(DateTime.now());
    final first = today.subtract(const Duration(days: 365));

    DateTime? initial;
    final previous = _lectureEventId == event.id ? _lectureDate : null;
    if (previous != null &&
        !previous.isBefore(first) &&
        !previous.isAfter(today) &&
        occurs(previous)) {
      initial = DateUtils.dateOnly(previous);
    } else {
      for (var i = 0; i <= 365; i++) {
        final d = today.subtract(Duration(days: i));
        if (occurs(d)) {
          initial = d;
          break;
        }
      }
    }
    if (initial == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.translate('no_lecture_dates'))),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today,
      selectableDayPredicate: occurs,
      helpText: l10n.translate('lecture_date_help'),
    );
    if (date == null || !mounted) return;
    setState(() {
      _lectureEventId = event.id;
      _lectureDate = date;
    });
  }

  String _eventSummary(ScheduleEvent e) {
    final time =
        '${DateFormat.Hm().format(e.startTime)}-${DateFormat.Hm().format(e.endTime)}';
    if (e.recurring && e.daysOfWeek.isNotEmpty) {
      // daysOfWeek: 0 = Sunday, and 2023-01-01 was a Sunday.
      final days = (e.daysOfWeek.toList()..sort())
          .map((d) => DateFormat.E().format(DateTime(2023, 1, 1 + (d % 7))))
          .join(', ');
      return '$days  $time';
    }
    return '${DateFormat.MMMEd().format(e.startTime)}  $time';
  }

  String _lectureLabel(CourseProvider provider, AppLocalizations l10n) {
    final date = _lectureDate;
    if (_lectureEventId == null || date == null) {
      return l10n.translate('no_lecture_linked');
    }
    final title = _lectureEvent(provider)?.title;
    final when = DateFormat.MMMEd().format(date);
    return title == null || title.isEmpty ? when : '$title  ·  $when';
  }

  static const _maxAttachments = 10;

  int get _attachmentTotal => _attachments.length + _added.length;

  Future<void> _addPhotos(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    final picker = ImagePicker();
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final shot = await picker.pickImage(source: source);
        picked = shot == null ? const [] : [shot];
      } else {
        picked = await picker.pickMultiImage();
      }
      for (final file in picked) {
        if (!_fitsAttachmentCount(l10n)) break;
        await _prepareAttachment(l10n, file.name, await file.readAsBytes());
      }
    } catch (_) {
      _showMessage(l10n.translate('attachment_failed'));
    }
  }

  Future<void> _addFiles() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final picked = await FilePicker.pickFiles();
      for (final file in picked) {
        if (!_fitsAttachmentCount(l10n)) break;
        final length = await file.length();
        if (length != null && length > _maxPickBytes) {
          _showMessage(
            l10n
                .translate('attachment_too_large')
                .replaceAll('{name}', file.name),
          );
          continue;
        }
        await _prepareAttachment(l10n, file.name, await file.readAsBytes());
      }
    } catch (_) {
      _showMessage(l10n.translate('attachment_failed'));
    }
  }

  bool _fitsAttachmentCount(AppLocalizations l10n) {
    if (_attachmentTotal + _preparing < _maxAttachments) return true;
    _showMessage(
      l10n
          .translate('attachment_limit_reached')
          .replaceAll('{max}', '$_maxAttachments'),
    );
    return false;
  }

  Future<void> _prepareAttachment(
    AppLocalizations l10n,
    String name,
    Uint8List bytes,
  ) async {
    if (bytes.length > _maxPickBytes) {
      _showMessage(
        l10n.translate('attachment_too_large').replaceAll('{name}', name),
      );
      return;
    }
    setState(() => _preparing++);
    try {
      final prepared = await prepareAttachment(name: name, bytes: bytes);
      if (!mounted) return;
      setState(() => _added.add(prepared));
    } on AttachmentTooLargeException catch (e) {
      _showMessage(
        l10n.translate('attachment_too_large').replaceAll('{name}', e.fileName),
      );
    } catch (_) {
      _showMessage(l10n.translate('attachment_failed'));
    } finally {
      if (mounted) setState(() => _preparing--);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openAttachment(AssignmentAttachment meta) {
    final added = _added.where((p) => p.meta.id == meta.id).firstOrNull;
    final saved = widget.assignmentToEdit;
    final Future<Uint8List?> bytes;
    if (added != null) {
      bytes = Future.value(restoreAttachmentBytes(meta, added.data));
    } else if (saved != null) {
      bytes = context.read<AssignmentProvider>().loadAttachmentBytes(
        saved,
        meta,
      );
    } else {
      bytes = Future.value(null);
    }
    showAttachment(context, meta, bytes);
  }

  void _removeAttachment(AssignmentAttachment meta) {
    setState(() {
      final addedIndex = _added.indexWhere((p) => p.meta.id == meta.id);
      if (addedIndex >= 0) {
        _added.removeAt(addedIndex);
      } else {
        _attachments.removeWhere((a) => a.id == meta.id);
        _removed.add(meta);
      }
    });
  }

  Future<void> _saveAssignment() async {
    final l10n = AppLocalizations.of(context)!;
    if (_preparing > 0) {
      _showMessage(l10n.translate('attachment_processing'));
      return;
    }
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
        lectureEventId: _lectureEventId,
        lectureDate: _lectureDate,
        attachments: _attachments,
      );

      await context.read<AssignmentProvider>().saveWithAttachments(
        assignment,
        added: _added,
        removed: _removed,
      );
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
                    onChanged: _onCourseChanged,
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
              onChanged: _onCourseChanged,
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

          // Lecture this assignment was given in
          _buildLectureTile(l10n),
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
          const SizedBox(height: 20),

          _buildAttachmentsSection(l10n, theme),
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
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
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

  Widget _buildLectureTile(AppLocalizations l10n) {
    final provider = context.watch<CourseProvider>();
    final linked = _lectureEventId != null && _lectureDate != null;
    return InkWell(
      onTap: _pickLecture,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.translate('given_in_lecture'),
          prefixIcon: const Icon(Icons.event_rounded, size: 20),
          suffixIcon: linked
              ? IconButton(
                  tooltip: l10n.translate('no_lecture_linked'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => setState(() {
                    _lectureEventId = null;
                    _lectureDate = null;
                  }),
                )
              : const Icon(Icons.arrow_drop_down, size: 22),
        ),
        child: Text(
          _lectureLabel(provider, l10n),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: linked ? null : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection(AppLocalizations l10n, ThemeData theme) {
    final items = [..._attachments, ..._added.map((p) => p.meta)];
    final canCamera =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('attachments'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        for (final meta in items)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 6),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                meta.isImage
                    ? Icons.photo_library_outlined
                    : Icons.upload_file_rounded,
              ),
              title: Text(meta.name, overflow: TextOverflow.ellipsis),
              subtitle: Text('${(meta.size / 1024).ceil()} KB'),
              onTap: () => _openAttachment(meta),
              trailing: IconButton(
                tooltip: l10n.translate('remove'),
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => _removeAttachment(meta),
              ),
            ),
          ),
        if (context.read<AssignmentProvider>().uid ==
            GuestDataMigrator.guestUserId)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.translate('attachments_guest_warning'),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (_preparing > 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _addPhotos(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: Text(l10n.translate('add_photo')),
            ),
            if (canCamera)
              OutlinedButton.icon(
                onPressed: () => _addPhotos(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: Text(l10n.translate('take_photo')),
              ),
            OutlinedButton.icon(
              onPressed: _addFiles,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(l10n.translate('add_file')),
            ),
          ],
        ),
      ],
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
