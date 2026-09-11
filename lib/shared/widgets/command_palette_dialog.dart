import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';

class CommandPaletteItem {
  final String id;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final String? shortcut;
  final String section;
  final VoidCallback onSelect;

  const CommandPaletteItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.shortcut,
    required this.section,
    required this.onSelect,
  });
}

class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => const CommandPaletteDialog(),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _selectedIndex = 0;
    });
  }

  List<CommandPaletteItem> _buildItems(
    BuildContext context,
    CourseProvider courseProvider,
    AssignmentProvider assignmentProvider,
    ThemeProvider themeProvider,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final items = <CommandPaletteItem>[];

    final courses = {for (var c in courseProvider.courses) c.id: c};

    // 1. Navigation & Quick Actions
    final actions = <CommandPaletteItem>[
      CommandPaletteItem(
        id: 'action_add_event',
        title: l10n.translate('add_event'),
        subtitle: 'Schedule a new lecture, exam, or lab',
        icon: Icons.add_circle_outline_rounded,
        iconColor: theme.colorScheme.primary,
        shortcut: 'E',
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          context.push('/schedule/add');
        },
      ),
      CommandPaletteItem(
        id: 'action_add_assignment',
        title: l10n.translate('add_assignment'),
        subtitle: 'Track upcoming homework or project',
        icon: Icons.assignment_add,
        iconColor: const Color(0xFF10B981),
        shortcut: 'A',
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          context.push('/assignments/add');
        },
      ),
      CommandPaletteItem(
        id: 'action_add_course',
        title: l10n.translate('add_course'),
        subtitle: 'Add a new academic course with credits',
        icon: Icons.school_outlined,
        iconColor: const Color(0xFFF59E0B),
        shortcut: 'C',
        section: 'Actions',
        onSelect: () {
          Navigator.of(context).pop();
          context.push('/courses/add');
        },
      ),
      CommandPaletteItem(
        id: 'nav_schedule',
        title: l10n.translate('schedule'),
        subtitle: 'View your weekly timetable & countdowns',
        icon: Icons.calendar_today_rounded,
        shortcut: '1',
        section: 'Navigation',
        onSelect: () {
          Navigator.of(context).pop();
          context.go('/schedule');
        },
      ),
      CommandPaletteItem(
        id: 'nav_courses',
        title: l10n.translate('my_courses'),
        subtitle: 'View enrolled courses & GPA simulator',
        icon: Icons.school_rounded,
        shortcut: '2',
        section: 'Navigation',
        onSelect: () {
          Navigator.of(context).pop();
          context.go('/courses');
        },
      ),
      CommandPaletteItem(
        id: 'nav_assignments',
        title: l10n.translate('assignments'),
        subtitle: 'Review pending and completed tasks',
        icon: Icons.assignment_rounded,
        shortcut: '3',
        section: 'Navigation',
        onSelect: () {
          Navigator.of(context).pop();
          context.go('/assignments');
        },
      ),
      CommandPaletteItem(
        id: 'nav_settings',
        title: l10n.translate('settings'),
        subtitle: 'Configure themes, AMOLED, and reminders',
        icon: Icons.settings_rounded,
        shortcut: '4',
        section: 'Navigation',
        onSelect: () {
          Navigator.of(context).pop();
          context.go('/settings');
        },
      ),
      CommandPaletteItem(
        id: 'toggle_amoled',
        title: 'Toggle AMOLED Pitch-Black Mode',
        subtitle: themeProvider.isAmoled ? 'Disable pure black' : 'Enable pure black #000000',
        icon: Icons.brightness_2_rounded,
        iconColor: const Color(0xFF6366F1),
        section: 'Preferences',
        onSelect: () {
          themeProvider.setIsAmoled(!themeProvider.isAmoled);
          Navigator.of(context).pop();
        },
      ),
      CommandPaletteItem(
        id: 'toggle_glass',
        title: 'Toggle Glassmorphism',
        subtitle: themeProvider.useGlassmorphism ? 'Turn off frosted glass' : 'Turn on frosted glass',
        icon: Icons.auto_awesome_rounded,
        iconColor: const Color(0xFF0EA5E9),
        section: 'Preferences',
        onSelect: () {
          themeProvider.setUseGlassmorphism(!themeProvider.useGlassmorphism);
          Navigator.of(context).pop();
        },
      ),
    ];

    for (final a in actions) {
      if (query.isEmpty ||
          a.title.toLowerCase().contains(query) ||
          (a.subtitle?.toLowerCase().contains(query) ?? false)) {
        items.add(a);
      }
    }

    // 2. Schedule Events
    for (final event in courseProvider.events) {
      final course = courses[event.courseId];
      final eventTitle = event.title.toLowerCase();
      final courseName = course?.name.toLowerCase() ?? '';
      final location = event.location.toLowerCase();

      if (query.isNotEmpty &&
          !eventTitle.contains(query) &&
          !courseName.contains(query) &&
          !location.contains(query)) {
        continue;
      }

      final timeStr = DateFormat.Hm().format(event.startTime);
      items.add(
        CommandPaletteItem(
          id: 'event_${event.id}',
          title: event.title,
          subtitle: '${course?.name ?? 'Event'} • $timeStr ${event.location.isNotEmpty ? '• ${event.location}' : ''}',
          icon: event.type == EventType.exam
              ? Icons.assignment_late_rounded
              : Icons.event_rounded,
          iconColor: course?.color ?? theme.colorScheme.primary,
          section: 'Events',
          onSelect: () {
            Navigator.of(context).pop();
            context.go('/schedule');
          },
        ),
      );
    }

    // 3. Assignments
    for (final assignment in assignmentProvider.assignments) {
      final course = courses[assignment.courseId];
      final title = assignment.title.toLowerCase();
      final courseName = course?.name.toLowerCase() ?? '';

      if (query.isNotEmpty && !title.contains(query) && !courseName.contains(query)) {
        continue;
      }

      final dueStr = DateFormat.MMMd().format(assignment.dueDate);
      items.add(
        CommandPaletteItem(
          id: 'assign_${assignment.id}',
          title: assignment.title,
          subtitle: '${course?.name ?? 'Assignment'} • Due $dueStr',
          icon: assignment.isCompleted
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          iconColor: assignment.isCompleted
              ? const Color(0xFF10B981)
              : (course?.color ?? theme.colorScheme.primary),
          section: 'Assignments',
          onSelect: () {
            Navigator.of(context).pop();
            context.go('/assignments');
          },
        ),
      );
    }

    // 4. Courses
    for (final course in courseProvider.courses) {
      final name = course.name.toLowerCase();
      final code = course.code.toLowerCase();
      final instructor = course.instructor.toLowerCase();

      if (query.isNotEmpty &&
          !name.contains(query) &&
          !code.contains(query) &&
          !instructor.contains(query)) {
        continue;
      }

      items.add(
        CommandPaletteItem(
          id: 'course_${course.id}',
          title: course.name,
          subtitle: '${course.code} • ${course.credits} credits ${course.instructor.isNotEmpty ? '• ${course.instructor}' : ''}',
          icon: Icons.school_rounded,
          iconColor: course.color,
          section: 'Courses',
          onSelect: () {
            Navigator.of(context).pop();
            context.go('/courses');
          },
        ),
      );
    }

    return items;
  }

  void _handleKeyEvent(KeyEvent event, List<CommandPaletteItem> items) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (items.isEmpty) return;
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % items.length;
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (items.isEmpty) return;
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + items.length) % items.length;
      });
      _scrollToSelected();
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (items.isNotEmpty && _selectedIndex < items.length) {
        items[_selectedIndex].onSelect();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    const itemHeight = 56.0;
    final targetOffset = (_selectedIndex * itemHeight) - 100;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final courseProvider = context.watch<CourseProvider>();
    final assignmentProvider = context.watch<AssignmentProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final items = _buildItems(
      context,
      courseProvider,
      assignmentProvider,
      themeProvider,
      l10n,
      theme,
    );

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (e) => _handleKeyEvent(e, items),
      child: Center(
        child: Container(
          width: 580,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: GlassContainer(
            borderRadius: BorderRadius.circular(24),
            padding: EdgeInsets.zero,
            elevation: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header / Input Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _inputFocusNode,
                          autofocus: true,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type a command, event, course, or assignment...',
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchController.clear(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ESC',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),

                // Results list
                Flexible(
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: theme.disabledColor,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No matching commands or items',
                                style: TextStyle(
                                  color: theme.disabledColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final isSelected = index == _selectedIndex;

                            // Show section header if first item of section
                            final showSection = index == 0 ||
                                items[index - 1].section != item.section;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showSection)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                                    child: Text(
                                      item.section.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: theme.colorScheme.primary.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isSelected
                                        ? Border.all(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      dense: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      onTap: item.onSelect,
                                      leading: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: (item.iconColor ?? theme.colorScheme.primary)
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          item.icon,
                                          size: 18,
                                          color: item.iconColor ?? theme.colorScheme.primary,
                                        ),
                                      ),
                                      title: Text(
                                        item.title,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: item.subtitle != null
                                          ? Text(
                                              item.subtitle!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : null,
                                      trailing: item.shortcut != null
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                item.shortcut!,
                                                style: GoogleFonts.firaCode(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                // Footer
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        'Navigate with ↑↓, select with ↵',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'ROCIs Schedule',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
