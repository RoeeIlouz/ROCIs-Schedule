import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:rocis_schedule/features/courses/widgets/share_course_qr_sheet.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';

void main() {
  testWidgets('ShareCourseQrSheet renders course title, QR code, and event badge',
      (WidgetTester tester) async {
    final course = Course(
      id: 'test-course-id',
      name: 'Linear Algebra',
      code: 'MATH202',
      instructor: 'Prof. Gauss',
      color: const Color(0xFF2563EB),
      credits: 3.0,
    );

    final events = [
      ScheduleEvent(
        id: 'test-ev-1',
        title: 'Linear Algebra Lecture',
        courseId: 'test-course-id',
        type: EventType.classType,
        startTime: DateTime(2026, 10, 1, 9, 0),
        endTime: DateTime(2026, 10, 1, 10, 30),
        daysOfWeek: [1, 3],
        recurring: true,
      ),
    ];

    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ShareCourseQrSheet(
              course: course,
              events: events,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify course name is shown
    expect(find.textContaining('Linear Algebra'), findsWidgets);
    // Verify QrImageView is present
    expect(find.byType(QrImageView), findsOneWidget);
    // Verify event count is present
    expect(find.textContaining('1'), findsWidgets);
    // Verify copy button is present
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });
}
