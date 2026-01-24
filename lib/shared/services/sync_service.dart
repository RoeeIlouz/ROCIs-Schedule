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

  StreamSubscription? _connectivitySubscription;

  SyncService(
    this._authService,
    this._courseProvider,
    this._assignmentProvider,
  ) {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      if (result != ConnectivityResult.none) {
        syncData();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  /// Downloads user data from Firestore and saves to local database.
  /// This should be called when a user logs in to ensure they have their cloud data.
  Future<void> downloadUserData() async {
    final user = _authService.user;
    if (user == null) return;

    try {
      debugPrint('Downloading user data from Firestore...');

      // Download and save courses
      final remoteCourses = await _firestoreService.downloadCourses(user.uid);
      for (var course in remoteCourses) {
        await _courseProvider.addCourseFromSync(course);
      }

      // Download and save events
      final remoteEvents = await _firestoreService.downloadEvents(user.uid);
      for (var event in remoteEvents) {
        await _courseProvider.addEventFromSync(event);
      }

      // Download and save assignments
      final assignmentProvider = _assignmentProvider;
      if (assignmentProvider != null) {
        final remoteAssignments = await _firestoreService.downloadAssignments(user.uid);
        for (var assignment in remoteAssignments) {
          await assignmentProvider.addAssignmentFromSync(assignment);
        }
      }

      _isInitialSyncDone = true;
      debugPrint('Download completed successfully.');
    } catch (e) {
      debugPrint('Download failed: $e');
    }
  }

  /// Performs initial sync: downloads from Firestore if local DB is empty,
  /// otherwise uploads local data to Firestore.
  Future<void> performInitialSync() async {
    final user = _authService.user;
    if (user == null || _isInitialSyncDone) return;

    try {
      debugPrint('Performing initial sync...');
      
      // Check if local database has data
      final hasLocalCourses = _courseProvider.courses.isNotEmpty;
      final hasLocalEvents = _courseProvider.events.isNotEmpty;
      final hasLocalAssignments = _assignmentProvider?.assignments.isNotEmpty ?? false;
      
      if (!hasLocalCourses && !hasLocalEvents && !hasLocalAssignments) {
        // Local DB is empty, download from Firestore
        debugPrint('Local DB empty, downloading from Firestore...');
        await downloadUserData();
      } else {
        // Local DB has data, upload to Firestore
        debugPrint('Local DB has data, uploading to Firestore...');
        await syncData();
      }
      
      _isInitialSyncDone = true;
    } catch (e) {
      debugPrint('Initial sync failed: $e');
    }
  }

  /// Uploads local data to Firestore
  Future<void> syncData() async {
    final user = _authService.user;
    if (user == null) return;

    try {
      debugPrint('Syncing data to Firestore...');

      // Upload local courses
      await _firestoreService.uploadCourses(user.uid, _courseProvider.courses);

      // Upload local events
      await _firestoreService.uploadEvents(user.uid, _courseProvider.events);

      // Upload local assignments
      if (_assignmentProvider != null) {
        for (var assignment in _assignmentProvider.assignments) {
          await _firestoreService.updateAssignment(user.uid, assignment);
        }
      }

      debugPrint('Sync completed successfully.');
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  /// Full bidirectional sync: downloads from Firestore, merges with local, uploads back
  Future<void> fullSync() async {
    final user = _authService.user;
    if (user == null) return;

    try {
      debugPrint('Performing full bidirectional sync...');
      
      // First download remote data
      await downloadUserData();
      
      // Then upload local data (this will merge/overwrite)
      await syncData();
      
      debugPrint('Full sync completed successfully.');
    } catch (e) {
      debugPrint('Full sync failed: $e');
    }
  }
}
