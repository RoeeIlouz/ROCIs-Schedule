import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/add_course_screen.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/assignments/add_assignment_screen.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/auth/login_screen.dart';
import 'package:rocis_schedule/features/auth/register_screen.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/widgets/app_button.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Widget createTestableWidget(
  Widget child, {
  CourseProvider? courseProvider,
  AssignmentProvider? assignmentProvider,
  AuthService? authService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CourseProvider>.value(
        value: courseProvider ?? CourseProvider('test_guest'),
      ),
      ChangeNotifierProvider<AssignmentProvider>.value(
        value: assignmentProvider ?? AssignmentProvider('test_guest'),
      ),
      ChangeNotifierProvider<AuthService>.value(
        value: authService ?? AuthService(),
      ),
      ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
      Provider<FirestoreService>(create: (_) => FirestoreService()),
    ],
    child: MaterialApp(
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Form Validation & User Input Suite', () {
    testWidgets(
      'AddCourseScreen validates empty fields and requires course name',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestableWidget(const AddCourseScreen()));
        await tester.pumpAndSettle();

        final saveButton = find.byType(AppButton);
        expect(saveButton, findsOneWidget);
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Validation error should appear
        expect(find.text('This field is required'), findsWidgets);
      },
    );

    testWidgets(
      'AddAssignmentScreen displays form fields and dropdowns properly',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          createTestableWidget(const AddAssignmentScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsWidgets);
        expect(find.byType(ElevatedButton), findsWidgets);
      },
    );

    testWidgets('LoginScreen validates email and password input', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      expect(signInButton, findsOneWidget);
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      // Expect invalid email message
      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('RegisterScreen validates matching passwords', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestableWidget(const RegisterScreen()));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(3));

      await tester.enterText(textFields.at(0), 'student@university.edu');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.enterText(textFields.at(2), 'mismatch456');
      await tester.pumpAndSettle();

      final registerButton = find.widgetWithText(
        ElevatedButton,
        'Create Account',
      );
      expect(registerButton, findsOneWidget);
      await tester.ensureVisible(registerButton);
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
