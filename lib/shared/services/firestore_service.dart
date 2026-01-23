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
}
