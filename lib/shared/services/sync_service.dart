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
}
