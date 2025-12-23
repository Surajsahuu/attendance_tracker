import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/attendance_provider.dart';

class SubjectCalendarPage extends ConsumerStatefulWidget {
  final int subjectId;
  final String subjectName;

  const SubjectCalendarPage({
    required this.subjectId,
    required this.subjectName,
    super.key,
  });

  @override
  ConsumerState<SubjectCalendarPage> createState() =>
      _SubjectCalendarPageState();
}

class _SubjectCalendarPageState extends ConsumerState<SubjectCalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Future<void> _updateAttendance(
    Map<DateTime, String> attendance,
    String status,
  ) async {
    if (_selectedDay != null) {
      final utcDate = DateTime.utc(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
      );
      final dateStr = utcDate.toIso8601String().split('T')[0];
      final currentStatus = attendance[utcDate];

      final repo = ref.read(attendanceRepositoryProvider(widget.subjectId));

      try {
        if (currentStatus == status) {
          await repo.deleteAttendance(dateStr);
        } else {
          await repo.markAttendance(dateStr, status);
        }
        // Force refresh
        ref.invalidate(attendanceProvider(widget.subjectId));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Widget _buildAttendanceStats(AsyncValue<Map<String, dynamic>> statsAsync) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            statsAsync.when(
              data: (stats) {
                final total = stats['total'] ?? 0;
                final present = stats['present'] ?? 0;
                final absent = stats['absent'] ?? 0;
                final percentage = (stats['percentage'] ?? 0).toDouble();

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Total', '$total', Colors.blue),
                        _buildStatItem('Present', '$present', Colors.green),
                        _buildStatItem('Absent', '$absent', Colors.red),
                        _buildStatItem(
                          'Percentage',
                          '${percentage.round()}%',
                          _getPercentageColor(percentage),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getPercentageColor(percentage),
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: LinearProgressIndicator()),
              error: (e, s) => Text('Error loading stats: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 75) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(attendanceProvider(widget.subjectId));
    final statsAsync = ref.watch(attendanceStatsProvider(widget.subjectId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: attendanceAsync.when(
          data: (attendance) => Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2025, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final utcDate = DateTime.utc(day.year, day.month, day.day);
                    final attendanceStatus = attendance[utcDate];

                    if (attendanceStatus == 'Present') {
                      return Container(
                        margin: const EdgeInsets.all(6.0),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    } else if (attendanceStatus == 'Absent') {
                      return Container(
                        margin: const EdgeInsets.all(6.0),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
                headerStyle: const HeaderStyle(formatButtonVisible: false),
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
              ),
              const SizedBox(height: 16),
              _buildAttendanceStats(statsAsync),
              const SizedBox(height: 16),
              if (_selectedDay != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Date: ${_selectedDay!.toLocal()}'.split(' ')[0],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              _updateAttendance(attendance, 'Present'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                attendance[DateTime.utc(
                                      _selectedDay!.year,
                                      _selectedDay!.month,
                                      _selectedDay!.day,
                                    )] ==
                                    'Present'
                                ? Colors.green
                                : Colors.grey,
                          ),
                          child: const Text('Present'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              _updateAttendance(attendance, 'Absent'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                attendance[DateTime.utc(
                                      _selectedDay!.year,
                                      _selectedDay!.month,
                                      _selectedDay!.day,
                                    )] ==
                                    'Absent'
                                ? Colors.red
                                : Colors.grey,
                          ),
                          child: const Text('Absent'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${attendance[DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] ?? 'Not Set'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
