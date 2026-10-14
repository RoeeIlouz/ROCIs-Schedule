import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/courses/services/gpa_simulator_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

Future<void> showGpaSimulatorSheet(
  BuildContext context, {
  String? semesterId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GpaSimulatorSheet(semesterId: semesterId),
  );
}

class GpaSimulatorSheet extends StatefulWidget {
  final String? semesterId;

  const GpaSimulatorSheet({super.key, this.semesterId});

  @override
  State<GpaSimulatorSheet> createState() => _GpaSimulatorSheetState();
}

class _GpaSimulatorSheetState extends State<GpaSimulatorSheet> {
  double _targetAverage = 85.0;
  final Map<String, double> _hypotheticalGrades = {};
  bool _useWhatIfMode = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CourseProvider>();
    final currentAvg = provider.getFilteredAverageGrade(widget.semesterId);
    if (currentAvg != null) {
      _targetAverage = (currentAvg + 3.0).clamp(60.0, 98.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<CourseProvider>();
    final courses = provider.getFilteredCourses(widget.semesterId);

    final pendingCourses = courses.where((c) => c.grade == null).toList();

    // Goal-seeking calculation
    final goalSeekResult = GpaSimulatorService.calculateTargetRequirement(
      courses: courses,
      targetAverage: _targetAverage,
    );

    // What-if calculation
    final whatIfResult = GpaSimulatorService.simulateHypotheticalGrades(
      courses: courses,
      hypotheticalGrades: _hypotheticalGrades,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121217) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_graph_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('gpa_simulator'),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        l10n.translate('target_gpa_desc'),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // Current Academic Standing
                GlassContainer(
                  borderRadius: BorderRadius.circular(18),
                  padding: const EdgeInsets.all(16),
                  tintColor: theme.colorScheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('current_standing'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStandingItem(
                              label: l10n.translate('total_credits'),
                              value:
                                  '${goalSeekResult.gradedCredits.toInt()} / ${goalSeekResult.totalCredits.toInt()}',
                              theme: theme,
                            ),
                          ),
                          Expanded(
                            child: _buildStandingItem(
                              label: l10n.translate('average_grade'),
                              value: goalSeekResult.currentAverage != null
                                  ? '${goalSeekResult.currentAverage!.toStringAsFixed(1)}%'
                                  : '--',
                              theme: theme,
                            ),
                          ),
                          Expanded(
                            child: _buildStandingItem(
                              label: l10n.translate('gpa'),
                              value: goalSeekResult.currentGpa != null
                                  ? goalSeekResult.currentGpa!.toStringAsFixed(2)
                                  : '--',
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tab Switcher: Goal Seeking vs What-If Simulator
                Row(
                  children: [
                    Expanded(
                      child: _buildModeTab(
                        title: l10n.translate('target_grade'),
                        isSelected: !_useWhatIfMode,
                        onTap: () => setState(() => _useWhatIfMode = false),
                        theme: theme,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeTab(
                        title: l10n.translate('what_if_simulator'),
                        isSelected: _useWhatIfMode,
                        onTap: () => setState(() => _useWhatIfMode = true),
                        theme: theme,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (!_useWhatIfMode) ...[
                  // Target GPA Goal Seeker Slider
                  GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.translate('target_grade'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_targetAverage.toStringAsFixed(1)}% (GPA ${GpaSimulatorService.gradeToGpa(_targetAverage).toStringAsFixed(1)})',
                                style: GoogleFonts.firaCode(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _targetAverage,
                          min: 60.0,
                          max: 100.0,
                          divisions: 80,
                          label: '${_targetAverage.toStringAsFixed(1)}%',
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setState(() => _targetAverage = val);
                          },
                        ),
                        const SizedBox(height: 12),

                        // Feasibility Banner
                        _buildFeasibilityCard(
                          result: goalSeekResult,
                          theme: theme,
                          l10n: l10n,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // What-If Per-Course Hypothetical Simulator
                  GlassContainer(
                    borderRadius: BorderRadius.circular(20),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.translate('simulated_gpa'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${whatIfResult.average.toStringAsFixed(1)}% (GPA ${whatIfResult.gpa.toStringAsFixed(2)})',
                                style: GoogleFonts.firaCode(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (pendingCourses.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'All courses in this semester have final grades!',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          ...pendingCourses.map((c) {
                            final score = _hypotheticalGrades[c.id] ?? 85.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: c.color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            c.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${c.credits.toInt()} cr',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${score.toInt()}%',
                                          style: GoogleFonts.firaCode(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Slider(
                                      value: score,
                                      min: 50.0,
                                      max: 100.0,
                                      divisions: 50,
                                      onChanged: (val) {
                                        setState(() {
                                          _hypotheticalGrades[c.id] = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingItem({
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.firaCode(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildModeTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildFeasibilityCard({
    required GpaSimulationResult result,
    required ThemeData theme,
    required AppLocalizations l10n,
  }) {
    final Color badgeColor;
    final IconData badgeIcon;
    final String badgeTitle;
    final String description;

    switch (result.feasibility) {
      case GpaFeasibility.secured:
        badgeColor = const Color(0xFF10B981);
        badgeIcon = Icons.check_circle_rounded;
        badgeTitle = l10n.translate('feasibility_secured');
        description =
            'Your accumulated points already secure your target! Any passing score (>60%) maintains your goal.';
        break;
      case GpaFeasibility.achievable:
        badgeColor = const Color(0xFF0EA5E9);
        badgeIcon = Icons.flag_rounded;
        badgeTitle = l10n.translate('feasibility_achievable');
        description =
            'You need an average of ${result.requiredRemainingAverage!.toStringAsFixed(1)}% across your remaining ${result.pendingCredits.toInt()} credits.';
        break;
      case GpaFeasibility.challenging:
        badgeColor = const Color(0xFFF59E0B);
        badgeIcon = Icons.bolt_rounded;
        badgeTitle = l10n.translate('feasibility_challenging');
        description =
            'High target: Requires ${result.requiredRemainingAverage!.toStringAsFixed(1)}% average across remaining courses. Aim for top exam scores.';
        break;
      case GpaFeasibility.unachievable:
        badgeColor = theme.colorScheme.error;
        badgeIcon = Icons.warning_amber_rounded;
        badgeTitle = l10n.translate('feasibility_unachievable');
        final maxPossible = GpaSimulatorService.simulateHypotheticalGrades(
          courses: context.read<CourseProvider>().getFilteredCourses(widget.semesterId),
          hypotheticalGrades: {
            for (final c in context.read<CourseProvider>().getFilteredCourses(widget.semesterId).where((c) => c.grade == null))
              c.id: 100.0,
          },
        ).average;
        description =
            'Even with 100% on all remaining courses, the maximum possible average is ${maxPossible.toStringAsFixed(1)}%.';
        break;
      case GpaFeasibility.noPendingCredits:
        badgeColor = theme.colorScheme.primary;
        badgeIcon = Icons.info_outline_rounded;
        badgeTitle = 'All Courses Graded';
        description = 'All courses in this view have already received final grades.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(badgeIcon, color: badgeColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badgeTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: badgeColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
