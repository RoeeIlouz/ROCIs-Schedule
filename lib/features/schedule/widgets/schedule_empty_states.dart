import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:rocis_schedule/shared/widgets/ics_import_dialog.dart';

/// First-run state: no courses and no events yet. This is the first screen a
/// new user sees, so it leads with setting up their week; signing in is an
/// optional footnote for guests.
class ScheduleWelcome extends StatelessWidget {
  final double bottomPadding;

  const ScheduleWelcome({super.key, this.bottomPadding = 0});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isGuest = context.watch<AuthService>().isGuest;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: 32,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.translate('welcome_title'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.translate('welcome_subtitle'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/courses/add'),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.translate('add_your_first_course')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => showIcsImportDialog(context),
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(l10n.translate('import_timetable')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (isGuest) ...[
                  const SizedBox(height: 16),
                  Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => context.push('/login'),
                    icon: const Icon(Icons.sync_rounded, size: 20),
                    label: Text(l10n.translate('have_account_sign_in')),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  Text(
                    l10n.translate('guest_data_stays'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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

/// Nothing on the selected day: points at the next thing on the calendar
/// instead of a dead end.
class FreeDayState extends StatelessWidget {
  final ScheduleEvent? nextEvent;
  final DateTime? nextDate;
  final Course? nextCourse;
  final ValueChanged<DateTime> onJumpTo;
  final bool filtersActive;
  final VoidCallback onClearFilters;

  const FreeDayState({
    super.key,
    required this.nextEvent,
    required this.nextDate,
    required this.nextCourse,
    required this.onJumpTo,
    required this.filtersActive,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final next = nextEvent;
    final date = nextDate;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtersActive
                  ? Icons.filter_list_off_rounded
                  : (next == null
                        ? Icons.event_busy_outlined
                        : Icons.wb_sunny_rounded),
              size: 48,
              color: scheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.translate(filtersActive ? 'no_matching_events' : 'free_day'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            if (filtersActive)
              TextButton(
                onPressed: onClearFilters,
                child: Text(l10n.translate('clear_filters')),
              )
            else if (next != null && date != null)
              ActionChip(
                avatar: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: nextCourse?.color ?? scheme.primary,
                ),
                label: Text(
                  l10n
                      .translate('next_up')
                      .replaceAll('{title}', next.title)
                      .replaceAll('{when}', DateFormat.MMMEd().format(date)),
                ),
                onPressed: () => onJumpTo(date),
              )
            else
              Text(
                l10n.translate('no_events'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
