import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/models/synced_task_model.dart';
import 'package:rocis_schedule/shared/services/tasks_firestore_service.dart';

class SyncedTasksProvider extends ChangeNotifier {
  final TasksFirestoreService _tasksService;
  final String? _email;
  final String? _uid;
  StreamSubscription<Object?>? _tasksAuthSub;
  bool _disposed = false;

  String? get email => _email;
  String? get uid => _uid;

  List<SyncedTask> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SyncedTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Tasks load whenever the ROCIs Tasks sign-in changes, including its first
  /// state, which can arrive after the Schedule sign-in.
  SyncedTasksProvider({
    TasksFirestoreService? tasksService,
    String? email,
    String? uid,
    Stream<Object?>? tasksAuthChanges,
  }) : _tasksService = tasksService ?? TasksFirestoreService(),
       _email = email,
       _uid = uid {
    if (uid != null) {
      _tasksAuthSub =
          (tasksAuthChanges ?? TasksFirestoreService.authStateChanges()).listen(
            (_) => loadTasks(),
          );
    }
  }

  Future<void> loadTasks() async {
    if (_uid == null) return;
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      _tasks = await _tasksService.fetchTasks();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _tasksAuthSub?.cancel();
    super.dispose();
  }
}
