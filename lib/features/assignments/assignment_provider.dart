import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/features/assignments/attachment_compressor.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';

class AssignmentProvider extends ChangeNotifier {
  final LocalDbService _db;
  final FirestoreService _firestore = FirestoreService();
  final String uid;

  List<Assignment> _assignments = [];
  bool _isLoading = false;

  AssignmentProvider(this.uid) : _db = LocalDbService(uid);

  List<Assignment> get assignments => _assignments;
  bool get isLoading => _isLoading;

  Future<void> loadAssignments() async {
    _isLoading = true;
    notifyListeners();

    try {
      _assignments = await _db.getAssignments();
    } catch (e) {
      debugPrint('Error loading assignments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds [assignment], or replaces the one with the same id (editing).
  Future<void> addAssignment(Assignment assignment) async {
    await _db.insertAssignment(assignment);
    final index = _assignments.indexWhere((a) => a.id == assignment.id);
    if (index >= 0) {
      _assignments[index] = assignment;
    } else {
      _assignments.add(assignment);
    }
    notifyListeners();

    // Background sync
    _firestore.updateAssignment(uid, assignment);
  }

  /// Saves [assignment] together with attachment changes.
  ///
  /// [added] are stored locally and uploaded; [removed] are deleted from both.
  /// The assignment's own attachment list is rebuilt from what's left plus
  /// what was added, so callers pass the assignment with its current list.
  Future<void> saveWithAttachments(
    Assignment assignment, {
    List<PreparedAttachment> added = const [],
    List<AssignmentAttachment> removed = const [],
  }) async {
    final removedIds = removed.map((a) => a.id).toSet();
    for (final meta in removed) {
      await _db.deleteAttachmentBlob(meta.id);
      // Don't await: offline, the cloud write waits for connectivity.
      unawaited(_firestore.deleteAttachment(uid, assignment.id, meta.id));
    }
    for (final prepared in added) {
      await _db.saveAttachmentBlob(
        prepared.meta.id,
        assignment.id,
        prepared.data,
      );
      unawaited(
        _firestore
            .saveAttachment(uid, assignment.id, prepared.meta, prepared.data)
            .catchError((Object e) {
              debugPrint('Attachment upload failed: $e');
            }),
      );
    }
    final merged = [
      ...assignment.attachments.where((a) => !removedIds.contains(a.id)),
      ...added.map((p) => p.meta),
    ];
    await addAssignment(assignment.copyWith(attachments: merged));
  }

  /// Original bytes of [meta]: from this device if cached, else downloaded
  /// (and cached for next time). Null when unavailable offline.
  Future<Uint8List?> loadAttachmentBytes(
    Assignment assignment,
    AssignmentAttachment meta,
  ) async {
    var stored = await _db.getAttachmentBlob(meta.id);
    if (stored == null) {
      stored = await _firestore.loadAttachment(uid, assignment.id, meta.id);
      if (stored == null) return null;
      await _db.saveAttachmentBlob(meta.id, assignment.id, stored);
    }
    return restoreAttachmentBytes(meta, stored);
  }

  /// Add assignment from sync without triggering another sync
  /// Used when downloading data from Firestore
  Future<void> addAssignmentFromSync(Assignment assignment) async {
    await _db.insertAssignment(assignment);
    // Check if assignment already exists in memory
    final existingIndex = _assignments.indexWhere((a) => a.id == assignment.id);
    if (existingIndex >= 0) {
      _assignments[existingIndex] = assignment;
    } else {
      _assignments.add(assignment);
    }
    notifyListeners();
  }

  Future<void> toggleAssignmentCompletion(String id) async {
    final index = _assignments.indexWhere((a) => a.id == id);
    if (index != -1) {
      final updated = _assignments[index].copyWith(
        isCompleted: !_assignments[index].isCompleted,
      );
      await _db.insertAssignment(updated);
      _assignments[index] = updated;
      notifyListeners();

      // Background sync
      _firestore.updateAssignment(uid, updated);
    }
  }

  Future<void> deleteAssignment(String id) async {
    final doomed = _assignments.where((a) => a.id == id).toList();
    await _db.deleteAssignment(id);
    await _db.deleteAttachmentBlobsFor(id);
    _assignments.removeWhere((a) => a.id == id);
    notifyListeners();

    // Background sync. Firestore doesn't cascade into subcollections, so the
    // attachment documents are removed explicitly.
    for (final assignment in doomed) {
      for (final meta in assignment.attachments) {
        unawaited(_firestore.deleteAttachment(uid, id, meta.id));
      }
    }
    _firestore.deleteAssignment(uid, id);
  }

  /// Applies a batch of cloud changes with a single UI notification.
  Future<void> applyRemoteAssignments(
    List<Assignment> upserts,
    List<String> deletedIds,
  ) async {
    for (final assignment in upserts) {
      await _db.insertAssignment(assignment);
      final index = _assignments.indexWhere((a) => a.id == assignment.id);
      if (index >= 0) {
        _assignments[index] = assignment;
      } else {
        _assignments.add(assignment);
      }
    }
    for (final id in deletedIds) {
      await _db.deleteAssignment(id);
      await _db.deleteAttachmentBlobsFor(id);
    }
    _assignments.removeWhere((a) => deletedIds.contains(a.id));
    notifyListeners();
  }

  List<Assignment> getAssignmentsByCourse(String courseId) {
    return _assignments.where((a) => a.courseId == courseId).toList();
  }

  /// Clear all local data (used when user signs out)
  Future<void> clearLocalData() async {
    _assignments.clear();
    notifyListeners();
  }
}
