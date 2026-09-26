import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/services/google_calendar_sync_service.dart';

/// Settings switch for mirroring the schedule into Google Calendar.
class GoogleCalendarTile extends StatelessWidget {
  final Widget leading;

  const GoogleCalendarTile({super.key, required this.leading});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final sync = context.watch<GoogleCalendarSyncService>();

    final subtitle = switch (sync.status) {
      CalendarSyncStatus.off => l10n.translate('gcal_sync_desc'),
      CalendarSyncStatus.syncing => l10n.translate('gcal_syncing'),
      CalendarSyncStatus.synced =>
        l10n
            .translate('gcal_synced')
            .replaceAll('{count}', '${sync.syncedCount}'),
      CalendarSyncStatus.needsAccess => l10n.translate('gcal_needs_access'),
      CalendarSyncStatus.error => l10n.translate('gcal_error'),
    };
    final isProblem =
        sync.status == CalendarSyncStatus.needsAccess ||
        sync.status == CalendarSyncStatus.error;

    return SwitchListTile(
      secondary: leading,
      title: Text(l10n.translate('gcal_sync_title')),
      subtitle: Text(
        subtitle,
        style: isProblem ? TextStyle(color: theme.colorScheme.error) : null,
      ),
      value: sync.enabled,
      onChanged: sync.status == CalendarSyncStatus.syncing
          ? null
          // In a problem state, tapping reconnects or retries instead.
          : (on) => on || isProblem
                ? _enable(context, sync)
                : _disable(context, sync),
    );
  }

  Future<void> _enable(
    BuildContext context,
    GoogleCalendarSyncService sync,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await sync.enable();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.translate(ok ? 'gcal_connected' : 'gcal_not_connected'),
        ),
      ),
    );
  }

  Future<void> _disable(
    BuildContext context,
    GoogleCalendarSyncService sync,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final remove = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('gcal_remove_title')),
        content: Text(l10n.translate('gcal_remove_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.translate('gcal_keep')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.translate('gcal_remove')),
          ),
        ],
      ),
    );
    if (remove == null) return;
    await sync.disable(removeCalendar: remove);
  }
}
