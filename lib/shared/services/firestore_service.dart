import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';
import 'package:rocis_schedule/shared/services/guest_data_migrator.dart';

/// A snapshot of a user collection, flagged when served from the offline cache.
typedef CloudSnapshot<T> = ({List<T> items, bool fromCache});

class FirestoreService {
  static const _maxBatchWrites = 500;

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

  /// Guests keep their data on the device only; nothing is read from or
  /// written to the cloud until they sign in (see GuestDataMigrator).
  FirebaseFirestore? _dbFor(String uid) =>
      uid == GuestDataMigrator.guestUserId ? null : _db;

  // User Profile
  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    final db = _dbFor(uid);
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
    final db = _dbFor(uid);
    if (db == null) return null;
    return await db.collection('users').doc(uid).get();
  }

  CollectionReference<Map<String, dynamic>> _userCollection(
    FirebaseFirestore db,
    String uid,
    String collection,
  ) => db.collection('users').doc(uid).collection(collection);

  /// Writes documents in chunks of 500 (Firestore's per-batch limit).
  Future<void> _uploadAll(
    String uid,
    String collection,
    Iterable<MapEntry<String, Map<String, dynamic>>> docs,
  ) async {
    final db = _dbFor(uid);
    if (db == null) return;
    final entries = docs.toList();
    if (entries.isEmpty) return;
    try {
      final commits = <Future<void>>[];
      for (var i = 0; i < entries.length; i += _maxBatchWrites) {
        final batch = db.batch();
        final end = (i + _maxBatchWrites).clamp(0, entries.length);
        for (final entry in entries.sublist(i, end)) {
          batch.set(
            _userCollection(db, uid, collection).doc(entry.key),
            entry.value,
          );
        }
        commits.add(batch.commit());
      }
      await Future.wait(commits);
    } catch (e) {
      debugPrint('Firestore Error (Upload $collection): $e');
    }
  }

  Future<void> _saveDoc(
    String uid,
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final db = _dbFor(uid);
    if (db == null) return;
    try {
      await _userCollection(db, uid, collection).doc(id).set(data);
    } catch (e) {
      debugPrint('Firestore Error (Save $collection/$id): $e');
    }
  }

  /// Live stream of a user collection, mapped to models.
  Stream<CloudSnapshot<T>> _watch<T>(
    String uid,
    String collection,
    T Function(Map<String, dynamic>) fromMap,
  ) {
    final db = _dbFor(uid);
    if (db == null) return const Stream.empty();
    return _userCollection(db, uid, collection)
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => (
            items: snapshot.docs.map((doc) => fromMap(doc.data())).toList(),
            fromCache: snapshot.metadata.isFromCache,
          ),
        );
  }

  Stream<CloudSnapshot<Course>> watchCourses(String uid) =>
      _watch(uid, 'courses', Course.fromMap);
  Stream<CloudSnapshot<ScheduleEvent>> watchEvents(String uid) =>
      _watch(uid, 'events', ScheduleEvent.fromMap);
  Stream<CloudSnapshot<Semester>> watchSemesters(String uid) =>
      _watch(uid, 'semesters', Semester.fromMap);
  Stream<CloudSnapshot<Assignment>> watchAssignments(String uid) =>
      _watch(uid, 'assignments', Assignment.fromMap);

  // Sync Courses
  Future<void> uploadCourses(String uid, List<Course> courses) =>
      _uploadAll(uid, 'courses', courses.map((c) => MapEntry(c.id, c.toMap())));

  Future<void> saveCourse(String uid, Course course) =>
      _saveDoc(uid, 'courses', course.id, course.toMap());

  // Sync Events
  Future<void> uploadEvents(String uid, List<ScheduleEvent> events) =>
      _uploadAll(uid, 'events', events.map((e) => MapEntry(e.id, e.toMap())));

  Future<void> saveEvent(String uid, ScheduleEvent event) =>
      _saveDoc(uid, 'events', event.id, event.toMap());

  // Sync Semesters
  Future<void> uploadSemesters(String uid, List<Semester> semesters) =>
      _uploadAll(
        uid,
        'semesters',
        semesters.map((s) => MapEntry(s.id, s.toMap())),
      );

  Future<void> saveSemester(String uid, Semester semester) =>
      _saveDoc(uid, 'semesters', semester.id, semester.toMap());

  Future<void> uploadAssignments(String uid, List<Assignment> assignments) =>
      _uploadAll(
        uid,
        'assignments',
        assignments.map((a) => MapEntry(a.id, a.toMap())),
      );

  Future<List<Semester>> downloadSemesters(String uid) async {
    final db = _dbFor(uid);
    if (db == null) return [];
    try {
      debugPrint('Firestore: Downloading semesters for $uid...');
      final snapshot = await db
          .collection('users')
          .doc(uid)
          .collection('semesters')
          .get();
      final semesters = snapshot.docs
          .map((doc) => Semester.fromMap(doc.data()))
          .toList();
      debugPrint('Firestore: Downloaded ${semesters.length} semesters');
      return semesters;
    } catch (e) {
      debugPrint('Firestore Error (Download Semesters): $e');
      return [];
    }
  }

  // Assignments
  Future<void> updateAssignment(String uid, Assignment assignment) async {
    final db = _dbFor(uid);
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
    final db = _dbFor(uid);
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
    final db = _dbFor(uid);
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
    final db = _dbFor(uid);
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
    final db = _dbFor(uid);
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
    final db = _dbFor(uid);
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
    final db = _dbFor(uid);
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
    final db = _dbFor(uid);
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
