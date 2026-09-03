import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/features/schedule/schedule_screen.dart';
import 'package:rocis_schedule/features/courses/course_list_screen.dart';
import 'package:rocis_schedule/features/assignments/assignment_list_screen.dart';
import 'package:rocis_schedule/features/profile/settings_screen.dart';

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
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.black12,
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onDestinationSelected,
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              selectedIcon: const Icon(Icons.calendar_today_rounded),
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
    );
  }
}
