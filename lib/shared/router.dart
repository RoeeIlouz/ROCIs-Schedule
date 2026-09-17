import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/auth/login_screen.dart';
import 'package:rocis_schedule/features/auth/register_screen.dart';
import 'package:rocis_schedule/features/onboarding/onboarding_screen.dart';
import 'package:rocis_schedule/features/onboarding/profile_setup_screen.dart';
import 'package:rocis_schedule/features/courses/add_course_screen.dart';
import 'package:rocis_schedule/features/schedule/add_event_screen.dart';
import 'package:rocis_schedule/features/assignments/add_assignment_screen.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/widgets/main_navigation_wrapper.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  void _checkSession() {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    if (auth.hasActiveSession) {
      context.go('/schedule');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AuthGate()),
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
        path: '/profile/edit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileSetupScreen(isEditing: true),
      ),
    ],
  );
}
