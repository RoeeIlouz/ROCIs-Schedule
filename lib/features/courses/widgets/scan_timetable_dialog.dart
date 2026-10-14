import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rocis_schedule/features/courses/services/ocr_scanner_service.dart';
import 'package:rocis_schedule/features/courses/widgets/ocr_import_review_sheet.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

Future<void> showScanTimetableDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ScanTimetableSheet(),
  );
}

class ScanTimetableSheet extends StatefulWidget {
  const ScanTimetableSheet({super.key});

  @override
  State<ScanTimetableSheet> createState() => _ScanTimetableSheetState();
}

class _ScanTimetableSheetState extends State<ScanTimetableSheet> {
  bool _isProcessing = false;
  bool _showPasteArea = false;
  final TextEditingController _pasteController = TextEditingController();

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _handleImagePick(ImageSource source) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final xfile = await OcrScannerService.pickImage(source);
      if (xfile == null) return;

      setState(() => _isProcessing = true);
      HapticFeedback.lightImpact();

      final result = await OcrScannerService.processImageFile(xfile.path);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close selector sheet

      if (result.drafts.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.translate('no_courses_found_ocr')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Open the interactive review sheet
      await OcrImportReviewSheet.show(context, result: result);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Scanning failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleParsePastedText() async {
    final text = _pasteController.text.trim();
    if (text.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      final result = OcrScannerService.processRawText(text);

      if (!mounted) return;
      Navigator.of(context).pop(); // Close selector sheet

      if (result.drafts.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.translate('no_courses_found_ocr')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await OcrImportReviewSheet.show(context, result: result);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Parsing failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassContainer(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        tintColor: primary,
        opacity: 0.22,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle Bar
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

                // Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.document_scanner_rounded,
                        color: primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('scan_timetable'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.translate('scan_timetable_desc'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_isProcessing)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            l10n.translate('processing_ocr'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Action 1: Camera
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(l10n.translate('take_photo')),
                    subtitle: const Text('Capture photo with camera'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _handleImagePick(ImageSource.camera),
                  ),
                  const SizedBox(height: 8),

                  // Action 2: Gallery
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.photo_library_rounded,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(l10n.translate('choose_from_gallery')),
                    subtitle: const Text('Pick screenshot or image document'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _handleImagePick(ImageSource.gallery),
                  ),
                  const SizedBox(height: 8),

                  // Action 3: Paste Text Toggle
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.content_paste_rounded,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    title: Text(l10n.translate('paste_syllabus_text')),
                    subtitle: const Text('Paste text copied from PDF or portal'),
                    trailing: Icon(
                      _showPasteArea
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                    ),
                    onTap: () {
                      setState(() => _showPasteArea = !_showPasteArea);
                    },
                  ),

                  if (_showPasteArea) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pasteController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Paste timetable or syllabus text here…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.analytics_outlined),
                        label: const Text('Parse Text'),
                        onPressed: _handleParsePastedText,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
