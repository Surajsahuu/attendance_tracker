import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:logging/logging.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  static final Logger _logger = Logger('DatabaseHelper');

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendance_tracker.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER DEFAULT 0, 
        order_index INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE,
        UNIQUE(subject_id, date)
      )
    ''');
  }

  Future<int> insertSubject(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Subject name cannot be empty');
    }

    if (trimmedName.length > 50) {
      throw ArgumentError('Subject name is too long (max 50 characters)');
    }

    final db = await database;

    final existing = await db.query(
      'subjects',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [trimmedName],
    );

    if (existing.isNotEmpty) {
      throw Exception('Subject "$trimmedName" already exists');
    }

    // Get the current maximum order_index to determine the new subject's position
    final result = await db.rawQuery(
      'SELECT MAX(order_index) as maxIndex FROM subjects',
    );
    int nextOrderIndex = 0;
    if (result.first['maxIndex'] != null) {
      nextOrderIndex = (result.first['maxIndex'] as int) + 1;
    }

    return db.insert('subjects', {
      'name': trimmedName,
      'order_index': nextOrderIndex,
    });
  }

  Future<List<Map<String, dynamic>>> getSubjects() async {
    final db = await database;
    return db.query('subjects');
  }

  Future<List<Map<String, dynamic>>> getSubjectsWithStats() async {
    final db = await database;
    return db.rawQuery('''
      SELECT 
        s.id, 
        s.name, 
        s.color, 
        s.order_index, 
        s.created_at,
        COUNT(a.id) as total,
        SUM(CASE WHEN a.status = 'Present' THEN 1 ELSE 0 END) as present
      FROM subjects s
      LEFT JOIN attendance a ON s.id = a.subject_id
      GROUP BY s.id
    ''');
  }

  Future<int> deleteSubject(int id) async {
    final db = await database;
    await db.delete('attendance', where: 'subject_id = ?', whereArgs: [id]);
    return db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertAttendance(
    int subjectId,
    String date,
    String status,
  ) async {
    if (status != 'Present' && status != 'Absent') {
      throw ArgumentError('Status must be "Present" or "Absent"');
    }

    try {
      DateTime.parse(date);
    } catch (e) {
      throw FormatException('Invalid date format: $date');
    }

    final db = await database;
    final result = await db.insert('attendance', {
      'subject_id': subjectId,
      'date': date,
      'status': status,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    _logger.info(
      'Inserted attendance: {subject_id: $subjectId, date: $date, status: $status}',
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> getAttendance(int subjectId) async {
    final db = await database;
    final records = await db.query(
      'attendance',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
    );

    _logger.info(
      'Retrieved attendance records for subject $subjectId: $records',
    );

    for (var record in records) {
      try {
        DateTime.parse(record['date'] as String);
      } catch (e) {
        _logger.severe('Invalid date format in database: ${record['date']}');
        throw FormatException(
          'Invalid date format in database: ${record['date']}',
        );
      }
    }

    return records;
  }

  Future<int> updateAttendance(
    int subjectId,
    String date,
    String status,
  ) async {
    final db = await database;
    final result = await db.update(
      'attendance',
      {'status': status},
      where: 'subject_id = ? AND date = ?',
      whereArgs: [subjectId, date],
    );

    _logger.info(
      'Updated attendance: {subject_id: $subjectId, date: $date, status: $status}',
    );
    return result;
  }

  Future<int> deleteAttendance(int subjectId, String date) async {
    final db = await database;
    final result = await db.delete(
      'attendance',
      where: 'subject_id = ? AND date = ?',
      whereArgs: [subjectId, date],
    );

    _logger.info('Deleted attendance: {subject_id: $subjectId, date: $date}');
    return result;
  }

  Future<Map<String, dynamic>> getAttendanceStats(int subjectId) async {
    final db = await database;
    final records = await db.query(
      'attendance',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
    );

    final total = records.length;
    final present = records.where((r) => r['status'] == 'Present').length;
    final absent = total - present;
    final percentage = total > 0 ? (present / total * 100) : 0;

    return {
      'total': total,
      'present': present,
      'absent': absent,
      'percentage': percentage,
    };
  }

  Future<int> updateSubject(int id, String newName) async {
    // Input validation
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Subject name cannot be empty');
    }

    if (trimmedName.length > 18) {
      throw ArgumentError('Subject name is too long (max 18 characters)');
    }

    final db = await database;

    // Check for duplicate subject names (excluding the current subject)
    final existing = await db.query(
      'subjects',
      where: 'LOWER(name) = LOWER(?) AND id != ?',
      whereArgs: [trimmedName, id],
    );

    if (existing.isNotEmpty) {
      throw Exception('Subject "$trimmedName" already exists');
    }

    return db.update(
      'subjects',
      {'name': trimmedName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSubjectOrder(List<Map<String, dynamic>> subjects) async {
    final db = await database;
    final batch = db.batch();

    for (int i = 0; i < subjects.length; i++) {
      batch.update(
        'subjects',
        {'order_index': i},
        where: 'id = ?',
        whereArgs: [subjects[i]['id']],
      );
    }

    await batch.commit(noResult: true);
  }
}
