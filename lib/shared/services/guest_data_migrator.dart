import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/features/courses/course_provider.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/services/firestore_service.dart';
import 'package:rocis_schedule/shared/services/local_db_service.dart';

/// Moves a guest's local data into the account they sign in to, so nothing
/// made before signing in is lost.
///
/// Runs before the account's providers load, one table at a time in foreign
/// key order (courses before the events and assignments that reference them).
/// Records the account already has keep the account's version.
class GuestDataMigrator {
  static const guestUserId = 'guest';

  static Future<void> migrateInto(
    String uid, {
    FirestoreService? firestore,
  }) async {
    if (uid == guestUserId) return;
    try {
      final guest = LocalDbService(guestUserId);
      final courses = await guest.getCourses();
      final events = await guest.getEvents();
      final semesters = await guest.getSemesters();
      final assignments = await guest.getAssignments();

      if (courses.isNotEmpty || events.isNotEmpty || assignments.isNotEmpty) {
        final account = LocalDbService(uid);
        final courseIds = {for (final c in await account.getCourses()) c.id};
        final eventIds = {for (final e in await account.getEvents()) e.id};
        final semesterIds = {
          for (final s in await account.getSemesters()) s.id,
        };
        final assignmentIds = {
          for (final a in await account.getAssignments()) a.id,
        };

        final newSemesters = semesters
            .where((s) => !semesterIds.contains(s.id))
            .toList();
        final newCourses = courses
            .where((c) => !courseIds.contains(c.id))
            .toList();
        final newEvents = events
            .where((e) => !eventIds.contains(e.id))
            .toList();
        final newAssignments = assignments
            .where((a) => !assignmentIds.contains(a.id))
            .toList();

        for (final semester in newSemesters) {
          await account.insertSemester(semester);
        }
        for (final course in newCourses) {
          await account.insertCourse(course);
        }
        for (final event in newEvents) {
          await account.insertEvent(event);
        }
        for (final assignment in newAssignments) {
          await account.insertAssignment(assignment);
        }

        _upload(
          uid,
          firestore ?? FirestoreService(),
          newSemesters,
          newCourses,
          newEvents,
          newAssignments,
        );
      }

      await LocalDbService.deleteDatabaseFor(guestUserId);
    } catch (e) {
      // Keep the guest database so a later sign-in can retry.
      debugPrint('GuestDataMigrator: migration into $uid failed: $e');
    }
  }

  /// Courses, events and assignments have unique ids, so uploading them can't
  /// clobber cloud data. Default semester ids exist in every account; the
  /// live mirror keeps the cloud's version of those.
  static void _upload(
    String uid,
    FirestoreService firestore,
    List<Semester> newSemesters,
    List<Course> newCourses,
    List<ScheduleEvent> newEvents,
    List<Assignment> newAssignments,
  ) {
    final defaultIds = {for (final s in CourseProvider.defaultSemesters) s.id};
    final customSemesters = newSemesters
        .where((s) => !defaultIds.contains(s.id))
        .toList();
    final writes = [
      if (customSemesters.isNotEmpty)
        firestore.uploadSemesters(uid, customSemesters),
      if (newCourses.isNotEmpty) firestore.uploadCourses(uid, newCourses),
      if (newEvents.isNotEmpty) firestore.uploadEvents(uid, newEvents),
      if (newAssignments.isNotEmpty)
        firestore.uploadAssignments(uid, newAssignments),
    ];
    // Not awaited: Firestore queues writes offline and would never complete.
    unawaited(
      Future.wait(writes).catchError((Object e) {
        debugPrint('GuestDataMigrator: upload failed: $e');
        return <void>[];
      }),
    );
  }
}
