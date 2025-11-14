import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

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
        await db.execute('''
          CREATE TABLE subjects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            subject_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            status TEXT NOT NULL,
            FOREIGN KEY (subject_id) REFERENCES subjects (id)
          )
        ''');
      },
    );
  }

  Future<int> insertSubject(String name) async {
    final db = await database;
    return db.insert('subjects', {'name': name});
  }

  Future<List<Map<String, dynamic>>> getSubjects() async {
    final db = await database;
    return db.query('subjects');
  }

  Future<int> deleteSubject(int id) async {
    final db = await database;
    await db.delete('attendance', where: 'subject_id = ?', whereArgs: [id]);
    return db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertAttendance(int subjectId, String date, String status) async {
    final db = await database;
    return db.insert('attendance', {
      'subject_id': subjectId,
      'date': date,
      'status': status,
    });
  }

  Future<List<Map<String, dynamic>>> getAttendance(int subjectId) async {
    final db = await database;
    return db.query('attendance', where: 'subject_id = ?', whereArgs: [subjectId]);
  }

  Future<int> updateAttendance(int subjectId, String date, String status) async {
    final db = await database;
    return db.update(
      'attendance',
      {'status': status},
      where: 'subject_id = ? AND date = ?',
      whereArgs: [subjectId, date],
    );
  }
}