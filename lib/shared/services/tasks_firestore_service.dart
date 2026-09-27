import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  static Future<FirebaseApp>? _app;

  /// The rocis-todo secondary app, or null when Firebase isn't set up (tests).
  static Future<FirebaseApp?> _tasksApp() async {
    if (Firebase.apps.isEmpty) return null;
    try {
      return await (_app ??= _initApp());
    } catch (e) {
      debugPrint('TasksFirestoreService: Secondary app init error: $e');
      _app = null;
      return null;
    }
  }

  static Future<FirebaseApp> _initApp() async {
    try {
      return Firebase.app('rocis-todo');
    } catch (_) {
      return Firebase.initializeApp(
        name: 'rocis-todo',
        options: _platformOptions,
      );
    }
  }

  static Future<FirebaseAuth?> _tasksAuth() async {
    final app = await _tasksApp();
    return app == null ? null : FirebaseAuth.instanceFor(app: app);
  }

  /// Emits whenever the rocis-todo sign-in changes. Its session is persisted
  /// separately from the Schedule one, so it survives restarts.
  static Stream<User?> authStateChanges() async* {
    final auth = await _tasksAuth();
    if (auth != null) yield* auth.authStateChanges();
  }

  /// Signs in to rocis-todo with a Google access token. An ID token is issued
  /// for the Schedule project's client, so only the access token carries over.
  static Future<void> signInWithGoogleAccessToken(String accessToken) =>
      _signIn(
        (auth) => auth.signInWithCredential(
          GoogleAuthProvider.credential(accessToken: accessToken),
        ),
      );

  /// Signs in to rocis-todo with the same email and password, which works when
  /// the user registered in ROCIs Tasks with them.
  static Future<void> signInWithEmail(String email, String password) => _signIn(
    (auth) => auth.signInWithEmailAndPassword(email: email, password: password),
  );

  /// Synced tasks are optional, so a failed sign-in only leaves them empty.
  static Future<void> _signIn(
    Future<UserCredential> Function(FirebaseAuth auth) signIn,
  ) async {
    try {
      final auth = await _tasksAuth();
      if (auth != null) await signIn(auth);
    } catch (e) {
      debugPrint('TasksFirestoreService: rocis-todo sign-in skipped: $e');
    }
  }

  static Future<bool> get isSignedIn async =>
      (await _tasksAuth())?.currentUser != null;

  static Future<void> signOut() async {
    try {
      await (await _tasksAuth())?.signOut();
    } catch (e) {
      debugPrint('TasksFirestoreService: rocis-todo sign-out error: $e');
    }
  }

  /// The signed-in user's open tasks in ROCIs Tasks. Tasks rules only let a
  /// user read their own documents, so this reads as the rocis-todo user.
  Future<List<SyncedTask>> fetchTasks() async {
    final app = await _tasksApp();
    if (app == null) return [];
    final uid = FirebaseAuth.instanceFor(app: app).currentUser?.uid;
    if (uid == null) return [];

    try {
      final snapshot = await FirebaseFirestore.instanceFor(app: app)
          .collection('users')
          .doc(uid)
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
