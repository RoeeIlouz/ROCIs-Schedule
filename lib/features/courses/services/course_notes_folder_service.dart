import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/features/courses/services/course_notes_pdf_service.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:saf/saf.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A directory the user granted the app write access to.
class NotesFolder {
  final String uri;
  final String name;
  const NotesFolder({required this.uri, required this.name});
}

/// Thrown when the stored folder grant is gone (revoked, folder deleted, or
/// storage unmounted) and the user must pick the folder again.
class NotesFolderAccessLost implements Exception {
  const NotesFolderAccessLost();
}

/// The few Storage Access Framework calls this feature needs, so the service
/// can be tested without a device.
abstract class NotesFolderStorage {
  Future<NotesFolder?> pickDirectory();
  Future<bool> hasWriteGrant(String uri);
  Future<void> releaseGrant(String uri);

  /// Creates [name] under [parentUri] if missing and returns its URI.
  Future<String> ensureSubfolder(String parentUri, String name);

  /// Writes without overwriting: a name clash gets an auto-renamed copy.
  Future<void> writeFile(
    String dirUri,
    String name,
    String mime,
    Uint8List bytes,
  );
}

class SafNotesFolderStorage implements NotesFolderStorage {
  final Saf _saf = Saf();

  @override
  Future<NotesFolder?> pickDirectory() async {
    final dir = await _saf.pickDirectory();
    return dir == null ? null : NotesFolder(uri: dir.uri, name: dir.name);
  }

  @override
  Future<bool> hasWriteGrant(String uri) async {
    final grants = await _saf.persistedPermissions();
    return grants.any((g) => g.uri == uri && g.write);
  }

  @override
  Future<void> releaseGrant(String uri) => _saf.releasePersistedPermission(uri);

  @override
  Future<String> ensureSubfolder(String parentUri, String name) async {
    try {
      return (await _saf.mkdirp(parentUri, [name])).uri;
    } on SafPermissionException {
      throw const NotesFolderAccessLost();
    } on SafNotFoundException {
      throw const NotesFolderAccessLost();
    }
  }

  @override
  Future<void> writeFile(
    String dirUri,
    String name,
    String mime,
    Uint8List bytes,
  ) async {
    try {
      await _saf.writeFileBytes(dirUri, name, mime, bytes);
    } on SafPermissionException {
      throw const NotesFolderAccessLost();
    } on SafNotFoundException {
      throw const NotesFolderAccessLost();
    }
  }
}

/// Keeps one user-chosen "notes root" folder and a subfolder per course in it,
/// so Goodnotes, Notability or a cloud-drive app can open each course's
/// notebook from a predictable place.
///
/// Neither notes app mirrors this folder on its own; the user still imports
/// from it. Android only: it relies on the Storage Access Framework.
class CourseNotesFolderService {
  static const _uriKey = 'notes_folder_uri';
  static const _nameKey = 'notes_folder_name';

  final NotesFolderStorage _storage;

  CourseNotesFolderService({NotesFolderStorage? storage})
      : _storage = storage ?? SafNotesFolderStorage();

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The saved folder, or null when none is set or its grant is gone.
  Future<NotesFolder?> current() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_uriKey);
    if (uri == null) return null;
    if (!await _storage.hasWriteGrant(uri)) return null;
    return NotesFolder(uri: uri, name: prefs.getString(_nameKey) ?? '');
  }

  /// Asks the user for a folder and remembers it. Null if they cancelled.
  Future<NotesFolder?> pickRoot() async {
    final picked = await _storage.pickDirectory();
    if (picked == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_uriKey);
    await prefs.setString(_uriKey, picked.uri);
    await prefs.setString(_nameKey, picked.name);
    if (previous != null && previous != picked.uri) {
      try {
        await _storage.releaseGrant(previous);
      } catch (_) {
        // The old grant may already be gone; nothing to clean up.
      }
    }
    return picked;
  }

  /// Creates the course's subfolder and returns its URI.
  Future<String> ensureCourseFolder(Course course) async {
    final root = await current();
    if (root == null) throw const NotesFolderAccessLost();
    return _storage.ensureSubfolder(
      root.uri,
      CourseNotesPdfService.folderNameFor(course),
    );
  }

  /// Creates the subfolder for every course. Returns how many exist after.
  Future<int> ensureAllCourseFolders(List<Course> courses) async {
    final root = await current();
    if (root == null) throw const NotesFolderAccessLost();
    final names = courses.map(CourseNotesPdfService.folderNameFor).toSet();
    for (final name in names) {
      await _storage.ensureSubfolder(root.uri, name);
    }
    return names.length;
  }

  /// Saves the notebook PDF into the course's folder. An existing file with
  /// the same name is kept, and the new one is renamed by the system.
  Future<void> saveCoursePdf(Course course, Uint8List bytes) async {
    final dirUri = await ensureCourseFolder(course);
    await _storage.writeFile(
      dirUri,
      CourseNotesPdfService.fileNameFor(course),
      'application/pdf',
      bytes,
    );
  }
}
