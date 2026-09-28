import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/courses/services/course_share_service.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';

void main() {
  late CourseShareService service;

  setUp(() {
    service = CourseShareService();
  });

  group('CourseShareService - Offline Direct Encoding & Decoding', () {
    test('encodes and decodes course and linked events accurately', () {
      final course = Course(
        id: 'course-123',
        name: 'Data Structures & Algorithms',
        code: 'CS201',
        instructor: 'Dr. Turing',
        color: const Color(0xFF2563EB),
        credits: 4.0,
        grade: 95.0,
        semester: 'semester_1',
      );

      final events = [
        ScheduleEvent(
          id: 'ev-1',
          title: 'CS201 Lecture',
          courseId: 'course-123',
          type: EventType.classType,
          startTime: DateTime(2026, 10, 1, 10, 0),
          endTime: DateTime(2026, 10, 1, 11, 30),
          location: 'Hall B',
          daysOfWeek: [1, 3], // Mon, Wed
          recurring: true,
          notes: 'Bring laptop',
          domain: EventDomain.academic,
          color: const Color(0xFF2563EB),
        ),
        ScheduleEvent(
          id: 'ev-2',
          title: 'CS201 Lab',
          courseId: 'course-123',
          type: EventType.lab,
          startTime: DateTime(2026, 10, 2, 14, 0),
          endTime: DateTime(2026, 10, 2, 16, 0),
          location: 'Lab 4',
          daysOfWeek: [4], // Thu
          recurring: true,
          notes: 'Lab exercises',
          domain: EventDomain.academic,
          color: const Color(0xFF2563EB),
        ),
      ];

      final payload = service.generateOfflinePayload(course, events);

      expect(payload.startsWith('${CourseShareService.linkBase}?d='), isTrue);
      expect(payload, contains('?d='));

      final decoded = service.decodeOfflinePayload(payload);
      expect(decoded, isNotNull);
      expect(decoded!['n'], equals('Data Structures & Algorithms'));
      expect(decoded['c'], equals('CS201'));
      expect(decoded['ins'], equals('Dr. Turing'));
      expect(decoded['cr'], equals(4.0));
      expect(decoded['ev'], isA<List>());
      expect((decoded['ev'] as List).length, equals(2));
    });

    test(
      'resolves https links, router-relative links and legacy QR codes',
      () async {
        final course = Course(
          id: 'c',
          name: 'Physics',
          code: 'PHY1',
          instructor: '',
          color: const Color(0xFF2563EB),
          credits: 3,
        );
        final link = service.generateOfflinePayload(course, const []);
        final query = Uri.parse(link).query;

        for (final raw in [
          link,
          '/share?$query', // what the /share route receives as state.uri
          'rocis://schedule/course?$query', // QR codes made before 0.0.7
        ]) {
          final data = await service.resolveQrString(raw);
          expect(data.course.name, 'Physics', reason: raw);
          expect(data.isCloud, isFalse, reason: raw);
        }
      },
    );

    test(
      'resolveQrString generates fresh UUIDs and unlinks original IDs',
      () async {
        final course = Course(
          id: 'orig-course-id',
          name: 'Calculus I',
          code: 'MATH101',
          instructor: 'Prof. Newton',
          color: const Color(0xFF0284C7),
          credits: 3.5,
          grade: 88.0,
        );

        final events = [
          ScheduleEvent(
            id: 'orig-event-id',
            title: 'Calculus Lecture',
            courseId: 'orig-course-id',
            type: EventType.classType,
            startTime: DateTime(2026, 10, 1, 8, 30),
            endTime: DateTime(2026, 10, 1, 10, 0),
            location: 'Auditorium 1',
            daysOfWeek: [0, 2], // Sun, Tue
            recurring: true,
          ),
        ];

        final payload = service.generateOfflinePayload(course, events);
        final shareData = await service.resolveQrString(payload);

        // Verify fresh course ID
        expect(shareData.course.id, isNot(equals('orig-course-id')));
        expect(shareData.course.name, equals('Calculus I'));
        expect(shareData.course.code, equals('MATH101'));
        // Grade should be reset for shared courses
        expect(shareData.course.grade, isNull);

        // Verify events linked to the new course ID
        expect(shareData.events.length, equals(1));
        final resolvedEvent = shareData.events.first;
        expect(resolvedEvent.id, isNot(equals('orig-event-id')));
        expect(resolvedEvent.courseId, equals(shareData.course.id));
        expect(resolvedEvent.title, equals('Calculus Lecture'));
        expect(resolvedEvent.location, equals('Auditorium 1'));
        expect(resolvedEvent.daysOfWeek, equals([0, 2]));
      },
    );

    test('throws StateError on unrecognized QR strings', () {
      expect(
        () => service.resolveQrString('https://example.com/random'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
