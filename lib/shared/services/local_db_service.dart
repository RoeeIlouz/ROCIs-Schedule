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
      return null;
    }
  }

  Future<Database> _initDB() async {
    // Sanitize userId for filename
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    String path = join(
      await getDatabasesPath(),
      'rocis_schedule_$safeUserId.db',
    );
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
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
        grade REAL
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
        FOREIGN KEY (courseId) REFERENCES courses (id) ON DELETE CASCADE
      )
    ''');

    await _createAssignmentsTable(db);
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
}
