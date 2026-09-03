import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';

class FirestoreService {
  final FirebaseFirestore? _customDb;

  FirestoreService({FirebaseFirestore? firestore}) : _customDb = firestore;

  FirebaseFirestore? get _db {
    if (_customDb != null) return _customDb;
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseFirestore.instance;
    } catch (e) {
      return null;
    }
  }

  // User Profile
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    final db = _db;
    if (db == null) return;
    try {
      debugPrint('Firestore: Starting profile update for $uid...');
      await db.collection('users').doc(uid).set(data, SetOptions(merge: true));
      debugPrint('Firestore: Profile update successful for $uid');
    } catch (e) {
      debugPrint('Firestore Error: Failed to update profile: $e');
      rethrow;
    }
  }

  Future<DocumentSnapshot?> getProfile(String uid) async {
    final db = _db;
    if (db == null) return null;
    return await db.collection('users').doc(uid).get();
  }

  // Sync Courses
  Future<void> uploadCourses(String uid, List<Course> courses) async {
    final db = _db;
    if (db == null) return;
    try {
      final batch = db.batch();
      for (var course in courses) {
        final ref = db
            .collection('users')
            .doc(uid)
            .collection('courses')
            .doc(course.id);
        batch.set(ref, course.toMap());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore Error (Upload Courses): $e');
    }
  }

  // Sync Events
  Future<void> uploadEvents(String uid, List<ScheduleEvent> events) async {
    final db = _db;
    if (db == null) return;
    try {
      final batch = db.batch();
      for (var event in events) {
        final ref = db
            .collection('users')
            .doc(uid)
            .collection('events')
            .doc(event.id);
        batch.set(ref, event.toMap());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore Error (Upload Events): $e');
    }
  }

  // Assignments
  Future<void> updateAssignment(String uid, Assignment assignment) async {
    final db = _db;
    if (db == null) return;
    try {
      await db
          .collection('users')
          .doc(uid)
          .collection('assignments')
          .doc(assignment.id)
          .set(assignment.toMap());
    } catch (e) {
      debugPrint('Firestore Error (Assignment Update): $e');
    }
  }

  Future<void> deleteAssignment(String uid, String id) async {
    final db = _db;
    if (db == null) return;
    try {
      await db
          .collection('users')
          .doc(uid)
          .collection('assignments')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint('Firestore Error (Assignment Delete): $e');
    }
  }

  // Download Methods for User Data Sync
  Future<List<Course>> downloadCourses(String uid) async {
    final db = _db;
    if (db == null) return [];
    try {
      debugPrint('Firestore: Downloading courses for $uid...');
      final snapshot = await db
          .collection('users')
          .doc(uid)
          .collection('courses')
          .get();
      final courses = snapshot.docs
          .map((doc) => Course.fromMap(doc.data()))
          .toList();
      debugPrint('Firestore: Downloaded ${courses.length} courses');
      return courses;
    } catch (e) {
      debugPrint('Firestore Error (Download Courses): $e');
      return [];
    }
  }

  Future<List<ScheduleEvent>> downloadEvents(String uid) async {
    final db = _db;
    if (db == null) return [];
    try {
      debugPrint('Firestore: Downloading events for $uid...');
      final snapshot = await db
          .collection('users')
          .doc(uid)
          .collection('events')
          .get();
      final events = snapshot.docs
          .map((doc) => ScheduleEvent.fromMap(doc.data()))
          .toList();
      debugPrint('Firestore: Downloaded ${events.length} events');
      return events;
    } catch (e) {
      debugPrint('Firestore Error (Download Events): $e');
      return [];
    }
  }

  Future<List<Assignment>> downloadAssignments(String uid) async {
    final db = _db;
    if (db == null) return [];
    try {
      debugPrint('Firestore: Downloading assignments for $uid...');
      final snapshot = await db
          .collection('users')
          .doc(uid)
          .collection('assignments')
          .get();
      final assignments = snapshot.docs
          .map((doc) => Assignment.fromMap(doc.data()))
          .toList();
      debugPrint('Firestore: Downloaded ${assignments.length} assignments');
      return assignments;
    } catch (e) {
      debugPrint('Firestore Error (Download Assignments): $e');
      return [];
    }
  }

  // Delete Course and associated data
  Future<void> deleteCourse(String uid, String courseId) async {
    final db = _db;
    if (db == null) return;
    try {
      debugPrint('Firestore: Deleting course $courseId and its contents...');
      final batch = db.batch();

      batch.delete(
        db.collection('users').doc(uid).collection('courses').doc(courseId),
      );

      final eventsSnapshot = await db
          .collection('users')
          .doc(uid)
          .collection('events')
          .where('courseId', isEqualTo: courseId)
          .get();
      for (var doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final assignmentsSnapshot = await db
          .collection('users')
          .doc(uid)
          .collection('assignments')
          .where('courseId', isEqualTo: courseId)
          .get();
      for (var doc in assignmentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Firestore: Course and associated data deleted successfully');
    } catch (e) {
      debugPrint('Firestore Error (Delete Course): $e');
    }
  }

  // Delete specific Event
  Future<void> deleteEvent(String uid, String eventId) async {
    final db = _db;
    if (db == null) return;
    try {
      await db
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc(eventId)
          .delete();
      debugPrint('Firestore: Event $eventId deleted');
    } catch (e) {
      debugPrint('Firestore Error (Delete Event): $e');
    }
  }

  // Delete all user data from Firestore collections (for cleanup)
  Future<void> deleteAllUserData(String uid) async {
    final db = _db;
    if (db == null) return;
    try {
      debugPrint('Firestore: Deleting all data for $uid...');
      final batch = db.batch();

      final coursesSnapshot = await db
          .collection('users')
          .doc(uid)
          .collection('courses')
          .get();
      for (var doc in coursesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final eventsSnapshot = await db
          .collection('users')
          .doc(uid)
          .collection('events')
          .get();
      for (var doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final assignmentsSnapshot = await db
          .collection('users')
          .doc(uid)
          .collection('assignments')
          .get();
      for (var doc in assignmentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Firestore: All user data deleted');
    } catch (e) {
      debugPrint('Firestore Error (Delete All User Data): $e');
    }
  }
}
