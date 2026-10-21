import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rocis_schedule/features/courses/services/course_notes_folder_service.dart';
import 'package:rocis_schedule/features/courses/services/course_notes_pdf_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:share_plus/share_plus.dart';

/// Lets the user pick page count and paper, then shares a per-course notebook
/// PDF to a notes app (Goodnotes, Notability, ...) through the system share sheet.
class CourseNotesSheet extends StatefulWidget {
  final Course course;
  final List<ScheduleEvent> events;
  final CourseNotesPdfService? pdfService;
  final CourseNotesFolderService? folderService;

  const CourseNotesSheet({
    super.key,
    required this.course,
    required this.events,
    this.pdfService,
    this.folderService,
  });

  static const pageOptions = [10, 25, 50, 100];

  static Future<void> show(
    BuildContext context, {
    required Course course,
    required List<ScheduleEvent> events,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CourseNotesSheet(course: course, events: events),
    );
  }

  @override
  State<CourseNotesSheet> createState() => _CourseNotesSheetState();
}

class _CourseNotesSheetState extends State<CourseNotesSheet> {
  late final CourseNotesPdfService _pdfService;
  late final CourseNotesFolderService _folderService;
  int _pages = 25;
  NotesPaperStyle _paper = NotesPaperStyle.ruled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pdfService = widget.pdfService ?? CourseNotesPdfService();
    _folderService = widget.folderService ?? CourseNotesFolderService();
  }

  Future<Uint8List> _buildBytes(AppLocalizations l10n) {
    return _pdfService.buildPdf(
      course: widget.course,
      events: widget.events,
      instructorLabel: l10n.translate('instructor'),
      scheduleLabel: l10n.translate('schedule'),
      localeCode: Localizations.localeOf(context).languageCode,
      textDirection: Directionality.of(context),
      pageCount: _pages,
      paper: _paper,
    );
  }

  Future<void> _saveToFolder() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    var message = 'notes_saved';
    try {
      if (await _folderService.current() == null) {
        final picked = await _folderService.pickRoot();
        if (picked == null) return;
      }
      await _folderService.saveCoursePdf(
        widget.course,
        await _buildBytes(l10n),
      );
      if (mounted) Navigator.pop(context);
    } on NotesFolderAccessLost {
      message = 'notes_folder_access_lost';
    } catch (_) {
      message = 'notes_share_failed';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.translate(message)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createAndShare(BuildContext buttonContext) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final box = buttonContext.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;

    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      final bytes = await _buildBytes(l10n);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: [CourseNotesPdfService.fileNameFor(widget.course)],
          title: widget.course.name,
          sharePositionOrigin: origin,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.translate('notes_share_failed')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = widget.course.color;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        tintColor: primary,
        opacity: 0.22,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.note_add_outlined, color: primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('notes_send_to_app'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.course.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.translate('notes_pages'),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final n in CourseNotesSheet.pageOptions)
                      ChoiceChip(
                        label: Text('$n'),
                        selected: _pages == n,
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _pages = n),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.translate('notes_paper'),
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<NotesPaperStyle>(
                  segments: [
                    ButtonSegment(
                      value: NotesPaperStyle.ruled,
                      label: Text(l10n.translate('notes_paper_ruled')),
                      icon: const Icon(Icons.format_line_spacing_rounded),
                    ),
                    ButtonSegment(
                      value: NotesPaperStyle.grid,
                      label: Text(l10n.translate('notes_paper_grid')),
                      icon: const Icon(Icons.grid_on_rounded),
                    ),
                  ],
                  selected: {_paper},
                  onSelectionChanged: _busy
                      ? null
                      : (s) => setState(() => _paper = s.first),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.translate('notes_share_hint'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Builder(
                    builder: (buttonContext) => FilledButton.icon(
                      onPressed:
                          _busy ? null : () => _createAndShare(buttonContext),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ios_share_rounded),
                      label: Text(l10n.translate('notes_create_share')),
                    ),
                  ),
                ),
                if (CourseNotesFolderService.isSupported) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _saveToFolder,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: Text(l10n.translate('notes_save_to_folder')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
