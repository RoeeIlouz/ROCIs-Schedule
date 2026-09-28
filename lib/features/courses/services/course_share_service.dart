import 'dart:convert';
import 'package:archive/archive.dart' show GZipDecoder, GZipEncoder;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:rocis_schedule/shared/models/schedule_models.dart';

/// Parsed result of a Course QR code payload (offline direct or cloud).
class CourseShareData {
  final Course course;
  final List<ScheduleEvent> events;
  final bool isCloud;
  final String? shareId;

  CourseShareData({
    required this.course,
    required this.events,
    this.isCloud = false,
    this.shareId,
  });
}

class CourseShareService {
  /// Share links are verified App Links: they open the app, or the web app
  /// when it isn't installed. Both routes handle `/share`.
  static const String linkBase = 'https://schedule.rocisapps.com/share';

  /// Prefixes of QR codes made before https links; they still resolve.
  static const String legacyOfflineScheme = 'rocis://schedule/course';
  static const String legacyCloudScheme = 'rocis://schedule/cloud';
  static const int cloudTtlDays = 7;

  final FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CourseShareService({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  // ---------------------------------------------------------------------------
  // 1. OFFLINE ENCODING & DECODING
  // ---------------------------------------------------------------------------

  /// Compresses a [course] and its linked [events] into a compact offline QR payload.
  /// Format: `https://schedule.rocisapps.com/share?d=<BASE64URL_GZIP_JSON>`
  String generateOfflinePayload(Course course, List<ScheduleEvent> events) {
    final compactEvents = events.map((e) {
      return <String, dynamic>{
        't': e.title,
        'ty': e.type.index,
        'st': e.startTime.toIso8601String(),
        'et': e.endTime.toIso8601String(),
        if (e.location.trim().isNotEmpty) 'loc': e.location.trim(),
        if (e.daysOfWeek.isNotEmpty) 'dow': e.daysOfWeek,
        if (e.recurring) 'rec': 1,
        if (e.notes.trim().isNotEmpty) 'not': e.notes.trim(),
        if (e.domain != EventDomain.academic) 'dom': e.domain.name,
        if (e.color != null) 'col': e.color!.toARGB32(),
      };
    }).toList();

    final Map<String, dynamic> compact = {
      'v': 1,
      'n': course.name,
      'c': course.code,
      if (course.instructor.trim().isNotEmpty) 'ins': course.instructor.trim(),
      'col': course.color.toARGB32(),
      if (course.credits > 0) 'cr': course.credits,
      if (course.semester != null) 'sem': course.semester,
      if (compactEvents.isNotEmpty) 'ev': compactEvents,
    };

    final jsonStr = jsonEncode(compact);
    final compressedBytes = GZipEncoder().encodeBytes(utf8.encode(jsonStr));
    final b64 = base64Url.encode(compressedBytes);
    return '$linkBase?d=$b64';
  }

  /// Decodes raw query payload into a JSON map. Returns `null` if invalid.
  Map<String, dynamic>? decodeOfflinePayload(String rawUrlOrData) {
    try {
      String b64 = rawUrlOrData.trim();
      // Any link form: https://…/share?d=, /share?d= (router), rocis://…?d=
      if (b64.contains('?d=') || b64.contains('&d=')) {
        b64 = Uri.tryParse(b64)?.queryParameters['d'] ?? '';
      }
      if (b64.isEmpty) return null;

      final normalizedB64 = base64Url.normalize(b64);
      final compressedBytes = base64Url.decode(normalizedB64);
      final decompressedBytes = GZipDecoder().decodeBytes(compressedBytes);
      final jsonStr = utf8.decode(decompressedBytes);
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      debugPrint('CourseShareService.decodeOfflinePayload error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 2. CLOUD FIRESTORE SHARE (7-Day TTL)
  // ---------------------------------------------------------------------------

  /// Uploads a course and its events to Cloud Firestore under `/shared_courses/{shareId}`.
  /// Automatically marks `expiresAt` 7 days from now.
  Future<String> uploadCloudCourse(
    Course course,
    List<ScheduleEvent> events, {
    String? authorId,
  }) async {
    final shareId = const Uuid().v4().replaceAll('-', '').substring(0, 12);
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: cloudTtlDays));

    final docRef = _firestore.collection('shared_courses').doc(shareId);

    final payload = {
      'id': shareId,
      'createdAt': Timestamp.fromDate(now),
      // A Timestamp so the Firestore TTL policy on expiresAt deletes the doc.
      'expiresAt': Timestamp.fromDate(expiresAt),
      'authorId': authorId ?? FirebaseAuth.instance.currentUser?.uid,
      'course': course.toMap(),
      'events': events.map((e) => e.toMap()).toList(),
    };

    await docRef.set(payload);
    return '$linkBase?id=$shareId';
  }

  /// Fetches a cloud-shared course by [shareId].
  /// Returns `null` if document is missing or expired.
  Future<Map<String, dynamic>?> fetchCloudCourse(String shareId) async {
    final cleanId = shareId.trim();
    if (cleanId.isEmpty) return null;

    final docSnap = await _firestore
        .collection('shared_courses')
        .doc(cleanId)
        .get();
    if (!docSnap.exists || docSnap.data() == null) {
      return null;
    }

    final data = docSnap.data()!;
    final expiresAtRaw = data['expiresAt'];
    final expiresAt = expiresAtRaw is Timestamp
        ? expiresAtRaw.toDate()
        : expiresAtRaw is String
        ? DateTime.tryParse(expiresAtRaw)
        : null;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      return null; // Expired share
    }

    return data;
  }

  // ---------------------------------------------------------------------------
  // 3. UNIVERSAL RESOLVER & SANITIZATION
  // ---------------------------------------------------------------------------

  /// Identifies whether the string is offline or cloud, resolves data,
  /// generates fresh UUIDs to prevent ID collisions, and links events.
  Future<CourseShareData> resolveQrString(String rawUrl) async {
    final trimmed = rawUrl.trim();

    // Check Cloud Mode
    if (trimmed.startsWith(legacyCloudScheme) ||
        trimmed.contains('shared_courses') ||
        (trimmed.contains('?id=') && !trimmed.contains('?d='))) {
      final uri = Uri.tryParse(trimmed);
      final shareId =
          uri?.queryParameters['id'] ??
          (trimmed.contains('/') ? trimmed.split('/').last : trimmed);

      final cloudDoc = await fetchCloudCourse(shareId);
      if (cloudDoc == null) {
        throw StateError(
          'Course share link not found or has expired (7 days).',
        );
      }

      final rawCourse =
          cloudDoc['course'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final rawEvents =
          (cloudDoc['events'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          <Map<String, dynamic>>[];

      final (sanitizedCourse, sanitizedEvents) = _sanitizeCourseAndEvents(
        rawCourse,
        rawEvents,
      );

      return CourseShareData(
        course: sanitizedCourse,
        events: sanitizedEvents,
        isCloud: true,
        shareId: shareId,
      );
    }

    // Check Offline Direct Mode
    if (trimmed.startsWith(legacyOfflineScheme) || trimmed.contains('?d=')) {
      final decoded = decodeOfflinePayload(trimmed);
      if (decoded == null) {
        throw StateError('Invalid offline course QR code payload.');
      }

      final (sanitizedCourse, sanitizedEvents) =
          _sanitizeCompactCourseAndEvents(decoded);

      return CourseShareData(
        course: sanitizedCourse,
        events: sanitizedEvents,
        isCloud: false,
      );
    }

    // Try parsing as plain JSON directly
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is Map<String, dynamic>) {
        if (parsed.containsKey('course')) {
          final (c, ev) = _sanitizeCourseAndEvents(
            parsed['course'] as Map<String, dynamic>,
            (parsed['events'] as List<dynamic>?)
                    ?.whereType<Map<String, dynamic>>()
                    .toList() ??
                [],
          );
          return CourseShareData(course: c, events: ev, isCloud: false);
        } else if (parsed.containsKey('n') || parsed.containsKey('name')) {
          final (c, ev) = _sanitizeCompactCourseAndEvents(parsed);
          return CourseShareData(course: c, events: ev, isCloud: false);
        }
      }
    } catch (_) {}

    throw StateError('Unrecognized course QR code format.');
  }

  /// Sanitizes full Course and Events map (e.g. from cloud Firestore).
  (Course, List<ScheduleEvent>) _sanitizeCourseAndEvents(
    Map<String, dynamic> rawCourse,
    List<Map<String, dynamic>> rawEvents,
  ) {
    const uuid = Uuid();
    final newCourseId = uuid.v4();

    final baseCourse = Course.fromMap(rawCourse);
    final sanitizedCourse = baseCourse.copyWith(
      id: newCourseId,
      grade: null, // Clear grade on shared course
    );

    final sanitizedEvents = rawEvents.map((eMap) {
      final event = ScheduleEvent.fromMap(eMap);
      return ScheduleEvent(
        id: uuid.v4(),
        title: event.title,
        courseId: newCourseId,
        type: event.type,
        startTime: event.startTime,
        endTime: event.endTime,
        location: event.location,
        daysOfWeek: List<int>.from(event.daysOfWeek),
        recurring: event.recurring,
        notes: event.notes,
        domain: event.domain,
        color: sanitizedCourse.color,
      );
    }).toList();

    return (sanitizedCourse, sanitizedEvents);
  }

  /// Sanitizes compact Course and Events map (from offline direct QR).
  (Course, List<ScheduleEvent>) _sanitizeCompactCourseAndEvents(
    Map<String, dynamic> raw,
  ) {
    const uuid = Uuid();
    final newCourseId = uuid.v4();

    final name = (raw['n'] ?? raw['name'] ?? 'Untitled Course').toString();
    final code = (raw['c'] ?? raw['code'] ?? '').toString();
    final instructor = (raw['ins'] ?? raw['instructor'] ?? '').toString();

    Color color = Colors.blue;
    final rawColor = raw['col'] ?? raw['color'];
    if (rawColor is int) {
      color = Color(rawColor);
    } else if (rawColor is num) {
      color = Color(rawColor.toInt());
    }

    double credits = 0.0;
    final rawCred = raw['cr'] ?? raw['credits'];
    if (rawCred is num) {
      credits = rawCred.toDouble();
    }

    final semester = (raw['sem'] ?? raw['semester'] ?? 'semester_1').toString();

    final sanitizedCourse = Course(
      id: newCourseId,
      name: name,
      code: code,
      instructor: instructor,
      color: color,
      credits: credits,
      grade: null,
      semester: semester,
    );

    final rawEventsList = raw['ev'] ?? raw['events'];
    final List<ScheduleEvent> sanitizedEvents = [];

    if (rawEventsList is List) {
      for (final item in rawEventsList) {
        if (item is! Map<String, dynamic>) continue;

        final title = (item['t'] ?? item['title'] ?? name).toString();
        final typeIdx = item['ty'] ?? item['type'];
        EventType eventType = EventType.classType;
        if (typeIdx is int &&
            typeIdx >= 0 &&
            typeIdx < EventType.values.length) {
          eventType = EventType.values[typeIdx];
        }

        DateTime startTime = DateTime.now();
        final rawSt = item['st'] ?? item['startTime'];
        if (rawSt != null) {
          startTime = DateTime.tryParse(rawSt.toString()) ?? startTime;
        }

        DateTime endTime = startTime.add(const Duration(hours: 1, minutes: 30));
        final rawEt = item['et'] ?? item['endTime'];
        if (rawEt != null) {
          endTime = DateTime.tryParse(rawEt.toString()) ?? endTime;
        }

        final location = (item['loc'] ?? item['location'] ?? '').toString();

        List<int> daysOfWeek = [];
        final rawDow = item['dow'] ?? item['daysOfWeek'];
        if (rawDow is List) {
          daysOfWeek = rawDow.whereType<int>().toList();
        }

        final recurring =
            (item['rec'] ?? item['recurring']) == 1 ||
            (item['rec'] ?? item['recurring']) == true;
        final notes = (item['not'] ?? item['notes'] ?? '').toString();

        final domainStr = item['dom'] ?? item['domain'];
        final domain = EventDomain.fromString(domainStr?.toString());

        sanitizedEvents.add(
          ScheduleEvent(
            id: uuid.v4(),
            title: title,
            courseId: newCourseId,
            type: eventType,
            startTime: startTime,
            endTime: endTime,
            location: location,
            daysOfWeek: daysOfWeek,
            recurring: recurring,
            notes: notes,
            domain: domain,
            color: color,
          ),
        );
      }
    }

    return (sanitizedCourse, sanitizedEvents);
  }
}
