import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rocis_schedule/features/auth/auth_service.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/features/assignments/assignment_provider.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  final AuthService _authService;
  final CourseProvider _courseProvider;
  final AssignmentProvider? _assignmentProvider;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isInitialSyncDone = false;
  bool _isSyncing = false;
  bool _isDisposed = false;

  StreamSubscription? _connectivitySubscription;

  SyncService(
    this._authService,
    this._courseProvider,
    this._assignmentProvider,
  ) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (!_isDisposed && isOnline) {
        syncData();
      }
    });
  }

  void dispose() {
    _isDisposed = true;
    _connectivitySubscription?.cancel();
  }

  bool get isSyncing => _isSyncing;

  /// Downloads user data from Firestore and saves to local database.
  /// This should be called when a user logs in to ensure they have their cloud data.
  Future<void> downloadUserData() async {
    final user = _authService.user;
    if (user == null || _isDisposed) return;

    try {
      debugPrint(
        'SyncService: Downloading user data from Firestore for ${user.uid}...',
      );

      // Download and save courses
      final remoteCourses = await _firestoreService.downloadCourses(user.uid);
      for (var course in remoteCourses) {
        if (_isDisposed) return;
        await _courseProvider.addCourseFromSync(course);
      }

      // Download and save events
      final remoteEvents = await _firestoreService.downloadEvents(user.uid);
      for (var event in remoteEvents) {
        if (_isDisposed) return;
        await _courseProvider.addEventFromSync(event);
      }

      // Download and save assignments
      final assignmentProvider = _assignmentProvider;
      if (assignmentProvider != null) {
        final remoteAssignments = await _firestoreService.downloadAssignments(
          user.uid,
        );
        for (var assignment in remoteAssignments) {
          if (_isDisposed) return;
          await assignmentProvider.addAssignmentFromSync(assignment);
        }
      }

      _isInitialSyncDone = true;
      debugPrint('SyncService: Download completed successfully.');
    } catch (e) {
      debugPrint('SyncService Error (Download failed): $e');
    }
  }

  /// Performs initial sync: downloads from Firestore if local DB is empty,
  /// otherwise uploads local data to Firestore.
  Future<void> performInitialSync() async {
    final user = _authService.user;
    if (user == null || _isInitialSyncDone || _isSyncing || _isDisposed) return;

    _isSyncing = true;
    try {
      debugPrint('SyncService: Performing initial sync...');

      final hasLocalCourses = _courseProvider.courses.isNotEmpty;
      final hasLocalEvents = _courseProvider.events.isNotEmpty;
      final hasLocalAssignments =
          _assignmentProvider?.assignments.isNotEmpty ?? false;

      if (!hasLocalCourses && !hasLocalEvents && !hasLocalAssignments) {
        debugPrint(
          'SyncService: Local DB empty, downloading from Firestore...',
        );
        await downloadUserData();
      } else {
        debugPrint('SyncService: Local DB has data, uploading to Firestore...');
        await syncData();
      }

      _isInitialSyncDone = true;
    } catch (e) {
      debugPrint('SyncService Error (Initial sync failed): $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Uploads local data to Firestore
  Future<void> syncData() async {
    final user = _authService.user;
    if (user == null || _isSyncing || _isDisposed) return;

    _isSyncing = true;
    try {
      debugPrint('SyncService: Syncing data to Firestore...');

      // Upload local courses
      await _firestoreService.uploadCourses(user.uid, _courseProvider.courses);

      // Upload local events
      await _firestoreService.uploadEvents(user.uid, _courseProvider.events);

      // Upload local assignments
      if (_assignmentProvider != null) {
        for (var assignment in _assignmentProvider.assignments) {
          if (_isDisposed) return;
          await _firestoreService.updateAssignment(user.uid, assignment);
        }
      }

      debugPrint('SyncService: Sync completed successfully.');
    } catch (e) {
      debugPrint('SyncService Error (Sync failed): $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Full bidirectional sync: downloads from Firestore, merges with local, uploads back
  Future<void> fullSync() async {
    final user = _authService.user;
    if (user == null || _isSyncing || _isDisposed) return;

    _isSyncing = true;
    try {
      debugPrint('SyncService: Performing full bidirectional sync...');

      await downloadUserData();
      await syncData();

      debugPrint('SyncService: Full sync completed successfully.');
    } catch (e) {
      debugPrint('SyncService Error (Full sync failed): $e');
    } finally {
      _isSyncing = false;
    }
  }
}
