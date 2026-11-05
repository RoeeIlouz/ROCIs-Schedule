import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory dir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('assignment_db_');
    await databaseFactory.setDatabasesPath(dir.path);
    await LocalDbService.clearCache();
  });

  tearDown(() async {
    await LocalDbService.clearCache();
    await dir.delete(recursive: true);
  });

  test('upgrades a v8 database, keeping existing assignments', () async {
    final path = p.join(dir.path, 'rocis_schedule_mig_user.db');
    final old = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE assignments(
              id TEXT PRIMARY KEY, courseId TEXT, title TEXT,
              description TEXT, dueDate TEXT, isCompleted INTEGER,
              priority INTEGER
            )
          ''');
          await db.insert('assignments', {
            'id': 'old1',
            'courseId': 'c1',
            'title': 'Written before the upgrade',
            'description': '',
            'dueDate': DateTime(2026, 12, 1).toIso8601String(),
            'isCompleted': 0,
            'priority': 1,
          });
        },
      ),
    );
    await old.close();

    final db = LocalDbService('mig_user');
    final loaded = await db.getAssignments();

    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'Written before the upgrade');
    expect(loaded.single.hasLecture, isFalse);
    expect(loaded.single.attachments, isEmpty);

    // The new columns and blob table work on the upgraded database.
    await db.insertAssignment(
      loaded.single.copyWith(
        lectureEventId: 'e1',
        lectureDate: DateTime(2026, 11, 3),
        attachments: const [
          AssignmentAttachment(
            id: 'f1',
            name: 'a.jpg',
            mime: 'image/jpeg',
            size: 3,
          ),
        ],
      ),
    );
    await db.saveAttachmentBlob('f1', 'old1', Uint8List.fromList([1, 2, 3]));

    final again = (await db.getAssignments()).single;
    expect(again.lectureEventId, 'e1');
    expect(again.lectureDate, DateTime(2026, 11, 3));
    expect(again.attachments.single.name, 'a.jpg');
    expect(await db.getAttachmentBlob('f1'), Uint8List.fromList([1, 2, 3]));
  });

  test('re-saving an assignment keeps its attachment bytes', () async {
    final db = LocalDbService('fresh_user');
    await db.insertCourse(
      Course(
        id: 'c1',
        name: 'Course',
        code: 'C1',
        instructor: 'I',
        color: Colors.blue,
        credits: 3,
      ),
    );
    final a = Assignment(
      id: 'a1',
      courseId: 'c1',
      title: 'HW',
      dueDate: DateTime(2026, 12, 1),
    );
    await db.insertAssignment(a);
    await db.saveAttachmentBlob('f1', 'a1', Uint8List.fromList([9, 9]));

    // Saving uses REPLACE; bytes must not be cascaded away with the old row.
    await db.insertAssignment(a.copyWith(title: 'HW (edited)'));

    expect(await db.getAttachmentBlob('f1'), Uint8List.fromList([9, 9]));

    await db.deleteAttachmentBlobsFor('a1');
    expect(await db.getAttachmentBlob('f1'), isNull);
  });
}
