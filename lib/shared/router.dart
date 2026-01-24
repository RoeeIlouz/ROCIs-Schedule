import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rocis_schedule/features/auth/login_screen.dart';
import 'package:rocis_schedule/features/onboarding/onboarding_screen.dart';
import 'package:rocis_schedule/features/onboarding/profile_setup_screen.dart';
import 'package:rocis_schedule/features/courses/add_course_screen.dart';
import 'package:rocis_schedule/features/schedule/add_event_screen.dart';
import 'package:rocis_schedule/features/friends/schedule_comparison_screen.dart';
import 'package:rocis_schedule/features/assignments/add_assignment_screen.dart';
import 'package:rocis_schedule/shared/widgets/main_navigation_wrapper.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainNavigationWrapper(
          initialRoute: state.uri.toString(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/schedule',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/courses',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/friends',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/assignments',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
      // Routes that should not be part of the swipeable navigation
      GoRoute(
        path: '/assignments/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddAssignmentScreen(),
      ),
      GoRoute(
        path: '/friends/compare',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ScheduleComparisonScreen(
            myEvents: extra['myEvents'],
            friendEvents: extra['friendEvents'],
            friendName: extra['friendName'],
          );
        },
      ),
      GoRoute(
        path: '/events/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddEventScreen(),
      ),
      GoRoute(
        path: '/courses/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddCourseScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileSetupScreen(isEditing: true),
      ),
    ],
  );
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
