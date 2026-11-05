import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:share_plus/share_plus.dart';

/// Opens an assignment attachment: images preview in a zoomable dialog, other
/// files go to the system share sheet so any installed app can open them.
///
/// [bytes] resolves to the original (already inflated) file, or null when it
/// isn't available, e.g. never synced to this device and no connection.
Future<void> showAttachment(
  BuildContext context,
  AssignmentAttachment meta,
  Future<Uint8List?> bytes,
) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);

  if (meta.isImage) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(meta.name, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: MaterialLocalizations.of(
                    dialogContext,
                  ).closeButtonTooltip,
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
              Flexible(
                child: FutureBuilder<Uint8List?>(
                  future: bytes,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(48),
                        child: CircularProgressIndicator(),
                      );
                    }
                    final data = snapshot.data;
                    if (data == null) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(l10n.translate('attachment_unavailable')),
                      );
                    }
                    return InteractiveViewer(
                      maxScale: 5,
                      child: Image.memory(data, fit: BoxFit.contain),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return;
  }

  try {
    final data = await bytes;
    if (data == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.translate('attachment_unavailable'))),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(data, mimeType: meta.mime)],
        fileNameOverrides: [meta.name],
        title: meta.name,
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.translate('attachment_failed'))),
    );
  }
}
