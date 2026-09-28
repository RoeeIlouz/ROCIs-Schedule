import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/courses/services/course_share_service.dart';
import 'package:rocis_schedule/features/courses/widgets/import_course_preview_sheet.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';

void main() {
  testWidgets(
      'ImportCoursePreviewSheet renders course details, scheduled event, and import button',
      (WidgetTester tester) async {
    final shareData = CourseShareData(
      course: Course(
        id: 'new-course-id',
        name: 'Operating Systems',
        code: 'CS301',
        instructor: 'Dr. Linus',
        color: const Color(0xFF0284C7),
        credits: 4.0,
      ),
      events: [
        ScheduleEvent(
          id: 'ev-1',
          title: 'OS Lecture',
          courseId: 'new-course-id',
          type: EventType.classType,
          startTime: DateTime(2026, 10, 1, 12, 0),
          endTime: DateTime(2026, 10, 1, 14, 0),
          location: 'Auditorium 3',
          daysOfWeek: [2],
          recurring: true,
        ),
      ],
      isCloud: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(),
          ),
          ChangeNotifierProvider<CourseProvider>(
            create: (_) => CourseProvider('test_user'),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ImportCoursePreviewSheet(shareData: shareData),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify course name is rendered
    expect(find.text('Operating Systems'), findsOneWidget);
    // Verify instructor is rendered
    expect(find.text('Dr. Linus'), findsOneWidget);
    // Verify event title is rendered
    expect(find.text('OS Lecture'), findsOneWidget);
    // Verify auditorium is rendered
    expect(find.text('Auditorium 3'), findsOneWidget);
    // Verify import button is present
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
