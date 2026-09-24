import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

class SemesterDatesSheet extends StatelessWidget {
  const SemesterDatesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 580),
      builder: (_) => const SemesterDatesSheet(),
    );
  }

  String _getSemesterDisplayName(
    String id,
    String defaultName,
    AppLocalizations l10n,
  ) {
    switch (id) {
      case 'semester_1':
        return l10n.translate('first_semester');
      case 'semester_2':
        return l10n.translate('second_semester');
      case 'semester_summer':
        return l10n.translate('summer_semester');
      default:
        return defaultName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final courseProvider = context.watch<CourseProvider>();
    final semesters = courseProvider.semesters;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (sheetContext, scrollController) {
        return GlassContainer(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          tintColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.translate('semester_dates'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('select_dates'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: semesters.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final semester = semesters[index];
                    final displayName = _getSemesterDisplayName(
                      semester.id,
                      semester.name,
                      l10n,
                    );
                    return _buildSemesterCard(
                      context,
                      semester,
                      displayName,
                      l10n,
                      theme,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSemesterCard(
    BuildContext context,
    Semester semester,
    String displayName,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final dateFormat = DateFormat.yMMMd();
    final hasDates = semester.startDate != null || semester.endDate != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasDates
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (hasDates)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip: l10n.translate('clear_dates'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await context.read<CourseProvider>().updateSemester(
                      semester.copyWith(clearDates: true),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateButton(
                  context,
                  label: l10n.translate('start_date'),
                  date: semester.startDate,
                  dateFormat: dateFormat,
                  l10n: l10n,
                  theme: theme,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: semester.startDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365 * 2),
                      ),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 3),
                      ),
                    );
                    if (picked != null && context.mounted) {
                      HapticFeedback.selectionClick();
                      await context.read<CourseProvider>().updateSemester(
                        semester.copyWith(startDate: picked),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateButton(
                  context,
                  label: l10n.translate('end_date'),
                  date: semester.endDate,
                  dateFormat: dateFormat,
                  l10n: l10n,
                  theme: theme,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          semester.endDate ??
                          (semester.startDate?.add(const Duration(days: 90)) ??
                              DateTime.now()),
                      firstDate:
                          semester.startDate ??
                          DateTime.now().subtract(
                            const Duration(days: 365 * 2),
                          ),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365 * 3),
                      ),
                    );
                    if (picked != null && context.mounted) {
                      HapticFeedback.selectionClick();
                      await context.read<CourseProvider>().updateSemester(
                        semester.copyWith(endDate: picked),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required DateFormat dateFormat,
    required AppLocalizations l10n,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    final isSet = date != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSet
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSet
                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                : theme.dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: isSet
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isSet ? dateFormat.format(date) : l10n.translate('not_set'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSet ? FontWeight.w600 : FontWeight.normal,
                      color: isSet
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
