import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/courses/services/course_share_service.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/theme/theme_provider.dart';
import 'package:rocis_schedule/shared/widgets/color_swatch_picker.dart';

const _teal = Color(0xFF14B8A6);
const _red = Color(0xFFEF4444);

Course _course({Color color = _teal}) => Course(
  id: 'c1',
  name: 'Algorithms',
  code: 'CS201',
  instructor: '',
  color: color,
  credits: 3,
);

ScheduleEvent _event({
  String id = 'e1',
  Color? color,
  EventDomain domain = EventDomain.academic,
}) => ScheduleEvent(
  id: id,
  title: id,
  courseId: domain == EventDomain.academic ? 'c1' : '',
  type: EventType.classType,
  startTime: DateTime(2026, 10, 4, 9),
  endTime: DateTime(2026, 10, 4, 10),
  domain: domain,
  color: color,
);

void main() {
  group('Event color', () {
    test('school events follow the course unless they have their own', () {
      expect(_event().colorFor(_course()), _teal);
      expect(_event(color: _red).colorFor(_course()), _red);
      expect(_event().colorFor(null), isNull);
    });

    test('work and personal events fall back to their category', () {
      final work = _event(domain: EventDomain.work);
      expect(work.colorFor(null), EventDomain.work.defaultColor);
      expect(
        _event(domain: EventDomain.personal, color: _red).colorFor(null),
        _red,
      );
    });

    test(
      'recoloring a course frees stored copies, keeps real choices',
      () async {
        final provider = CourseProvider('test_colors');
        await provider.applyRemoteCourses([_course()], const []);
        await provider.applyRemoteEvents([
          _event(id: 'copy', color: _teal), // old shared-import copy
          _event(id: 'own', color: _red),
          _event(id: 'plain'),
        ], const []);

        await provider.updateCourse(_course(color: Colors.orange));

        Color? colorOf(String id) =>
            provider.events.firstWhere((e) => e.id == id).color;
        expect(colorOf('copy'), isNull);
        expect(colorOf('own'), _red);
        expect(colorOf('plain'), isNull);
      },
    );

    test(
      'shared courses keep only colors that differ from the course',
      () async {
        final service = CourseShareService();
        final payload = service.generateOfflinePayload(_course(), [
          _event(id: 'copy', color: _teal),
          _event(id: 'own', color: _red),
        ]);
        final shared = await service.resolveQrString(payload);
        expect(shared.course.color.toARGB32(), _teal.toARGB32());
        final byTitle = {for (final e in shared.events) e.title: e.color};
        expect(byTitle['copy'], isNull);
        expect(byTitle['own']?.toARGB32(), _red.toARGB32());
      },
    );
  });

  group('Color swatches', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            localizationsDelegates: const [AppLocalizationsDelegate()],
            supportedLocales: const [Locale('en')],
            home: Scaffold(body: Center(child: child)),
          ),
        ),
      );
      await tester.pumpAndSettle(); // translations load asynchronously
    }

    testWidgets('the course swatch reports null, presets their color', (
      tester,
    ) async {
      Color? picked = _red;
      await pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => ColorSwatchPicker(
            presets: const [_red],
            selected: picked,
            autoColor: _teal,
            autoLabel: 'Course color',
            sheetTitle: 'Event color',
            onChanged: (c) => setState(() => picked = c),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Course color'));
      await tester.pump();
      expect(picked, isNull);
      await tester.tap(find.byTooltip('Color'));
      await tester.pump();
      expect(picked, _red);
    });

    testWidgets('"More colors" opens the full picker', (tester) async {
      await pump(
        tester,
        ColorSwatchPicker(
          presets: const [_red],
          selected: _red,
          sheetTitle: 'Course Color',
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.byTooltip('More colors'));
      await tester.pumpAndSettle();
      expect(find.text('#EF4444'), findsOneWidget);
      expect(find.text('Course Color'), findsWidgets);
    });
  });
}
