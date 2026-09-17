import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/theme/app_theme.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/widgets/main_navigation_wrapper.dart';
import 'package:rocis_schedule/shared/widgets/command_palette_dialog.dart';
import 'package:rocis_schedule/features/schedule/schedule_screen.dart';
import 'package:rocis_schedule/features/courses/course_list_screen.dart';
import 'package:rocis_schedule/features/assignments/assignment_list_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required Widget child,
    Locale locale = const Locale('en'),
    ThemeData? theme,
    CourseProvider? courseProvider,
    AssignmentProvider? assignmentProvider,
    ThemeProvider? themeProvider,
    AuthService? authService,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(
          value: themeProvider ?? ThemeProvider(),
        ),
        ChangeNotifierProvider<CourseProvider>.value(
          value: courseProvider ?? CourseProvider('test_uid'),
        ),
        ChangeNotifierProvider<AssignmentProvider>.value(
          value: assignmentProvider ?? AssignmentProvider('test_uid'),
        ),
        ChangeNotifierProvider<AuthService>.value(
          value: authService ?? AuthService(),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        theme: theme ?? AppTheme.lightTheme(null),
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }

  group('Production Readiness: Responsive UX / UI Layouts', () {
    testWidgets(
      'Desktop resolution (1200x800) renders desktop sidebar with quick action and search',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestApp(
            child: const MainNavigationWrapper(
              child: Scaffold(body: Text('Schedule Content')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Desktop layout should display the sidebar branding
        expect(find.text('ROCIs Schedule'), findsOneWidget);
        expect(find.text('Ctrl K'), findsOneWidget);
        expect(find.byType(PopupMenuButton<String>), findsOneWidget);

        // Mobile NavigationBar should NOT be present on desktop
        expect(find.byType(NavigationBar), findsNothing);
      },
    );

    testWidgets(
      'Mobile resolution (400x800) renders floating bottom NavigationBar with 4 tabs',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestApp(
            child: const MainNavigationWrapper(
              child: Scaffold(body: Text('Mobile Schedule Content')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Mobile navigation bar must be present with destinations
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationDestination), findsNWidgets(4));

        // Desktop sidebar specific elements should not be present
        expect(find.text('Ctrl K'), findsNothing);
      },
    );

    testWidgets(
      'Desktop resolution (1200x800) renders AssignmentListScreen with KPI stats and desktop toolbar without FAB',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestApp(child: const AssignmentListScreen()),
        );
        await tester.pumpAndSettle();

        // Desktop header and action button
        expect(find.text('Assignments'), findsOneWidget);
        expect(find.text('Add Assignment'), findsOneWidget);

        // KPI summary cards
        expect(find.text('Pending'), findsWidgets);
        expect(find.text('Due This Week'), findsOneWidget);
        expect(find.text('Overdue'), findsOneWidget);
        expect(find.text('Completed'), findsWidgets);

        // Floating Action Button should be absent on desktop
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );

    testWidgets(
      'Desktop resolution (1200x800) renders CourseListScreen with desktop header without FAB',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const CourseListScreen()));
        await tester.pumpAndSettle();

        // Empty state provides no courses message
        expect(find.text('No courses yet'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );

    testWidgets(
      'Desktop resolution (1200x800) renders ScheduleScreen with desktop toolbar without FAB',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(child: const ScheduleScreen()));
        await tester.pumpAndSettle();

        // Desktop header elements
        expect(find.text('Week'), findsOneWidget);
        expect(find.text('Add Event'), findsOneWidget);

        // Mobile FAB should be absent on desktop
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );
  });

  group('Production Readiness: RTL Multilingual Support', () {
    testWidgets(
      'Hebrew locale applies TextDirection.rtl and translates navigation',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestApp(
            locale: const Locale('he'),
            child: const MainNavigationWrapper(child: Scaffold()),
          ),
        );
        await tester.pumpAndSettle();

        final directionality = Directionality.of(
          tester.element(find.text('ROCIs Schedule')),
        );
        expect(directionality, TextDirection.rtl);

        // Verify Hebrew navigation translations
        expect(find.text('מערכת'), findsWidgets);
        expect(find.text('הקורסים שלי'), findsWidgets);
        expect(find.text('מטלות'), findsWidgets);
        expect(find.text('הגדרות'), findsWidgets);
      },
    );

    testWidgets(
      'Arabic locale applies TextDirection.rtl and translates navigation',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestApp(
            locale: const Locale('ar'),
            child: const MainNavigationWrapper(child: Scaffold()),
          ),
        );
        await tester.pumpAndSettle();

        final directionality = Directionality.of(
          tester.element(find.text('ROCIs Schedule')),
        );
        expect(directionality, TextDirection.rtl);

        // Verify Arabic navigation translations
        expect(find.text('الجدول الدراسي'), findsWidgets);
        expect(find.text('موادي الدراسية'), findsWidgets);
        expect(find.text('الإعدادات'), findsWidgets);
      },
    );
  });

  group('Production Readiness: Theme & Color Contrast Integrity', () {
    test('AMOLED Dark Mode uses pitch black #000000 background', () {
      final amoledTheme = AppTheme.darkTheme(null, isAmoled: true);
      expect(amoledTheme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(amoledTheme.colorScheme.surface, const Color(0xFF0A0C12));
    });

    test(
      'Non-AMOLED Dark Mode uses neutral zinc #121316 without blue tint',
      () {
        final darkTheme = AppTheme.darkTheme(null, isAmoled: false);
        expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF121316));
        expect(darkTheme.colorScheme.surface, const Color(0xFF1B1C21));
        expect(darkTheme.colorScheme.surfaceContainer, const Color(0xFF22242A));
      },
    );

    test('Switch thumb colors provide high contrast in both themes', () {
      final darkTheme = AppTheme.darkTheme(null);
      final lightTheme = AppTheme.lightTheme(null);

      final darkSwitchThumb = darkTheme.switchTheme.thumbColor?.resolve({});
      final lightSwitchThumb = lightTheme.switchTheme.thumbColor?.resolve({});

      expect(darkSwitchThumb, const Color(0xFFE2E8F0));
      expect(lightSwitchThumb, const Color(0xFF64748B));
    });
  });

  group('Production Readiness: Academic & Assignment Edge Cases', () {
    test(
      'CourseProvider handles perfect 100 GPA and 0.0 failing GPA correctly',
      () async {
        final provider = CourseProvider('test_uid');

        final perfectCourse = Course(
          id: 'c_perfect',
          name: 'Algorithms',
          code: 'CS201',
          instructor: 'Dr. Knuth',
          color: Colors.blue,
          credits: 4.0,
          grade: 100.0,
        );
        await provider.addCourseFromSync(perfectCourse);
        expect(provider.averageGrade, 100.0);
        expect(provider.calculatedGpa, 4.0);

        final failingCourse = Course(
          id: 'c_failing',
          name: 'Underperformed Course',
          code: 'BAD101',
          instructor: 'Dr. Harsh',
          color: Colors.red,
          credits: 4.0,
          grade: 45.0, // Below 60 -> 0.0 GPA
        );
        await provider.addCourseFromSync(failingCourse);
        // Average: (4*100 + 4*45) / 8 = 145 / 2 = 72.5
        expect(provider.averageGrade, 72.5);
        // 72.5 corresponds to 1.7 on 4.0 scale (70 <= grade < 73)
        expect(provider.calculatedGpa, 1.7);
      },
    );

    test(
      'Assignment priority sorting orders correctly: High -> Medium -> Low',
      () {
        final assignments = [
          Assignment(
            id: 'a1',
            courseId: 'c1',
            title: 'Low Priority Task',
            dueDate: DateTime.now().add(const Duration(days: 1)),
            priority: AssignmentPriority.low,
          ),
          Assignment(
            id: 'a2',
            courseId: 'c1',
            title: 'High Priority Task',
            dueDate: DateTime.now().add(const Duration(days: 2)),
            priority: AssignmentPriority.high,
          ),
          Assignment(
            id: 'a3',
            courseId: 'c1',
            title: 'Medium Priority Task',
            dueDate: DateTime.now().add(const Duration(days: 3)),
            priority: AssignmentPriority.medium,
          ),
        ];

        // Sort by priority index descending (high: 2, medium: 1, low: 0)
        assignments.sort(
          (a, b) => b.priority.index.compareTo(a.priority.index),
        );

        expect(assignments[0].title, 'High Priority Task');
        expect(assignments[1].title, 'Medium Priority Task');
        expect(assignments[2].title, 'Low Priority Task');
      },
    );

    testWidgets(
      'Command Palette safely handles search queries without matching items',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(child: const Scaffold(body: CommandPaletteDialog())),
        );
        await tester.pumpAndSettle();

        final searchInput = find.byType(TextField);
        expect(searchInput, findsOneWidget);

        // Search for non-existent keyword
        await tester.enterText(searchInput, 'XYZ_NON_EXISTENT_QUERY_999');
        await tester.pumpAndSettle();

        // Ensure no crash occurs and empty message renders gracefully
        expect(find.text('No matching commands or items'), findsOneWidget);
      },
    );
  });
}
