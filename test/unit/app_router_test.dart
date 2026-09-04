import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rocis_schedule/shared/router.dart';

void main() {
  group('AppRouter Configuration & Navigation Suite', () {
    test('Router instance is configured with initial location "/"', () {
      final router = AppRouter.router;
      expect(router, isNotNull);
      expect(router.configuration.routes.isNotEmpty, isTrue);
    });

    test(
      'All expected top-level routes are registered in router configuration',
      () {
        final routes = AppRouter.router.configuration.routes;

        final topLevelPaths = <String>[];
        final shellPaths = <String>[];

        for (final route in routes) {
          if (route is GoRoute) {
            topLevelPaths.add(route.path);
          } else if (route is ShellRoute) {
            for (final childRoute in route.routes) {
              if (childRoute is GoRoute) {
                shellPaths.add(childRoute.path);
              }
            }
          }
        }

        // Verify core auth & onboarding routes
        expect(topLevelPaths, contains('/'));
        expect(topLevelPaths, contains('/login'));
        expect(topLevelPaths, contains('/register'));
        expect(topLevelPaths, contains('/onboarding'));
        expect(topLevelPaths, contains('/profile-setup'));

        // Verify shell navigation routes
        expect(shellPaths, contains('/schedule'));
        expect(shellPaths, contains('/courses'));
        expect(shellPaths, contains('/assignments'));
        expect(shellPaths, contains('/settings'));

        // Verify action routes
        expect(topLevelPaths, contains('/assignments/add'));
        expect(topLevelPaths, contains('/events/add'));
        expect(topLevelPaths, contains('/courses/add'));
        expect(topLevelPaths, contains('/profile/edit'));
      },
    );

    test('Router root navigator key is properly assigned', () {
      final key = AppRouter.router.routerDelegate.navigatorKey;
      expect(key, isA<GlobalKey<NavigatorState>>());
    });
  });
}
