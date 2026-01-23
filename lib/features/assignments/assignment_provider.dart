import 'package:flutter/foundation.dart';
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

  Future<void> addAssignment(Assignment assignment) async {
    await _db.insertAssignment(assignment);
    _assignments.add(assignment);
    notifyListeners();

    // Background sync
    _firestore.updateAssignment(uid, assignment);
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
    await _db.deleteAssignment(id);
    _assignments.removeWhere((a) => a.id == id);
    notifyListeners();

    // Background sync
    _firestore.deleteAssignment(uid, id);
  }

  List<Assignment> getAssignmentsByCourse(String courseId) {
    return _assignments.where((a) => a.courseId == courseId).toList();
  }
}
