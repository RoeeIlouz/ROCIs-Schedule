import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/models/synced_task_model.dart';
import 'package:rocis_schedule/shared/services/tasks_firestore_service.dart';

class SyncedTasksProvider extends ChangeNotifier {
  final TasksFirestoreService _tasksService;
  final String? _email;
  final String? _uid;

  List<SyncedTask> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SyncedTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  SyncedTasksProvider({
    TasksFirestoreService? tasksService,
    String? email,
    String? uid,
  }) : _tasksService = tasksService ?? TasksFirestoreService(),
       _email = email,
       _uid = uid;

  Future<void> loadTasks() async {
    if (_email == null && _uid == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _tasksService.fetchTasksForUser(email: _email, uid: _uid);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
