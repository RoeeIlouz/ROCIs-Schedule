import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/widgets/command_palette_dialog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CommandPaletteDialog Tests', () {
    testWidgets('renders search input and action items', (tester) async {
      final themeProvider = ThemeProvider();
      final courseProvider = CourseProvider('test_guest');
      final assignmentProvider = AssignmentProvider('test_guest');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
            ChangeNotifierProvider<CourseProvider>.value(value: courseProvider),
            ChangeNotifierProvider<AssignmentProvider>.value(value: assignmentProvider),
          ],
          child: const MaterialApp(
            localizationsDelegates: [AppLocalizationsDelegate()],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CommandPaletteDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('ACTIONS'), findsOneWidget);
      expect(find.text('Add Event'), findsOneWidget);
      expect(find.text('Add Assignment'), findsOneWidget);
      expect(find.text('Add Course'), findsOneWidget);

      // Search filtering
      await tester.enterText(find.byType(TextField), 'assignment');
      await tester.pumpAndSettle();

      expect(find.text('Add Assignment'), findsOneWidget);
    });
  });
}
