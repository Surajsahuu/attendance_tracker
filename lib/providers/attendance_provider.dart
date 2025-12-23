import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import '../database_helper.dart';

// Repository to handle DB operations
class AttendanceRepository {
  final DatabaseHelper dbHelper;
  final int subjectId;

  AttendanceRepository(this.dbHelper, this.subjectId);

  Future<Map<DateTime, String>> getAttendance() async {
    final attendanceRecords = await dbHelper.getAttendance(subjectId);
    final Map<DateTime, String> attendance = {};

    for (var record in attendanceRecords) {
      final date = DateTime.parse(record['date'] as String);
      final utcDate = DateTime.utc(date.year, date.month, date.day);
      attendance[utcDate] = record['status'] as String;
    }
    return attendance;
  }

  Future<void> markAttendance(String dateStr, String status) async {
    final rows = await dbHelper.updateAttendance(subjectId, dateStr, status);
    if (rows == 0) {
      await dbHelper.insertAttendance(subjectId, dateStr, status);
    }
  }

  Future<void> deleteAttendance(String dateStr) async {
    await dbHelper.deleteAttendance(subjectId, dateStr);
  }
}

// Provider for the repository
final attendanceRepositoryProvider = Provider.family<AttendanceRepository, int>(
  (ref, subjectId) {
    final dbHelper = ref.watch(databaseProvider);
    return AttendanceRepository(dbHelper, subjectId);
  },
);

// Provider for the attendance data
final attendanceProvider = FutureProvider.family<Map<DateTime, String>, int>((
  ref,
  subjectId,
) async {
  final repo = ref.watch(attendanceRepositoryProvider(subjectId));
  return repo.getAttendance();
});

// Provider for stats
final attendanceStatsProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, subjectId) async {
      ref.watch(attendanceProvider(subjectId));

      final dbHelper = ref.watch(databaseProvider);
      return dbHelper.getAttendanceStats(subjectId);
    });
