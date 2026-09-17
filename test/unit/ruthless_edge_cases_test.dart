import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/ics_import_service.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Ruthless ScheduleEvent Boundary & Edge Cases', () {
    test('ScheduleEvent.fromMap handles invalid date strings gracefully', () {
      final map = {
        'id': 'e_edge_1',
        'title': 'Corrupted Date Event',
        'courseId': 'c_1',
        'type': 0,
        'startTime': 'NOT_A_DATE_2026',
        'endTime': 'CORRUPTED_END_TIME',
        'location': 'Room 101',
        'daysOfWeek': '1,2',
        'recurring': 1,
        'notes': 'Testing invalid dates',
      };

      final event = ScheduleEvent.fromMap(map);
      expect(event.id, 'e_edge_1');
      expect(event.title, 'Corrupted Date Event');
      expect(event.startTime, isNotNull);
      expect(event.endTime, isNotNull);
      expect(
        event.endTime.isAfter(event.startTime) ||
            event.endTime.isAtSameMomentAs(event.startTime),
        isTrue,
      );
    });

    test('ScheduleEvent.fromMap handles leap years and century leap years', () {
      final leapMap = {
        'id': 'e_leap',
        'title': 'Leap Year Event',
        'courseId': 'c_leap',
        'startTime': '2024-02-29T12:00:00.000',
        'endTime': '2024-02-29T14:00:00.000',
      };
      final leapEvent = ScheduleEvent.fromMap(leapMap);
      expect(leapEvent.startTime.year, 2024);
      expect(leapEvent.startTime.month, 2);
      expect(leapEvent.startTime.day, 29);
      expect(leapEvent.duration.inHours, 2);

      final centuryLeapMap = {
        'id': 'e_century_leap',
        'title': 'Century Leap Year Event',
        'courseId': 'c_leap',
        'startTime': '2000-02-29T08:00:00.000',
        'endTime': '2000-02-29T09:30:00.000',
      };
      final centuryEvent = ScheduleEvent.fromMap(centuryLeapMap);
      expect(centuryEvent.startTime.year, 2000);
      expect(centuryEvent.startTime.month, 2);
      expect(centuryEvent.startTime.day, 29);
      expect(centuryEvent.duration.inMinutes, 90);
    });

    test('ScheduleEvent duration and negative duration detection', () {
      final now = DateTime(2026, 9, 1, 14, 0);
      final earlier = DateTime(2026, 9, 1, 12, 0);

      final normalEvent = ScheduleEvent(
        id: 'norm',
        title: 'Normal',
        courseId: 'c1',
        type: EventType.classType,
        startTime: earlier,
        endTime: now,
      );
      expect(normalEvent.duration, const Duration(hours: 2));
      expect(normalEvent.isNegativeDuration, isFalse);

      final negativeEvent = ScheduleEvent(
        id: 'neg',
        title: 'Negative Duration Event',
        courseId: 'c1',
        type: EventType.classType,
        startTime: now,
        endTime: earlier,
      );
      expect(negativeEvent.duration.isNegative, isTrue);
      expect(negativeEvent.isNegativeDuration, isTrue);
    });

    test(
      'ScheduleEvent recurring events across week transitions (Sunday & Saturday)',
      () {
        final now = DateTime(2026, 9, 1, 10, 0);
        final event = ScheduleEvent(
          id: 'e_weekend',
          title: 'Weekend Study',
          courseId: 'c1',
          type: EventType.study,
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          daysOfWeek: [0, 6], // Sunday and Saturday
          recurring: true,
        );

        expect(event.daysOfWeek, containsAll([0, 6]));
        expect(event.recurring, isTrue);
      },
    );

    test('ScheduleEvent with empty daysOfWeek parses and behaves safely', () {
      final map = {
        'id': 'e_empty_days',
        'title': 'No Days Event',
        'courseId': 'c1',
        'daysOfWeek': '',
        'recurring': 1,
      };

      final event = ScheduleEvent.fromMap(map);
      expect(event.daysOfWeek, isEmpty);
      expect(event.recurring, isTrue);
    });

    test(
      'ScheduleEvent.fromMap normalizes negative and out-of-range daysOfWeek',
      () {
        final map = {
          'id': 'e_bad_days',
          'title': 'Bad Days Event',
          'courseId': 'c1',
          'daysOfWeek': '-1,7,8,-8,0,3',
        };

        final event = ScheduleEvent.fromMap(map);
        // -1 normalized is 6, 7 normalized is 0, 8 normalized is 1, -8 normalized is 6, 0 is 0, 3 is 3
        for (final day in event.daysOfWeek) {
          expect(
            day >= 0 && day <= 6,
            isTrue,
            reason: 'Day $day is out of 0..6 range',
          );
        }
      },
    );

    test(
      'ScheduleEvent.fromMap handles string booleans and numbers for recurring',
      () {
        final mapTrue = {
          'id': '1',
          'title': 'T',
          'courseId': 'c',
          'recurring': 'true',
        };
        expect(ScheduleEvent.fromMap(mapTrue).recurring, isTrue);

        final mapOne = {
          'id': '2',
          'title': 'T',
          'courseId': 'c',
          'recurring': '1',
        };
        expect(ScheduleEvent.fromMap(mapOne).recurring, isTrue);

        final mapFalse = {
          'id': '3',
          'title': 'T',
          'courseId': 'c',
          'recurring': 'false',
        };
        expect(ScheduleEvent.fromMap(mapFalse).recurring, isFalse);

        final mapZero = {
          'id': '4',
          'title': 'T',
          'courseId': 'c',
          'recurring': 0,
        };
        expect(ScheduleEvent.fromMap(mapZero).recurring, isFalse);
      },
    );

    test('ScheduleEvent out-of-bounds type falls back to EventType.other', () {
      final mapHigh = {'id': '1', 'title': 'T', 'courseId': 'c', 'type': 99};
      expect(ScheduleEvent.fromMap(mapHigh).type, EventType.other);

      final mapNeg = {'id': '2', 'title': 'T', 'courseId': 'c', 'type': -1};
      expect(ScheduleEvent.fromMap(mapNeg).type, EventType.other);

      final mapStr = {
        'id': '3',
        'title': 'T',
        'courseId': 'c',
        'type': 'invalid',
      };
      expect(ScheduleEvent.fromMap(mapStr).type, EventType.classType);
    });
  });

  group('Course Model & GPA Calculation Resilience', () {
    test(
      'Course model handles 0.0 credits and decimal credits (1.5, 3.5, 0.25)',
      () {
        final zeroCredit = Course(
          id: 'c_zero',
          name: 'Orientation',
          code: 'OR101',
          instructor: 'Dean',
          color: Colors.grey,
          credits: 0.0,
        );
        expect(zeroCredit.credits, 0.0);

        final decimalCredit = Course(
          id: 'c_dec',
          name: 'Physics Lab',
          code: 'PHYS101L',
          instructor: 'Dr. Bohr',
          color: Colors.cyan,
          credits: 1.5,
          grade: 90.0,
        );
        expect(decimalCredit.credits, 1.5);
        expect(decimalCredit.grade, 90.0);

        final map = {
          'id': 'c_parsed',
          'name': 'Chemistry Seminar',
          'code': 'CHEM200',
          'instructor': 'Dr. Curie',
          'color': '4282663799',
          'credits': '3.5',
          'grade': '92.5',
        };
        final fromMap = Course.fromMap(map);
        expect(fromMap.credits, 3.5);
        expect(fromMap.grade, 92.5);
      },
    );

    test(
      'GPA calculation prevents division by zero with zero graded credits',
      () async {
        final provider = CourseProvider('test_uid');

        // Empty courses
        expect(provider.totalCredits, 0.0);
        expect(provider.averageGrade, isNull);
        expect(provider.calculatedGpa, isNull);

        // Add course with 0.0 credits and a grade
        final zeroCourse = Course(
          id: 'c0',
          name: 'Voluntary Seminar',
          code: 'VOL100',
          instructor: 'Dr. Zero',
          color: Colors.blue,
          credits: 0.0,
          grade: 98.0,
        );
        await provider.addCourseFromSync(zeroCourse);

        expect(provider.totalCredits, 0.0);
        // averageGrade must not be NaN or Infinity due to division by zero!
        expect(provider.averageGrade, isNull);
        expect(provider.calculatedGpa, isNull);
      },
    );

    test(
      'GPA calculation with decimal credits computes precise weighted average',
      () async {
        final provider = CourseProvider('test_uid');

        final courseA = Course(
          id: 'ca',
          name: 'Lecture',
          code: 'LEC1',
          instructor: 'Inst A',
          color: Colors.blue,
          credits: 3.5,
          grade: 92.0,
        );
        final courseB = Course(
          id: 'cb',
          name: 'Lab',
          code: 'LAB1',
          instructor: 'Inst B',
          color: Colors.green,
          credits: 1.5,
          grade: 80.0,
        );
        final courseC = Course(
          id: 'cc',
          name: 'Ungraded Workshop',
          code: 'WRK1',
          instructor: 'Inst C',
          color: Colors.orange,
          credits: 2.0,
          grade: null, // Null grade
        );

        await provider.addCourseFromSync(courseA);
        await provider.addCourseFromSync(courseB);
        await provider.addCourseFromSync(courseC);

        expect(provider.totalCredits, 7.0);

        // Weighted average: (3.5 * 92 + 1.5 * 80) / (3.5 + 1.5) = (322 + 120) / 5 = 442 / 5 = 88.4
        expect(provider.averageGrade, closeTo(88.4, 0.001));

        // GPA conversion for 88.4 (>= 87) is 3.3
        expect(provider.calculatedGpa, 3.3);
      },
    );

    test('GPA conversion boundary test across all scale thresholds', () async {
      final thresholds = [
        (95.0, 4.0),
        (93.0, 4.0),
        (91.0, 3.7),
        (90.0, 3.7),
        (88.0, 3.3),
        (87.0, 3.3),
        (84.0, 3.0),
        (83.0, 3.0),
        (81.0, 2.7),
        (80.0, 2.7),
        (78.0, 2.3),
        (77.0, 2.3),
        (74.0, 2.0),
        (73.0, 2.0),
        (71.0, 1.7),
        (70.0, 1.7),
        (65.0, 1.0),
        (60.0, 1.0),
        (55.0, 0.0),
        (3.8, 3.8), // Already on 4.0 scale
      ];

      for (final (grade, expectedGpa) in thresholds) {
        final provider = CourseProvider('test_uid');
        await provider.addCourseFromSync(
          Course(
            id: 'test_$grade',
            name: 'Test',
            code: 'TST',
            instructor: 'Prof',
            color: Colors.blue,
            credits: 3.0,
            grade: grade,
          ),
        );
        expect(
          provider.calculatedGpa,
          expectedGpa,
          reason: 'Grade $grade failed to match expected GPA $expectedGpa',
        );
      }
    });
  });

  group('ICS Importer Adversarial & Resilience Tests', () {
    test(
      'Empty and whitespace-only string returns empty result without throwing',
      () {
        final emptyResult = IcsImportService.parseIcsContent('');
        expect(emptyResult.courses, isEmpty);
        expect(emptyResult.events, isEmpty);

        final whitespaceResult = IcsImportService.parseIcsContent(
          "   \n\r\n\t   \n",
        );
        expect(whitespaceResult.courses, isEmpty);
        expect(whitespaceResult.events, isEmpty);
      },
    );

    test('Corrupted non-calendar text & SQL injection attempts do not throw', () {
      const attackPayload =
          "'; DROP TABLE courses; DROP TABLE events; -- <script>alert('xss')</script>";
      final result = IcsImportService.parseIcsContent(attackPayload);
      expect(result.courses, isEmpty);
      expect(result.events, isEmpty);
    });

    test('Unclosed VEVENT block without END:VEVENT is gracefully ignored', () {
      const unclosedIcs = """
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Dangling Event
DTSTART:20260901T090000
END:VCALENDAR
""";
      final result = IcsImportService.parseIcsContent(unclosedIcs);
      expect(result.events, isEmpty);
    });

    test('Missing SUMMARY causes event to be safely skipped', () {
      const missingSummaryIcs = """
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20260901T090000
DTEND:20260901T100000
END:VEVENT
END:VCALENDAR
""";
      final result = IcsImportService.parseIcsContent(missingSummaryIcs);
      expect(result.events, isEmpty);
    });

    test('Missing DTSTART causes event to be safely skipped', () {
      const missingDtstartIcs = """
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:No Start Time Event
DTEND:20260901T100000
END:VEVENT
END:VCALENDAR
""";
      final result = IcsImportService.parseIcsContent(missingDtstartIcs);
      expect(result.events, isEmpty);
    });

    test('Missing DTEND automatically defaults to startTime + 1 hour', () {
      const missingDtendIcs = """
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:CS101 Intro to CS
DTSTART:20260901T100000
END:VEVENT
END:VCALENDAR
""";
      final result = IcsImportService.parseIcsContent(missingDtendIcs);
      expect(result.events.length, 1);
      final event = result.events.first;
      expect(event.endTime, event.startTime.add(const Duration(hours: 1)));
      expect(event.duration, const Duration(hours: 1));
    });

    test(
      'Missing RRULE produces non-recurring event with empty daysOfWeek',
      () {
        const missingRruleIcs = """
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Single One-off Seminar
DTSTART:20260910T140000
DTEND:20260910T160000
END:VEVENT
END:VCALENDAR
""";
        final result = IcsImportService.parseIcsContent(missingRruleIcs);
        expect(result.events.length, 1);
        final event = result.events.first;
        expect(event.recurring, isFalse);
        expect(event.daysOfWeek, isEmpty);
      },
    );

    test('Malformed RRULE without BYDAY falls back to start weekday', () {
      const weeklyNoByDayIcs = """
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Weekly Meeting
DTSTART:20260902T100000
DTEND:20260902T110000
RRULE:FREQ=WEEKLY
END:VEVENT
END:VCALENDAR
""";
      final result = IcsImportService.parseIcsContent(weeklyNoByDayIcs);
      expect(result.events.length, 1);
      final event = result.events.first;
      expect(event.recurring, isTrue);
      // 2026-09-02 is Wednesday (weekday 3 % 7 = 3)
      expect(event.daysOfWeek, [3]);
    });

    test('Corrupted DTSTART string defaults safely without crash', () {
      const corruptDateIcs = """
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Corrupt Date Event
DTSTART:CORRUPT_NOT_A_DATE
DTEND:ALSO_CORRUPT
END:VEVENT
END:VCALENDAR
""";
      final result = IcsImportService.parseIcsContent(corruptDateIcs);
      expect(result.events.length, 1);
      final event = result.events.first;
      expect(event.startTime, isNotNull);
      expect(event.endTime, isNotNull);
    });

    test('Hebrew & Emoji in ICS data parses accurately', () {
      const hebrewIcs = """
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:מבוא למדעי המחשב 💻 - הרצאה
LOCATION:בניין טאוב, כיתה 2
DESCRIPTION:פרופ' ישראלי
DTSTART:20260901T083000
DTEND:20260901T103000
RRULE:FREQ=WEEKLY;BYDAY=SU,TU
END:VEVENT
END:VCALENDAR
""";
      final result = IcsImportService.parseIcsContent(hebrewIcs);
      expect(result.courses.length, 1);
      expect(result.courses.first.name, 'מבוא למדעי המחשב 💻');
      expect(result.courses.first.instructor, 'פרופ\' ישראלי');
      expect(result.events.length, 1);
      expect(result.events.first.location, 'בניין טאוב, כיתה 2');
      expect(result.events.first.daysOfWeek, containsAll([0, 2]));
    });

    test('Summary with delimiters produces valid course fallback keys', () {
      const dashOnlySummaryIcs = """
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:- Lecture
DTSTART:20260901T100000
DTEND:20260901T110000
END:VEVENT
END:VCALENDAR
""";
      final result = IcsImportService.parseIcsContent(dashOnlySummaryIcs);
      expect(result.courses.length, 1);
      expect(result.courses.first.name.isNotEmpty, isTrue);
      expect(result.courses.first.code.isNotEmpty, isTrue);
    });
  });

  group('Local DB Cache & Uninitialized State Resilience', () {
    test(
      'LocalDbService.clearCache is idempotent and safe to call repeatedly',
      () async {
        await expectLater(LocalDbService.clearCache(), completes);
        await expectLater(LocalDbService.clearCache(), completes);
        await expectLater(LocalDbService.clearCache(), completes);
      },
    );

    test('LocalDbService sanitizes malicious and unusual user IDs', () async {
      final maliciousUsers = [
        '../../etc/passwd',
        'user\\..\\path\\traversal',
        'user with spaces and symbols!@#\$%^&*()',
        '',
        'אלי_כהן_123',
      ];

      for (final userId in maliciousUsers) {
        final service = LocalDbService(userId);
        expect(service.userId, userId);
      }
    });

    test('CourseProvider clearLocalData cleans up memory safely', () async {
      final provider = CourseProvider('test_uid');
      await provider.addCourseFromSync(
        Course(
          id: 'c1',
          name: 'Test',
          code: 'T1',
          instructor: 'Dr. T',
          color: Colors.red,
          credits: 3.0,
        ),
      );
      expect(provider.courses.length, 1);

      await provider.clearLocalData();
      expect(provider.courses, isEmpty);
      expect(provider.events, isEmpty);
    });

    test(
      'CourseProvider getEventsByCourse with non-existent id returns empty list',
      () {
        final provider = CourseProvider('test_uid');
        expect(provider.getEventsByCourse('non_existent_course'), isEmpty);
      },
    );
  });

  group('Multilingual Localization Coverage & Parity', () {
    test('All keys in English exist in Hebrew without exception', () {
      final enMap = AppLocalizations.localizedValues['en']!;
      final heMap = AppLocalizations.localizedValues['he']!;

      final missingInHebrew = <String>[];
      for (final key in enMap.keys) {
        if (!heMap.containsKey(key)) {
          missingInHebrew.add(key);
        }
      }

      expect(
        missingInHebrew,
        isEmpty,
        reason:
            'The following keys are defined in "en" but missing in "he": $missingInHebrew',
      );
    });

    test('All keys in Hebrew exist in English without exception', () {
      final enMap = AppLocalizations.localizedValues['en']!;
      final heMap = AppLocalizations.localizedValues['he']!;

      final missingInEnglish = <String>[];
      for (final key in heMap.keys) {
        if (!enMap.containsKey(key)) {
          missingInEnglish.add(key);
        }
      }

      expect(
        missingInEnglish,
        isEmpty,
        reason:
            'The following keys are defined in "he" but missing in "en": $missingInEnglish',
      );
    });

    test(
      'No localized values are empty or whitespace only in English or Hebrew',
      () {
        final enMap = AppLocalizations.localizedValues['en']!;
        final heMap = AppLocalizations.localizedValues['he']!;

        for (final entry in enMap.entries) {
          expect(
            entry.value.trim().isNotEmpty,
            isTrue,
            reason: 'Key "${entry.key}" in "en" is empty',
          );
        }

        for (final entry in heMap.entries) {
          expect(
            entry.value.trim().isNotEmpty,
            isTrue,
            reason: 'Key "${entry.key}" in "he" is empty',
          );
        }
      },
    );

    test(
      'Every translation key called in the entire UI codebase exists in en and he',
      () {
        final libDir = Directory('lib');
        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.dart') &&
                  !f.path.contains('app_localizations.dart'),
            );

        final translateRegex = RegExp(
          r"translate\(\s*['"
          '"'
          r"]([a-zA-Z0-9_\-]+)['"
          '"'
          r"]\s*\)",
        );
        final discoveredKeys = <String>{};

        for (final file in dartFiles) {
          final content = file.readAsStringSync();
          for (final match in translateRegex.allMatches(content)) {
            final key = match.group(1);
            if (key != null) {
              discoveredKeys.add(key);
            }
          }
        }

        expect(
          discoveredKeys.isNotEmpty,
          isTrue,
          reason: 'Discovered keys from UI should not be empty',
        );

        final enMap = AppLocalizations.localizedValues['en']!;
        final heMap = AppLocalizations.localizedValues['he']!;

        final missingInEn = <String>[];
        final missingInHe = <String>[];

        for (final key in discoveredKeys) {
          if (!enMap.containsKey(key)) missingInEn.add(key);
          if (!heMap.containsKey(key)) missingInHe.add(key);
        }

        expect(
          missingInEn,
          isEmpty,
          reason: 'UI uses keys missing in "en": $missingInEn',
        );
        expect(
          missingInHe,
          isEmpty,
          reason: 'UI uses keys missing in "he": $missingInHe',
        );
      },
    );

    test('AppLocalizations falls back to key if key is completely unknown', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.translate('non_existent_key_xyz'), 'non_existent_key_xyz');
    });

    test(
      'AppLocalizations falls back to English when a supported language lacks a specific key',
      () {
        final l10nEs = AppLocalizations(const Locale('es'));
        expect(l10nEs.translate('app_title'), 'ROCIs Schedule');
      },
    );
  });
}
