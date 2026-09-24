import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/services/mirror_reconciler.dart';

/// Keeps the local SQLite cache a live mirror of the user's Firestore data.
///
/// Firestore is the source of truth (its SDK queues offline writes); every
/// cloud snapshot is reconciled into the local cache with [planMirror], so
/// edits and deletions made on any device appear here within seconds.
class SyncService {
  final AuthService _authService;
  final CourseProvider _courseProvider;
  final AssignmentProvider? _assignmentProvider;
  final FirestoreService _firestoreService;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  final Map<String, Completer<void>> _firstServerSnapshot = {};
  bool _isSyncing = false;
  bool _isDisposed = false;

  static const _firstSnapshotTimeout = Duration(seconds: 10);

  SyncService(
    this._authService,
    this._courseProvider,
    this._assignmentProvider, {
    FirestoreService? firestoreService,
  }) : _firestoreService = firestoreService ?? FirestoreService();

  bool get isSyncing => _isSyncing;

  void dispose() {
    _isDisposed = true;
    _cancelListeners();
  }

  /// Starts the live mirror and waits (bounded) for the first server snapshot
  /// of each collection, so callers such as the login screen see cloud data.
  Future<void> performInitialSync() async {
    if (_subscriptions.isNotEmpty || _isDisposed) return;
    await _startLiveSync();
  }

  /// Restarts the mirror, re-reading every collection from the server.
  Future<void> fullSync() async {
    if (_isDisposed) return;
    _cancelListeners();
    await _startLiveSync();
  }

  /// Uploads the whole local cache (kept for manual recovery flows).
  Future<void> syncData() async {
    final uid = _authService.user?.uid;
    if (uid == null || _isDisposed) return;
    await Future.wait([
      _firestoreService.uploadCourses(uid, _courseProvider.courses),
      _firestoreService.uploadEvents(uid, _courseProvider.events),
      _firestoreService.uploadSemesters(uid, _courseProvider.semesters),
      if (_assignmentProvider != null)
        _firestoreService.uploadAssignments(
          uid,
          _assignmentProvider.assignments,
        ),
    ]);
  }

  Future<void> _startLiveSync() async {
    final uid = _authService.user?.uid;
    if (uid == null) return;
    _isSyncing = true;

    _listen<Course>(
      uid: uid,
      collection: 'courses',
      stream: _firestoreService.watchCourses(uid),
      local: () => _courseProvider.courses,
      idOf: (c) => c.id,
      toMap: (c) => c.toMap(),
      apply: _courseProvider.applyRemoteCourses,
      upload: (items) => _firestoreService.uploadCourses(uid, items),
    );
    _listen<ScheduleEvent>(
      uid: uid,
      collection: 'events',
      stream: _firestoreService.watchEvents(uid),
      local: () => _courseProvider.events,
      idOf: (e) => e.id,
      toMap: (e) => e.toMap(),
      apply: _courseProvider.applyRemoteEvents,
      upload: (items) => _firestoreService.uploadEvents(uid, items),
    );
    _listen<Semester>(
      uid: uid,
      collection: 'semesters',
      stream: _firestoreService.watchSemesters(uid),
      local: () => _courseProvider.semesters,
      idOf: (s) => s.id,
      toMap: (s) => s.toMap(),
      apply: _courseProvider.applyRemoteSemesters,
      upload: (items) => _firestoreService.uploadSemesters(uid, items),
    );
    final assignmentProvider = _assignmentProvider;
    if (assignmentProvider != null) {
      _listen<Assignment>(
        uid: uid,
        collection: 'assignments',
        stream: _firestoreService.watchAssignments(uid),
        local: () => assignmentProvider.assignments,
        idOf: (a) => a.id,
        toMap: (a) => a.toMap(),
        apply: assignmentProvider.applyRemoteAssignments,
        upload: (items) => _firestoreService.uploadAssignments(uid, items),
      );
    }

    try {
      await Future.wait(
        _firstServerSnapshot.values.map((c) => c.future),
      ).timeout(_firstSnapshotTimeout);
    } on TimeoutException {
      debugPrint('SyncService: first server snapshot timed out (offline?)');
    } finally {
      _isSyncing = false;
    }
  }

  void _listen<T>({
    required String uid,
    required String collection,
    required Stream<CloudSnapshot<T>> stream,
    required List<T> Function() local,
    required String Function(T) idOf,
    required Map<String, dynamic> Function(T) toMap,
    required Future<void> Function(List<T> upserts, List<String> deletedIds)
    apply,
    required Future<void> Function(List<T>) upload,
  }) {
    final firstSnapshot = Completer<void>();
    _firstServerSnapshot[collection] = firstSnapshot;
    // Snapshots are reconciled one at a time, in order.
    var pending = Future<void>.value();

    _subscriptions.add(
      stream.listen(
        (snapshot) {
          pending = pending
              .then((_) async {
                if (_isDisposed) return;
                await _reconcile(
                  uid: uid,
                  collection: collection,
                  snapshot: snapshot,
                  local: local(),
                  idOf: idOf,
                  toMap: toMap,
                  apply: apply,
                  upload: upload,
                );
                if (!snapshot.fromCache && !firstSnapshot.isCompleted) {
                  firstSnapshot.complete();
                }
              })
              .catchError((Object e) {
                debugPrint('SyncService: reconcile $collection failed: $e');
              });
        },
        onError: (Object e) {
          debugPrint('SyncService: $collection listener error: $e');
          if (!firstSnapshot.isCompleted) firstSnapshot.complete();
        },
      ),
    );
  }

  Future<void> _reconcile<T>({
    required String uid,
    required String collection,
    required CloudSnapshot<T> snapshot,
    required List<T> local,
    required String Function(T) idOf,
    required Map<String, dynamic> Function(T) toMap,
    required Future<void> Function(List<T>, List<String>) apply,
    required Future<void> Function(List<T>) upload,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = confirmedIdsKey(uid, collection);
    final plan = planMirror<T>(
      remote: snapshot.items,
      local: local,
      idOf: idOf,
      toMap: toMap,
      confirmedIds: (prefs.getStringList(key) ?? const []).toSet(),
      fromCache: snapshot.fromCache,
    );

    if (plan.changesLocal) {
      await apply(plan.upsertLocal, plan.deleteLocal);
    }
    if (plan.uploadToCloud.isNotEmpty) {
      unawaited(upload(plan.uploadToCloud));
    }
    final confirmed = plan.confirmedIds;
    if (confirmed != null) {
      await prefs.setStringList(key, confirmed.toList());
    }
  }

  static String confirmedIdsKey(String uid, String collection) =>
      'sync_confirmed_${collection}_$uid';

  void _cancelListeners() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _firstServerSnapshot.clear();
  }
}
