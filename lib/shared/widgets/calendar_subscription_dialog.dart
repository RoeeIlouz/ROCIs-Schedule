import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/services/calendar_subscription_service.dart';

/// Connects the timetable to a live calendar link (e.g. the Afeka calendar),
/// syncs it now, or stops syncing.
Future<void> showCalendarSubscriptionDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _CalendarSubscriptionDialog(),
  );
}

class _CalendarSubscriptionDialog extends StatefulWidget {
  const _CalendarSubscriptionDialog();

  @override
  State<_CalendarSubscriptionDialog> createState() =>
      _CalendarSubscriptionDialogState();
}

class _CalendarSubscriptionDialogState
    extends State<_CalendarSubscriptionDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _subscribed = false;
  DateTime? _lastSync;
  String? _error;

  late final String _uid = context.read<AuthService>().effectiveUserId;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final url = await CalendarSubscriptionService.savedUrl(_uid);
    final last = await CalendarSubscriptionService.lastSync(_uid);
    if (!mounted) return;
    setState(() {
      _subscribed = url != null;
      _lastSync = last;
      if (url != null && _controller.text.isEmpty) _controller.text = url;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() {
        _controller.text = text;
        _error = null;
      });
    }
  }

  Future<void> _sync() async {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<CourseProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final typed = _controller.text.trim();
    if (typed.isEmpty) return;

    // Re-syncing the link already saved needs no new subscription.
    final saved = await CalendarSubscriptionService.savedUrl(_uid);
    if (!mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await provider.syncCalendarSubscription(
        newUrl: typed == saved ? null : typed,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? l10n.translate('calendar_sync_up_to_date')
                : l10n
                      .translate('calendar_sync_done')
                      .replaceAll('{added}', '${result.added}')
                      .replaceAll('{updated}', '${result.updated}')
                      .replaceAll('{removed}', '${result.removed}'),
          ),
        ),
      );
    } on CalendarSyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.translate(e.failure.l10nKey);
      });
    }
  }

  Future<void> _stop() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await CalendarSubscriptionService.clear(_uid);
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.translate('calendar_sync_stopped'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final last = _lastSync;

    return AlertDialog(
      title: Text(l10n.translate('calendar_sync_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('calendar_sync_desc'),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              // Calendar links are always left-to-right, even in Hebrew.
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: 'https://…/calendar.ics',
                errorText: _error,
                errorMaxLines: 3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _busy ? null : _paste,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l10n.translate('paste')),
              ),
            ),
            if (last != null)
              Text(
                l10n
                    .translate('calendar_sync_last')
                    .replaceAll(
                      '{time}',
                      DateFormat.yMMMd().add_Hm().format(last),
                    ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        if (_subscribed)
          TextButton(
            onPressed: _busy ? null : _stop,
            child: Text(l10n.translate('calendar_sync_stop')),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.translate('cancel')),
        ),
        FilledButton(
          onPressed: _busy ? null : _sync,
          child: Text(
            l10n.translate(_subscribed ? 'calendar_sync_now' : 'calendar_sync'),
          ),
        ),
      ],
    );
  }
}
