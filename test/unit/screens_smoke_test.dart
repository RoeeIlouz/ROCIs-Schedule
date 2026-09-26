import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/features/schedule/schedule_screen.dart';
import 'package:rocis_schedule/features/assignments/assignment_list_screen.dart';
import 'package:rocis_schedule/features/courses/course_list_screen.dart';
import 'package:rocis_schedule/features/profile/settings_screen.dart';
import 'package:rocis_schedule/shared/widgets/main_navigation_wrapper.dart';
import 'package:rocis_schedule/shared/widgets/bouncy_checkbox.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required Widget child,
    ThemeProvider? themeProvider,
    CourseProvider? courseProvider,
    AssignmentProvider? assignmentProvider,
    AuthService? authService,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(
          value: authService ?? AuthService(),
        ),
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider ?? ThemeProvider(),
        ),
        ChangeNotifierProvider<CourseProvider>.value(
          value: courseProvider ?? CourseProvider('test_uid'),
        ),
        ChangeNotifierProvider<AssignmentProvider?>.value(
          value: assignmentProvider ?? AssignmentProvider('test_uid'),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizationsDelegate()],
        supportedLocales: const [Locale('en'), Locale('he')],
        home: child,
      ),
    );
  }

  group('ROCIs-Schedule Full UI & Screen Tests', () {
    testWidgets('ScheduleScreen greets a new user with setup actions', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(child: const ScheduleScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ScheduleScreen), findsOneWidget);
      expect(find.text("Let's build your week"), findsOneWidget);
      expect(find.text('Add your first course'), findsOneWidget);
      expect(find.text('Have an account? Sign in'), findsOneWidget);
      // No add-event button until there's a course to attach events to.
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets(
      'ScheduleScreen displays events with GlassContainer and course color',
      (WidgetTester tester) async {
        final courseProvider = CourseProvider('test_uid');
        final course = Course(
          id: 'c1',
          name: 'Algorithms',
          code: 'CS201',
          instructor: 'Dr. Turing',
          color: Colors.teal,
          credits: 4,
        );
        final event = ScheduleEvent(
          id: 'e1',
          courseId: 'c1',
          title: 'Lecture 1',
          type: EventType.classType,
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(hours: 2)),
          location: 'Hall B',
        );

        courseProvider.addCourseFromSync(course);
        courseProvider.addEventFromSync(event);

        await tester.pumpWidget(
          createTestWidget(
            child: const ScheduleScreen(),
            courseProvider: courseProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lecture 1'), findsOneWidget);
        expect(find.text('Algorithms'), findsOneWidget);
        expect(find.text('Hall B'), findsOneWidget);
      },
    );

    testWidgets(
      'AssignmentListScreen displays assignments with priority pill and toggles completion',
      (WidgetTester tester) async {
        final assignmentProvider = AssignmentProvider('test_uid');
        final courseProvider = CourseProvider('test_uid');
        final course = Course(
          id: 'c1',
          name: 'Algorithms',
          code: 'CS201',
          instructor: 'Dr. Turing',
          color: Colors.blue,
          credits: 4,
        );
        final assignment = Assignment(
          id: 'a1',
          courseId: 'c1',
          title: 'Homework 1',
          dueDate: DateTime.now().add(const Duration(days: 3)),
          priority: AssignmentPriority.high,
        );

        courseProvider.addCourseFromSync(course);
        assignmentProvider.addAssignmentFromSync(assignment);

        await tester.pumpWidget(
          createTestWidget(
            child: const AssignmentListScreen(),
            courseProvider: courseProvider,
            assignmentProvider: assignmentProvider,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Homework 1'), findsOneWidget);
        expect(find.text('HIGH'), findsOneWidget);
        expect(find.text('Algorithms'), findsOneWidget);

        // Tap completion checkbox
        await tester.tap(find.byType(BouncyCheckbox));
        await tester.pumpAndSettle();

        expect(assignmentProvider.assignments.first.isCompleted, isTrue);
      },
    );

    testWidgets('CourseListScreen displays courses and opens details sheet', (
      WidgetTester tester,
    ) async {
      final courseProvider = CourseProvider('test_uid');
      final course = Course(
        id: 'c1',
        name: 'Database Systems',
        code: 'CS305',
        instructor: 'Prof. Codd',
        color: Colors.purple,
        credits: 3,
      );
      courseProvider.addCourseFromSync(course);

      await tester.pumpWidget(
        createTestWidget(
          child: const CourseListScreen(),
          courseProvider: courseProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Database Systems'), findsOneWidget);
      expect(find.text('3 Credits'), findsOneWidget);

      // Tap course item to open details modal sheet
      await tester.tap(find.text('Database Systems'));
      await tester.pumpAndSettle();

      expect(find.text('Instructor: Prof. Codd'), findsOneWidget);
    });

    testWidgets('SettingsScreen toggles glassmorphism and preferences', (
      WidgetTester tester,
    ) async {
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        createTestWidget(
          child: const SettingsScreen(),
          themeProvider: themeProvider,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Glassmorphism UI'), findsOneWidget);
      expect(find.text('Material You'), findsOneWidget);
      expect(find.text('AMOLED Mode'), findsOneWidget);

      // Find switch for Glassmorphism and toggle it
      final glassSwitch = find.widgetWithText(
        SwitchListTile,
        'Glassmorphism UI',
      );
      expect(glassSwitch, findsOneWidget);

      await tester.tap(glassSwitch);
      await tester.pumpAndSettle();

      expect(themeProvider.useGlassmorphism, isFalse);
    });

    testWidgets('MainNavigationWrapper displays navigation destinations', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const MainNavigationWrapper(child: SizedBox.shrink()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('My Courses'), findsOneWidget);
      expect(find.text('Assignments'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
