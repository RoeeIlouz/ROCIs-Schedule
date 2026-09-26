import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';

/// Asks for pasted .ics content and imports its courses and events.
Future<void> showIcsImportDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _IcsImportDialog(),
  );
}

class _IcsImportDialog extends StatefulWidget {
  const _IcsImportDialog();

  @override
  State<_IcsImportDialog> createState() => _IcsImportDialogState();
}

class _IcsImportDialogState extends State<_IcsImportDialog> {
  final _controller = TextEditingController();
  bool _importing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) _controller.text = text;
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final result = IcsImportService.parseIcsContent(text);
    final messenger = ScaffoldMessenger.of(context);
    if (result.courses.isEmpty && result.events.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.translate('ics_nothing_found'))),
      );
      return;
    }

    setState(() => _importing = true);
    await context.read<CourseProvider>().importIcsTimetable(result);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n
              .translate('ics_imported')
              .replaceAll('{courses}', '${result.courses.length}')
              .replaceAll('{events}', '${result.events.length}'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.translate('import_timetable')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('import_ics_desc'),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'BEGIN:VCALENDAR\nBEGIN:VEVENT\n...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(l10n.translate('paste')),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.translate('cancel')),
        ),
        FilledButton(
          onPressed: _importing ? null : _import,
          child: Text(l10n.translate('import')),
        ),
      ],
    );
  }
}
