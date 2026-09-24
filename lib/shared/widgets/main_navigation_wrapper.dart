import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/features/schedule/schedule_screen.dart';
import 'package:rocis_schedule/features/courses/course_list_screen.dart';
import 'package:rocis_schedule/features/assignments/assignment_list_screen.dart';
import 'package:rocis_schedule/features/profile/settings_screen.dart';
import 'package:rocis_schedule/shared/widgets/glass_container.dart';
import 'package:rocis_schedule/shared/widgets/command_palette_dialog.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';

class MainNavigationWrapper extends StatefulWidget {
  final Widget child;
  final String initialRoute;

  const MainNavigationWrapper({
    super.key,
    required this.child,
    this.initialRoute = '/schedule',
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  late PageController _pageController;
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ScheduleScreen(),
    CourseListScreen(),
    AssignmentListScreen(),
    SettingsScreen(),
  ];

  final List<String> _routes = [
    '/schedule',
    '/courses',
    '/assignments',
    '/settings',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = _getIndexFromRoute(widget.initialRoute);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(MainNavigationWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    final location = GoRouterState.of(context).uri.toString();
    final newIndex = _getIndexFromRoute(location);
    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  int _getIndexFromRoute(String route) {
    if (route.startsWith('/schedule')) return 0;
    if (route.startsWith('/courses')) return 1;
    if (route.startsWith('/assignments')) return 2;
    if (route.startsWith('/settings')) return 3;
    return 0;
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
      context.go(_routes[index]);
    }
  }

  void _onDestinationSelected(int index) {
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _currentIndex = index);
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      context.go(_routes[index]);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getTodayEventsCount(CourseProvider courseProvider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = now.weekday % 7;
    return courseProvider.events.where((e) {
      if (e.recurring) {
        return e.daysOfWeek.contains(weekday);
      }
      return DateUtils.isSameDay(e.startTime, today);
    }).length;
  }

  int _getPendingAssignmentsCount(AssignmentProvider assignmentProvider) {
    return assignmentProvider.assignments.where((a) => !a.isCompleted).length;
  }

  void _showQuickAddMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_month_rounded),
                    title: Text(l10n.translate('add_event')),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/schedule/add-event');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.assignment_add),
                    title: Text(l10n.translate('add_assignment')),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/assignments/add');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.school_rounded),
                    title: Text(l10n.translate('add_course')),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push('/courses/add');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final authService = context.watch<AuthService>();
    final courseProvider = context.watch<CourseProvider>();
    final assignmentProvider = context.watch<AssignmentProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final todayEventsCount = _getTodayEventsCount(courseProvider);
    final pendingAssignmentsCount = _getPendingAssignmentsCount(
      assignmentProvider,
    );
    final totalCoursesCount = courseProvider.courses.length;

    final shortcutBindings = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
        CommandPaletteDialog.show(context);
      },
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
        CommandPaletteDialog.show(context);
      },
      const SingleActivator(LogicalKeyboardKey.digit1, control: true): () {
        _onDestinationSelected(0);
      },
      const SingleActivator(LogicalKeyboardKey.digit2, control: true): () {
        _onDestinationSelected(1);
      },
      const SingleActivator(LogicalKeyboardKey.digit3, control: true): () {
        _onDestinationSelected(2);
      },
      const SingleActivator(LogicalKeyboardKey.digit4, control: true): () {
        _onDestinationSelected(3);
      },
      const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () {
        _onDestinationSelected(0);
      },
      const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () {
        _onDestinationSelected(1);
      },
      const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () {
        _onDestinationSelected(2);
      },
      const SingleActivator(LogicalKeyboardKey.digit4, meta: true): () {
        _onDestinationSelected(3);
      },
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
        _showQuickAddMenu(context);
      },
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () {
        _showQuickAddMenu(context);
      },
    };

    return CallbackShortcuts(
      bindings: shortcutBindings,
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 850;

            if (isDesktop) {
              return Scaffold(
                body: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Desktop Navigation Sidebar
                    _buildDesktopSidebar(
                      context,
                      l10n,
                      theme,
                      authService,
                      themeProvider,
                      todayEventsCount: todayEventsCount,
                      totalCoursesCount: totalCoursesCount,
                      pendingAssignmentsCount: pendingAssignmentsCount,
                    ),

                    // Subtle Vertical Divider
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.25,
                      ),
                    ),

                    // Main Content Workspace
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: _onPageChanged,
                        children: _pages,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Mobile Navigation Layout (Floating Glass Bottom Bar)
            return Scaffold(
              extendBody: true,
              body: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: _pages,
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(24),
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: NavigationBar(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: _onDestinationSelected,
                        elevation: 0,
                        destinations: [
                          NavigationDestination(
                            icon: const Icon(Icons.calendar_today_outlined),
                            selectedIcon: const Icon(
                              Icons.calendar_today_rounded,
                            ),
                            label: l10n.translate('schedule'),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.school_outlined),
                            selectedIcon: const Icon(Icons.school_rounded),
                            label: l10n.translate('my_courses'),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.assignment_outlined),
                            selectedIcon: const Icon(Icons.assignment_rounded),
                            label: l10n.translate('assignments'),
                          ),
                          NavigationDestination(
                            icon: const Icon(Icons.settings_outlined),
                            selectedIcon: const Icon(Icons.settings_rounded),
                            label: l10n.translate('settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    AuthService authService,
    ThemeProvider themeProvider, {
    required int todayEventsCount,
    required int totalCoursesCount,
    required int pendingAssignmentsCount,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final isGuest = authService.isGuest;
    final userEmail = authService.user?.email;

    return Container(
      width: 260,
      color: isDark
          ? theme.colorScheme.surfaceContainerLowest
          : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Branding Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.school_rounded,
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
                        l10n.translate('app_title'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l10n.translate('academic_overview'),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Quick Create Action Button (Dropdown)
          PopupMenuButton<String>(
            tooltip: 'Quick Action',
            position: PopupMenuPosition.under,
            offset: const Offset(0, 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (action) {
              if (action == 'event') {
                context.push('/schedule/add-event');
              } else if (action == 'assignment') {
                context.push('/assignments/add');
              } else if (action == 'course') {
                context.push('/courses/add');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'event',
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(l10n.translate('add_event')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'assignment',
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_add,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(l10n.translate('add_assignment')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'course',
                child: Row(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(l10n.translate('add_course')),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.translate('add_event'),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Command Palette Search Trigger
          Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(12),
              onTap: () => CommandPaletteDialog.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.translate('filter_all'),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Ctrl K',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Text(
              l10n.translate('schedule').toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Nav Items
          _buildSidebarNavItem(
            index: 0,
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today_rounded,
            label: l10n.translate('schedule'),
            badgeCount: todayEventsCount,
          ),
          _buildSidebarNavItem(
            index: 1,
            icon: Icons.school_outlined,
            activeIcon: Icons.school_rounded,
            label: l10n.translate('my_courses'),
            badgeCount: totalCoursesCount,
          ),
          _buildSidebarNavItem(
            index: 2,
            icon: Icons.assignment_outlined,
            activeIcon: Icons.assignment_rounded,
            label: l10n.translate('assignments'),
            badgeCount: pendingAssignmentsCount,
          ),
          _buildSidebarNavItem(
            index: 3,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: l10n.translate('settings'),
          ),

          const Spacer(),

          // User Profile Footer Card
          Material(
            color: Colors.transparent,
            child: InkWell(
              mouseCursor: SystemMouseCursors.click,
              borderRadius: BorderRadius.circular(16),
              onTap: () => _onDestinationSelected(3),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.25,
                    ),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.2,
                      ),
                      child: Icon(
                        isGuest
                            ? Icons.person_outline_rounded
                            : Icons.person_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGuest
                                ? l10n.translate('guest_mode_title')
                                : (userEmail ?? l10n.translate('profile')),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isGuest
                                ? l10n.translate('cloud_sync')
                                : l10n.translate('active'),
                            style: TextStyle(
                              fontSize: 10,
                              color: isGuest
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
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
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int? badgeCount,
  }) {
    final theme = Theme.of(context);
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(12),
          onTap: () => _onDestinationSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.35)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
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
