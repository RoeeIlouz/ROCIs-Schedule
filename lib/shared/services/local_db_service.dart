import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:rocis_schedule/shared/models/schedule_models.dart';
import 'package:rocis_schedule/shared/models/assignment_model.dart';

class LocalDbService {
  final String userId;
  static Database? _database;
  static String? _currentUserId;

  LocalDbService(this.userId);

  Future<Database?> get database async {
    try {
      if (_database != null && _currentUserId == userId && _database!.isOpen) {
        return _database!;
      }
      if (_database != null && _database!.isOpen) {
        await _database!.close();
        _database = null;
      }
      _database = await _initDB();
      _currentUserId = userId;
      return _database;
    } catch (e) {
      debugPrint('LocalDbService: Error initializing database: $e');
      return null;
    }
  }

  Future<Database> _initDB() async {
    // Sanitize userId for filename
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final dbName = 'rocis_schedule_$safeUserId.db';
    final String path;
    if (kIsWeb) {
      path = dbName;
    } else {
      path = join(await getDatabasesPath(), dbName);
    }
    return await openDatabase(
      path,
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// Deletes [userId]'s database file (used once guest data has moved into a
  /// signed-in account).
  static Future<void> deleteDatabaseFor(String userId) async {
    try {
      if (_currentUserId == userId) await clearCache();
      final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final dbName = 'rocis_schedule_$safeUserId.db';
      await deleteDatabase(
        kIsWeb ? dbName : join(await getDatabasesPath(), dbName),
      );
    } catch (e) {
      debugPrint('LocalDbService: Error deleting $userId database: $e');
    }
  }

  static Future<void> clearCache() async {
    if (_database != null) {
      if (_database!.isOpen) {
        await _database!.close();
      }
      _database = null;
      _currentUserId = null;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAssignmentsTable(db);
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE courses ADD COLUMN grade REAL');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      await _createIndices(db);
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE courses ADD COLUMN semester TEXT');
      } catch (_) {}
      await _createSemestersTable(db);
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE events ADD COLUMN domain TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE events ADD COLUMN color INTEGER');
      } catch (_) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE courses(
        id TEXT PRIMARY KEY,
        name TEXT,
        code TEXT,
        instructor TEXT,
        color INTEGER,
        credits INTEGER,
        grade REAL,
        semester TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE events(
        id TEXT PRIMARY KEY,
        title TEXT,
        courseId TEXT,
        type INTEGER,
        startTime TEXT,
        endTime TEXT,
        location TEXT,
        daysOfWeek TEXT,
        recurring INTEGER,
        notes TEXT,
        domain TEXT,
        color INTEGER,
        FOREIGN KEY (courseId) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');

    await _createAssignmentsTable(db);
    await _createSemestersTable(db);
    await _createIndices(db);
  }

  Future<void> _createSemestersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS semesters(
        id TEXT PRIMARY KEY,
        name TEXT,
        startDate TEXT,
        endDate TEXT
      )
    ''');
  }

  Future<void> _createAssignmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE assignments(
        id TEXT PRIMARY KEY,
        courseId TEXT,
        title TEXT,
        description TEXT,
        dueDate TEXT,
        isCompleted INTEGER,
        priority INTEGER,
        FOREIGN KEY (courseId) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _createIndices(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_courseId ON events(courseId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_events_startTime ON events(startTime)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_assignments_courseId ON assignments(courseId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_assignments_dueDate ON assignments(dueDate)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_assignments_isCompleted ON assignments(isCompleted)',
    );
  }

  // Course CRUD
  Future<void> insertCourse(Course course) async {
    final db = await database;
    if (db == null) return;
    await db.insert(
      'courses',
      course.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Course>> getCourses() async {
    final db = await database;
    if (db == null) return [];
    final List<Map<String, dynamic>> maps = await db.query('courses');
    return List.generate(maps.length, (i) => Course.fromMap(maps[i]));
  }

  Future<void> deleteCourse(String id) async {
    final db = await database;
    if (db == null) return;
    await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  // Event CRUD
  Future<void> insertEvent(ScheduleEvent event) async {
    final db = await database;
    if (db == null) return;
    await db.insert(
      'events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ScheduleEvent>> getEvents() async {
    final db = await database;
    if (db == null) return [];
    final List<Map<String, dynamic>> maps = await db.query('events');
    return List.generate(maps.length, (i) => ScheduleEvent.fromMap(maps[i]));
  }

  Future<void> deleteEvent(String id) async {
    final db = await database;
    if (db == null) return;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  // Assignment CRUD
  Future<void> insertAssignment(Assignment assignment) async {
    final db = await database;
    if (db == null) return;
    await db.insert(
      'assignments',
      assignment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Assignment>> getAssignments() async {
    final db = await database;
    if (db == null) return [];
    final List<Map<String, dynamic>> maps = await db.query('assignments');
    return List.generate(maps.length, (i) => Assignment.fromMap(maps[i]));
  }

  Future<void> deleteAssignment(String id) async {
    final db = await database;
    if (db == null) return;
    await db.delete('assignments', where: 'id = ?', whereArgs: [id]);
  }

  // Semester CRUD
  Future<void> insertSemester(Semester semester) async {
    final db = await database;
    if (db == null) return;
    await db.insert(
      'semesters',
      semester.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Semester>> getSemesters() async {
    final db = await database;
    if (db == null) return [];
    final List<Map<String, dynamic>> maps = await db.query('semesters');
    return List.generate(maps.length, (i) => Semester.fromMap(maps[i]));
  }

  Future<void> deleteSemester(String id) async {
    final db = await database;
    if (db == null) return;
    await db.delete('semesters', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    if (db == null) return;
    await db.delete('assignments');
    await db.delete('events');
    await db.delete('courses');
    await db.delete('semesters');
  }
}
