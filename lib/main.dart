import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'database_helper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
        home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> _subjects = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final subjects = await _dbHelper.getSubjects();
    setState(() {
      _subjects.clear();
      _subjects.addAll(subjects);
    });
  }

  Future<void> _addSubject(String name) async {
    final id = await _dbHelper.insertSubject(name);
    setState(() {
      _subjects.add({'id': id, 'name': name});
    });
  }
  Future<void> _editSubject(int id, String currentName) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        String input = currentName;
        return AlertDialog(
          title: const Text('Edit Subject'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter new subject name',
            ),
            controller: TextEditingController(text: currentName),
            onChanged: (v) => input = v,
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(input.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  if (newName != null && newName.isNotEmpty && newName != currentName) {
      try {
        await _dbHelper.updateSubject(id, newName);
        setState(() {
          final subjectIndex = _subjects.indexWhere((subject) => subject['id'] == id);
          if (subjectIndex != -1) {
            _subjects[subjectIndex]['name'] = newName;
          }
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subject renamed to "$newName"'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }  
  Future<void> _deleteSubject(int id) async {
    await _dbHelper.deleteSubject(id);
    setState(() {
      _subjects.removeWhere((subject) => subject['id'] == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subjects',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final name = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        String input = '';
                        return AlertDialog(
                          title: const Text('Add Subject'),
                          content: TextField(
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Enter subject name',
                            ),
                            onChanged: (v) => input = v,
                            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(input.trim()),
                              child: const Text('Add'),
                            ),
                          ],
                        );
                      },
                    );

                    if (name != null && name.isNotEmpty) {
                      await _addSubject(name);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Subject'),
                )
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _subjects.isEmpty
                  ? Center(
                      child: Text(
                        'No subjects yet. Tap "Add Subject" to create one.',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: _subjects.length,
                      itemBuilder: (context, index) {
                        final subject = _subjects[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: _SubjectCard(
                            name: subject['name'],
                            onEdit: () async {
                              await _editSubject(subject['id'], subject['name']);
                            },
                            onDelete: () async {
                              await _deleteSubject(subject['id']);
                            },
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => SubjectCalendarPage(
                                    subjectId: subject['id'],
                                    subjectName: subject['name'],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubjectCalendarPage extends StatefulWidget {
  final int subjectId;
  final String subjectName;

  const SubjectCalendarPage({
    required this.subjectId,
    required this.subjectName,
    super.key,
  });

  @override
  State<SubjectCalendarPage> createState() => _SubjectCalendarPageState();
}

class _SubjectCalendarPageState extends State<SubjectCalendarPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final Map<DateTime, String> _attendance = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Add these new variables for statistics
  int _totalClasses = 0;
  int _presentClasses = 0;
  int _absentClasses = 0;
  double _attendancePercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
    _loadAttendanceStats(); // Load statistics when page loads
  }

  // Add this new method to load statistics
  Future<void> _loadAttendanceStats() async {
    final stats = await _dbHelper.getAttendanceStats(widget.subjectId);
    setState(() {
      _totalClasses = stats['total'] ?? 0;
      _presentClasses = stats['present'] ?? 0;
      _absentClasses = stats['absent'] ?? 0;
      _attendancePercentage = (stats['percentage'] ?? 0).toDouble();
    });
  }

  Future<void> _loadAttendance() async {
    final attendanceRecords = await _dbHelper.getAttendance(widget.subjectId);
    setState(() {
      _attendance.clear();
      for (var record in attendanceRecords) {
        final date = DateTime.parse(record['date'] as String);
        final utcDate = DateTime.utc(date.year, date.month, date.day);
        _attendance[utcDate] = record['status'] as String;
      }
    });
    
    // Also reload stats when attendance data changes
    await _loadAttendanceStats();
  }

  Future<void> _updateAttendance(String status) async {
    if (_selectedDay != null) {
      final utcDate = DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      final date = utcDate.toIso8601String().split('T')[0];
      final currentStatus = _attendance[utcDate];

      if (currentStatus == status) {
        await _dbHelper.deleteAttendance(widget.subjectId, date);
      } else {
        final rowsAffected = await _dbHelper.updateAttendance(widget.subjectId, date, status);
        if (rowsAffected == 0) {
          await _dbHelper.insertAttendance(widget.subjectId, date, status);
        }
      }
      
      await _loadAttendance(); // This will also reload stats
    }
  }

  // Add this method to build the statistics widget
  Widget _buildAttendanceStats() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', '$_totalClasses', Colors.blue),
                _buildStatItem('Present', '$_presentClasses', Colors.green),
                _buildStatItem('Absent', '$_absentClasses', Colors.red),
                _buildStatItem('Percentage', '${_attendancePercentage.round()}%', 
                    _getPercentageColor(_attendancePercentage)),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar for visual representation
            LinearProgressIndicator(
              value: _attendancePercentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getPercentageColor(_attendancePercentage),
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subjectName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                  final attendanceStatus = _attendance[utcDate];

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
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
              ),
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
              },
            ),
            const SizedBox(height: 16),
            
            // Add the statistics card here
            _buildAttendanceStats(),
            
            const SizedBox(height: 16),
            if (_selectedDay != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Date: ${_selectedDay!.toLocal()}'.split(' ')[0],
                    style: const TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await _updateAttendance('Present');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _attendance[DateTime.utc(
                                      _selectedDay!.year,
                                      _selectedDay!.month,
                                      _selectedDay!.day)] ==
                                  'Present'
                              ? Colors.green
                              : Colors.grey,
                        ),
                        child: const Text('Present'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await _updateAttendance('Absent');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _attendance[DateTime.utc(
                                      _selectedDay!.year,
                                      _selectedDay!.month,
                                      _selectedDay!.day)] ==
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
                    'Status: ${_attendance[DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day)] ?? 'Not Set'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final String name;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.name, 
    required this.onEdit, 
    required this.onDelete, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 100,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Deletion'),
                        content: Text('Are you sure you want to delete "$name"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      onDelete();
                    }
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.deepPurpleAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedDay != null)
              Text(
                'Selected Date: ${_selectedDay!.toLocal()}'.split(' ')[0],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
