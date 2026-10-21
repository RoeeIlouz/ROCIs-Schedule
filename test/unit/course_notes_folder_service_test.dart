import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rocis_schedule/features/courses/services/course_notes_folder_service.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStorage implements NotesFolderStorage {
  NotesFolder? toPick;
  final grants = <String>{};
  final released = <String>[];
  final subfolders = <String>[];
  final written = <String>[];
  bool denyAccess = false;

  @override
  Future<NotesFolder?> pickDirectory() async {
    final picked = toPick;
    if (picked != null) grants.add(picked.uri);
    return picked;
  }

  @override
  Future<bool> hasWriteGrant(String uri) async => grants.contains(uri);

  @override
  Future<void> releaseGrant(String uri) async {
    released.add(uri);
    grants.remove(uri);
  }

  @override
  Future<String> ensureSubfolder(String parentUri, String name) async {
    if (denyAccess) throw const NotesFolderAccessLost();
    subfolders.add(name);
    return '$parentUri/$name';
  }

  @override
  Future<void> writeFile(
    String dirUri,
    String name,
    String mime,
    Uint8List bytes,
  ) async {
    if (denyAccess) throw const NotesFolderAccessLost();
    written.add('$dirUri/$name');
  }
}

Course _course(String name) => Course(
      id: name,
      name: name,
      code: '',
      instructor: '',
      color: Colors.teal,
      credits: 3,
    );

void main() {
  late _FakeStorage storage;
  late CourseNotesFolderService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = _FakeStorage();
    service = CourseNotesFolderService(storage: storage);
  });

  test('current is null until a folder is picked', () async {
    expect(await service.current(), isNull);
  });

  test('pickRoot stores the folder and current returns it', () async {
    storage.toPick = const NotesFolder(uri: 'content://root', name: 'Notes');
    final picked = await service.pickRoot();
    expect(picked?.uri, 'content://root');
    final current = await service.current();
    expect(current?.name, 'Notes');
  });

  test('a cancelled pick keeps the previous folder', () async {
    storage.toPick = const NotesFolder(uri: 'content://root', name: 'Notes');
    await service.pickRoot();
    storage.toPick = null;
    expect(await service.pickRoot(), isNull);
    expect((await service.current())?.uri, 'content://root');
  });

  test('picking a different folder releases the old grant', () async {
    storage.toPick = const NotesFolder(uri: 'content://a', name: 'A');
    await service.pickRoot();
    storage.toPick = const NotesFolder(uri: 'content://b', name: 'B');
    await service.pickRoot();
    expect(storage.released, ['content://a']);
  });

  test('current is null once the grant has been revoked', () async {
    storage.toPick = const NotesFolder(uri: 'content://root', name: 'Notes');
    await service.pickRoot();
    storage.grants.clear();
    expect(await service.current(), isNull);
  });

  test('saveCoursePdf writes into the course subfolder', () async {
    storage.toPick = const NotesFolder(uri: 'content://root', name: 'Notes');
    await service.pickRoot();
    await service.saveCoursePdf(_course('Calculus 2'), Uint8List(3));
    expect(storage.subfolders, ['Calculus 2']);
    expect(storage.written, ['content://root/Calculus 2/Calculus 2.pdf']);
  });

  test('ensureAllCourseFolders creates each distinct folder once', () async {
    storage.toPick = const NotesFolder(uri: 'content://root', name: 'Notes');
    await service.pickRoot();
    final count = await service.ensureAllCourseFolders(
      [_course('Physics'), _course('Physics'), _course('A/B')],
    );
    expect(count, 2);
    expect(storage.subfolders, ['Physics', 'A_B']);
  });

  test('saving without a folder reports lost access', () async {
    expect(
      () => service.saveCoursePdf(_course('Physics'), Uint8List(1)),
      throwsA(isA<NotesFolderAccessLost>()),
    );
  });

  test('storage access errors surface as NotesFolderAccessLost', () async {
    storage.toPick = const NotesFolder(uri: 'content://root', name: 'Notes');
    await service.pickRoot();
    storage.denyAccess = true;
    expect(
      () => service.saveCoursePdf(_course('Physics'), Uint8List(1)),
      throwsA(isA<NotesFolderAccessLost>()),
    );
  });
}
