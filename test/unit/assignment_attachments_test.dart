import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rocis_schedule/features/assignments/attachment_compressor.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';

/// A noisy photo-like image: noise compresses badly, so it exercises the
/// quality/size search rather than trivially fitting.
Uint8List _noisyPng(int w, int h) {
  final rng = Random(7);
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    p
      ..r = rng.nextInt(256)
      ..g = rng.nextInt(256)
      ..b = rng.nextInt(256);
  }
  return Uint8List.fromList(img.encodePng(image, level: 1));
}

void main() {
  group('prepareAttachment', () {
    test('keeps an image that already fits byte for byte', () async {
      final small = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 40, height: 40), quality: 80),
      );
      final out = await prepareAttachment(name: 'a.jpg', bytes: small);
      expect(out.data, small);
      expect(out.meta.mime, 'image/jpeg');
      expect(out.meta.gzipped, isFalse);
    });

    test(
      'shrinks a large noisy image under the limit as JPEG',
      () async {
        final big = _noisyPng(1800, 1400);
        expect(big.length, greaterThan(kMaxAttachmentBytes));

        final out = await prepareAttachment(name: 'scan.png', bytes: big);

        expect(out.data.length, lessThanOrEqualTo(kMaxAttachmentBytes));
        expect(out.meta.name, 'scan.jpg');
        expect(out.meta.mime, 'image/jpeg');
        expect(out.meta.size, out.data.length);
        expect(img.decodeJpg(out.data), isNotNull);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('gzips compressible files and restores them exactly', () async {
      final text = Uint8List.fromList(
        List.generate(900 * 1024, (i) => 97 + (i % 7)),
      );
      final out = await prepareAttachment(name: 'notes.txt', bytes: text);

      expect(out.meta.gzipped, isTrue);
      expect(out.data.length, lessThan(kMaxAttachmentBytes));
      expect(restoreAttachmentBytes(out.meta, out.data), text);
    });

    test('rejects an incompressible file over the limit', () async {
      final rng = Random(3);
      final noise = Uint8List.fromList(
        List.generate(1024 * 1024, (_) => rng.nextInt(256)),
      );
      expect(
        () => prepareAttachment(name: 'big.pdf', bytes: noise),
        throwsA(isA<AttachmentTooLargeException>()),
      );
    });

    test('treats an undecodable image as a plain file', () async {
      final junk = Uint8List.fromList(List.generate(2000, (i) => i % 251));
      final out = await prepareAttachment(name: 'photo.heic', bytes: junk);
      expect(out.meta.mime, 'application/octet-stream');
    });
  });

  group('Assignment', () {
    test('round-trips lecture link and attachments through a db map', () {
      final a = Assignment(
        id: 'a1',
        courseId: 'c1',
        title: 'HW 3',
        dueDate: DateTime(2026, 12, 1),
        lectureEventId: 'e1',
        lectureDate: DateTime(2026, 11, 3),
        attachments: const [
          AssignmentAttachment(
            id: 'f1',
            name: 'sheet.pdf',
            mime: 'application/pdf',
            size: 1234,
            gzipped: true,
          ),
        ],
      );

      final back = Assignment.fromMap(a.toDbMap());

      expect(back.lectureEventId, 'e1');
      expect(back.lectureDate, DateTime(2026, 11, 3));
      expect(back.attachments.single.name, 'sheet.pdf');
      expect(back.attachments.single.gzipped, isTrue);
    });

    test('reads old documents that have no lecture or attachments', () {
      final back = Assignment.fromMap({
        'id': 'old',
        'courseId': 'c',
        'title': 't',
        'dueDate': DateTime(2026, 1, 1).toIso8601String(),
        'isCompleted': 0,
        'priority': 1,
      });
      expect(back.hasLecture, isFalse);
      expect(back.attachments, isEmpty);
    });

    test('drops a half-set lecture link', () {
      final back = Assignment.fromMap({
        'id': 'x',
        'courseId': 'c',
        'title': 't',
        'dueDate': DateTime(2026, 1, 1).toIso8601String(),
        'lectureEventId': 'e1',
      });
      expect(back.lectureEventId, isNull);
    });

    test('copyWith can clear the lecture', () {
      final a = Assignment(
        courseId: 'c',
        title: 't',
        dueDate: DateTime(2026, 1, 1),
        lectureEventId: 'e',
        lectureDate: DateTime(2025, 12, 1),
      );
      expect(a.copyWith(clearLecture: true).hasLecture, isFalse);
    });
  });
}
