import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // User Profile
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    try {
      debugPrint('Firestore: Starting profile update for $uid...');
      // Ensure Firestore is pointing to the right settings for troubleshooting
      _db.settings = const Settings(
        persistenceEnabled: false, // Force network for troubleshooting
      );

      await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
      debugPrint('Firestore: Profile update successful for $uid');
    } catch (e) {
      debugPrint('Firestore Error: Failed to update profile: $e');
      rethrow;
    }
  }

  Future<DocumentSnapshot> getProfile(String uid) async {
    return await _db.collection('users').doc(uid).get();
  }

  // Sync Courses
  Future<void> uploadCourses(String uid, List<Course> courses) async {
    final batch = _db.batch();
    for (var course in courses) {
      final ref = _db
          .collection('users')
          .doc(uid)
          .collection('courses')
          .doc(course.id);
      batch.set(ref, course.toMap());
    }
    await batch.commit();
  }

  // Sync Events
  Future<void> uploadEvents(String uid, List<ScheduleEvent> events) async {
    final batch = _db.batch();
    for (var event in events) {
      final ref = _db
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc(event.id);
      batch.set(ref, event.toMap());
    }
    await batch.commit();
  }

  // Friends System
  Future<void> sendFriendRequest(String fromUid, String toEmail) async {
    // 1. Find user ID by email
    final query = await _db
        .collection('users')
        .where('email', isEqualTo: toEmail)
        .limit(1)
        .get();
    if (query.docs.isEmpty) throw Exception('User not found');

    final toUid = query.docs.first.id;
    if (fromUid == toUid) throw Exception('You cannot add yourself');

    // 2. Add request
    await _db
        .collection('users')
        .doc(toUid)
        .collection('friend_requests')
        .doc(fromUid)
        .set({
          'fromUid': fromUid,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
  }

  Stream<QuerySnapshot> getFriendRequests(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('friend_requests')
        .snapshots();
  }

  Future<void> acceptFriendRequest(String uid, String friendUid) async {
    final batch = _db.batch();

    // Add to my friends
    batch.set(
      _db.collection('users').doc(uid).collection('friends').doc(friendUid),
      {'uid': friendUid, 'since': FieldValue.serverTimestamp()},
    );

    // Add myself to friend's friends
    batch.set(
      _db.collection('users').doc(friendUid).collection('friends').doc(uid),
      {'uid': uid, 'since': FieldValue.serverTimestamp()},
    );

    // Delete request
    batch.delete(
      _db
          .collection('users')
          .doc(uid)
          .collection('friend_requests')
          .doc(friendUid),
    );

    await batch.commit();
  }

  Future<void> declineFriendRequest(String uid, String friendUid) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('friend_requests')
        .doc(friendUid)
        .delete();
  }

  Future<void> removeFriend(String uid, String friendUid) async {
    final batch = _db.batch();

    // Remove from my friends
    batch.delete(
      _db.collection('users').doc(uid).collection('friends').doc(friendUid),
    );

    // Remove myself from friend's friends
    batch.delete(
      _db.collection('users').doc(friendUid).collection('friends').doc(uid),
    );

    await batch.commit();
  }

  // Assignments
  Future<void> updateAssignment(String uid, Assignment assignment) async {
    try {
      await _db
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
    try {
      await _db
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
    try {
      debugPrint('Firestore: Downloading courses for $uid...');
      final snapshot = await _db
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
    try {
      debugPrint('Firestore: Downloading events for $uid...');
      final snapshot = await _db
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
    try {
      debugPrint('Firestore: Downloading assignments for $uid...');
      final snapshot = await _db
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
    try {
      debugPrint('Firestore: Deleting course $courseId and its contents...');
      final batch = _db.batch();

      // 1. Delete the course document
      batch.delete(
        _db.collection('users').doc(uid).collection('courses').doc(courseId),
      );

      // 2. Find and delete all events for this course
      final eventsSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('events')
          .where('courseId', isEqualTo: courseId)
          .get();
      for (var doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 3. Find and delete all assignments for this course
      final assignmentsSnapshot = await _db
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
    try {
      await _db
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
    try {
      debugPrint('Firestore: Deleting all data for $uid...');
      final batch = _db.batch();

      // Delete courses
      final coursesSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('courses')
          .get();
      for (var doc in coursesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete events
      final eventsSnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('events')
          .get();
      for (var doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete assignments
      final assignmentsSnapshot = await _db
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
