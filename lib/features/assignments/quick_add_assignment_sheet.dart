import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/assignments/add_assignment_screen.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/assignments/quick_add_parser.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A small panel for adding an assignment in a couple of taps: a title, a
/// course and a due date. Typing "calc hw friday" fills the course and date
/// chips too; "More details" opens the full form with what was entered.
class QuickAddAssignmentSheet extends StatefulWidget {
  final String? initialCourseId;

  const QuickAddAssignmentSheet({super.key, this.initialCourseId});

  static const _lastCourseKey = 'quick_add_last_course';

  /// Opens the panel, or the full form when there are no courses yet (it
  /// explains that a course is needed first).
  static Future<void> show(BuildContext context) async {
    final courses = context.read<CourseProvider>().courses;
    if (courses.isEmpty) {
      unawaited(context.push('/assignments/add'));
      return;
    }
    final guess = await _guessCourse(context.read<CourseProvider>());
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => QuickAddAssignmentSheet(initialCourseId: guess),
    );
  }

  /// The class going on now or that ended in the last two hours, else the
  /// course used last time, else the first course.
  static Future<String?> _guessCourse(CourseProvider provider) async {
    final courses = provider.courses;
    final byId = {for (final c in courses) c.id: c};
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    ScheduleEvent? best;
    var bestStart = -1;
    for (final e in provider.events) {
      if (!byId.containsKey(e.courseId) || e.allDay) continue;
      if (!provider.occursOn(e, now, byId)) continue;
      final start = e.startTime.hour * 60 + e.startTime.minute;
      final end = e.endTime.hour * 60 + e.endTime.minute;
      if (start <= nowMin + 10 && end >= nowMin - 120 && start > bestStart) {
        best = e;
        bestStart = start;
      }
    }
    if (best != null) return best.courseId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_lastCourseKey);
      if (last != null && byId.containsKey(last)) return last;
    } catch (_) {}
    return courses.first.id;
  }

  @override
  State<QuickAddAssignmentSheet> createState() =>
      _QuickAddAssignmentSheetState();
}

class _QuickAddAssignmentSheetState extends State<QuickAddAssignmentSheet> {
  final _controller = TextEditingController();
  late String? _courseId = widget.initialCourseId;
  late DateTime _due = _inDays(7);

  /// Set once the user taps a chip; typed words no longer override it.
  bool _courseTouched = false;
  bool _dateTouched = false;

  /// What the typed text said, so removing a word can undo its effect.
  String? _typedCourse;
  DateTime? _typedDate;
  String _title = '';
  bool _saving = false;

  static DateTime _inDays(int days) {
    final d = DateTime.now().add(Duration(days: days));
    return DateTime(d.year, d.month, d.day, 23, 59);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 3/4 is March 4 only for US users; everyone else writes the day first.
  bool get _monthFirst => Localizations.localeOf(context).countryCode == 'US';

  void _onChanged(String text) {
    final courses = context.read<CourseProvider>().courses;
    final parsed = QuickAddParser.parse(
      text,
      courses,
      DateTime.now(),
      monthFirst: _monthFirst,
    );
    setState(() {
      _title = parsed.title;
      if (!_courseTouched) {
        if (parsed.courseId != null) {
          _courseId = parsed.courseId;
        } else if (_typedCourse != null) {
          _courseId = widget.initialCourseId;
        }
      }
      if (!_dateTouched) {
        if (parsed.dueDate != null) {
          _due = parsed.dueDate!;
        } else if (_typedDate != null) {
          _due = _inDays(7);
        }
      }
      _typedCourse = parsed.courseId;
      _typedDate = parsed.dueDate;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      _dateTouched = true;
      _due = DateTime(date.year, date.month, date.day, 23, 59);
    });
  }

  Future<void> _save() async {
    final title = _title.trim();
    final courseId = _courseId;
    if (title.isEmpty || courseId == null || _saving) return;
    setState(() => _saving = true);
    final provider = context.read<AssignmentProvider>();
    await provider.addAssignment(
      Assignment(courseId: courseId, title: title, dueDate: _due),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(QuickAddAssignmentSheet._lastCourseKey, courseId);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  void _moreDetails() {
    final router = GoRouter.of(context);
    final courseId = _courseId;
    Navigator.of(context).pop();
    if (courseId == null) {
      router.push('/assignments/add');
      return;
    }
    router.push(
      '/assignments/add',
      extra: AssignmentPrefill(
        courseId: courseId,
        title: _title.trim().isEmpty ? null : _title.trim(),
        dueDate: _due,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final courses = context.watch<CourseProvider>().courses;
    final locale = Localizations.localeOf(context).toString();
    final today = DateUtils.dateOnly(DateTime.now());
    final dueDay = DateUtils.dateOnly(_due);

    final presets = <(String, int)>[
      (l10n.translate('tomorrow'), 1),
      (l10n.translate('quick_add_in_days').replaceAll('{days}', '3'), 3),
      (l10n.translate('next_week'), 7),
    ];
    final isPreset = presets.any(
      (p) => dueDay == today.add(Duration(days: p.$2)),
    );

    Widget chipRow(List<Widget> chips) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final c in chips)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: c,
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.translate('add_assignment'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l10n.translate('quick_add_hint'),
              ),
              onChanged: _onChanged,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            chipRow([
              for (final c in courses)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: c.color, radius: 6),
                  label: Text(c.name),
                  selected: c.id == _courseId,
                  onSelected: (_) => setState(() {
                    _courseTouched = true;
                    _courseId = c.id;
                  }),
                ),
            ]),
            const SizedBox(height: 8),
            chipRow([
              for (final p in presets)
                ChoiceChip(
                  label: Text(p.$1),
                  selected: dueDay == today.add(Duration(days: p.$2)),
                  onSelected: (_) => setState(() {
                    _dateTouched = true;
                    _due = _inDays(p.$2);
                  }),
                ),
              ChoiceChip(
                avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(
                  isPreset
                      ? l10n.translate('due_date')
                      : DateFormat.MMMEd(locale).format(_due),
                ),
                selected: !isPreset,
                onSelected: (_) => _pickDate(),
              ),
            ]),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: _moreDetails,
                  child: Text(l10n.translate('quick_add_more')),
                ),
                const Spacer(),
                FilledButton(
                  onPressed:
                      _title.trim().isEmpty || _courseId == null || _saving
                      ? null
                      : _save,
                  child: Text(l10n.translate('quick_add_add')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
