import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/courses/services/course_notes_folder_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

/// Settings tiles for the notes folder: pick the root folder, and create a
/// subfolder for every course in it. Android only (see [CourseNotesFolderService]).
class NotesFolderTiles extends StatefulWidget {
  final CourseNotesFolderService? service;

  const NotesFolderTiles({super.key, this.service});

  @override
  State<NotesFolderTiles> createState() => _NotesFolderTilesState();
}

class _NotesFolderTilesState extends State<NotesFolderTiles> {
  late final CourseNotesFolderService _service;
  NotesFolder? _folder;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CourseNotesFolderService();
    _refresh();
  }

  Future<void> _refresh() async {
    NotesFolder? folder;
    try {
      folder = await _service.current();
    } catch (_) {
      folder = null;
    }
    if (mounted) {
      setState(() {
        _folder = folder;
        _loading = false;
      });
    }
  }

  Future<void> _pick() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      final picked = await _service.pickRoot();
      if (picked != null && mounted) setState(() => _folder = picked);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.translate('notes_share_failed'))),
      );
    }
  }

  Future<void> _createFolders() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final courses = context.read<CourseProvider>().courses;
    setState(() => _busy = true);
    var message = 'notes_folders_created';
    try {
      await _service.ensureAllCourseFolders(courses);
    } on NotesFolderAccessLost {
      message = 'notes_folder_access_lost';
      if (mounted) setState(() => _folder = null);
    } catch (_) {
      message = 'notes_share_failed';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.translate(message))),
    );
  }

  Widget _leading(BuildContext context, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasFolder = _folder != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: _leading(context, Icons.folder_open_rounded, Colors.amber),
          title: Text(l10n.translate('notes_folder_title')),
          subtitle: Text(
            _loading
                ? ''
                : hasFolder
                    ? _folder!.name
                    : l10n.translate('notes_folder_pick_hint'),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _pick,
        ),
        ListTile(
          enabled: hasFolder && !_busy,
          leading:
              _leading(context, Icons.create_new_folder_outlined, Colors.green),
          title: Text(l10n.translate('notes_create_course_folders')),
          trailing: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: hasFolder && !_busy ? _createFolders : null,
        ),
      ],
    );
  }
}
