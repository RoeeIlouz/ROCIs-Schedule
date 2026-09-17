import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/models/synced_task_model.dart';

class TasksFirestoreService {
  static const FirebaseOptions _webOptions = FirebaseOptions(
    apiKey: 'AIzaSyCElvqD6SzVOlYii_TThaXoy8_XZT88Pkw',
    appId: '1:867477199658:web:ae5bebfbeb0940a68d1c53',
    messagingSenderId: '867477199658',
    projectId: 'rocis-todo',
    authDomain: 'rocis-todo.firebaseapp.com',
    storageBucket: 'rocis-todo.firebasestorage.app',
    measurementId: 'G-WBCJEY70B9',
  );

  static const FirebaseOptions _androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyBD5Dw_v-PeYj0qgsnQHG4wYw4VEbfLD9E',
    appId: '1:867477199658:android:966d4a50b5b02d4e8d1c53',
    messagingSenderId: '867477199658',
    projectId: 'rocis-todo',
    storageBucket: 'rocis-todo.firebasestorage.app',
  );

  static FirebaseOptions get _platformOptions {
    if (kIsWeb) return _webOptions;
    return _androidOptions;
  }

  FirebaseFirestore? _tasksDb;
  bool _isInitialized = false;

  bool get isReady => _isInitialized && _tasksDb != null;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('TasksFirestoreService: Default Firebase not ready');
        return;
      }

      FirebaseApp tasksApp;
      try {
        tasksApp = Firebase.app('rocis-todo');
      } catch (_) {
        tasksApp = await Firebase.initializeApp(
          name: 'rocis-todo',
          options: _platformOptions,
        );
      }

      _tasksDb = FirebaseFirestore.instanceFor(app: tasksApp);
      _isInitialized = true;
      debugPrint(
        'TasksFirestoreService: Initialized rocis-todo secondary app successfully',
      );
    } catch (e) {
      debugPrint(
        'TasksFirestoreService: Secondary app init error (non-critical): $e',
      );
      _isInitialized = false;
    }
  }

  Future<List<SyncedTask>> fetchTasksForUser({
    required String? email,
    required String? uid,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    final db = _tasksDb;
    if (db == null) return [];

    try {
      String? targetUserId;
      if (uid != null && uid.isNotEmpty) {
        final doc = await db.collection('users').doc(uid).get();
        if (doc.exists) {
          targetUserId = uid;
        }
      }

      if (targetUserId == null && email != null && email.isNotEmpty) {
        final query = await db
            .collection('users')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          targetUserId = query.docs.first.id;
        }
      }

      if (targetUserId == null) return [];

      final snapshot = await db
          .collection('users')
          .doc(targetUserId)
          .collection('tasks')
          .where('isDeleted', isEqualTo: false)
          .get();

      final tasks = snapshot.docs
          .map((d) => SyncedTask.fromFirestore(d.data()))
          .where((t) => !t.isCompleted)
          .toList();

      tasks.sort((a, b) {
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

      return tasks;
    } catch (e) {
      debugPrint('TasksFirestoreService: Error fetching tasks: $e');
      return [];
    }
  }
}
