import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';

class MainNavigationWrapper extends StatelessWidget {
  final Widget child;

  const MainNavigationWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final l10n = AppLocalizations.of(context)!;

    int currentIndex = 0;
    if (location.startsWith('/schedule')) currentIndex = 0;
    if (location.startsWith('/courses')) currentIndex = 1;
    if (location.startsWith('/assignments')) currentIndex = 2;
    if (location.startsWith('/friends')) currentIndex = 3;
    if (location.startsWith('/profile')) currentIndex = 4;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/schedule');
              break;
            case 1:
              context.go('/courses');
              break;
            case 2:
              context.go('/assignments');
              break;
            case 3:
              context.go('/friends');
              break;
            case 4:
              context.go('/profile');
              break;
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: l10n.translate('schedule'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school),
            label: l10n.translate('my_courses'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.assignment_outlined),
            selectedIcon: const Icon(Icons.assignment),
            label: l10n.translate('assignments'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: l10n.translate('friends'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.translate('profile'),
          ),
        ],
      ),
    );
  }
}
