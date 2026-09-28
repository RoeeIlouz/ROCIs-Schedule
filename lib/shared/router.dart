import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rocis_schedule/features/auth/login_screen.dart';
import 'package:rocis_schedule/features/auth/register_screen.dart';
import 'package:rocis_schedule/features/onboarding/onboarding_screen.dart';
import 'package:rocis_schedule/features/onboarding/profile_setup_screen.dart';
import 'package:rocis_schedule/features/courses/add_course_screen.dart';
import 'package:rocis_schedule/features/courses/screens/shared_course_link_screen.dart';
import 'package:rocis_schedule/features/schedule/add_event_screen.dart';
import 'package:rocis_schedule/features/assignments/add_assignment_screen.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/main_navigation_wrapper.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  // The web app uses hash URLs, so a https://schedule.rocisapps.com/share?…
  // link would start at the default; route it to the share screen explicitly.
  static String get _initialLocation => kIsWeb && Uri.base.path == '/share'
      ? '/share?${Uri.base.query}'
      : '/schedule';

  static final router = GoRouter(
    // The app opens straight into the schedule; signing in is optional and
    // only needed to sync across devices.
    initialLocation: _initialLocation,
    navigatorKey: _rootNavigatorKey,
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/schedule'),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        parentNavigatorKey: _rootNavigatorKey,
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
        path: '/schedule/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddEventScreen(),
      ),
      GoRoute(
        path: '/schedule/add-event',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            AddEventScreen(initialStart: state.extra as DateTime?),
      ),
      GoRoute(
        path: '/schedule/edit-event',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            AddEventScreen(eventToEdit: state.extra as ScheduleEvent?),
      ),
      GoRoute(
        path: '/assignments/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            AddAssignmentScreen(assignmentToEdit: state.extra as Assignment?),
      ),
      GoRoute(
        path: '/events/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddEventScreen(),
      ),
      GoRoute(
        path: '/courses/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            AddCourseScreen(courseToEdit: state.extra as Course?),
      ),
      GoRoute(
        path: '/courses/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            AddCourseScreen(courseToEdit: state.extra as Course?),
      ),
      GoRoute(
        path: '/share',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => SharedCourseLinkScreen(link: state.uri),
      ),
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileSetupScreen(isEditing: true),
      ),
    ],
  );
}
