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
      _subjects.addAll(subjects);
    });
  }

  Future<void> _addSubject(String name) async {
    final id = await _dbHelper.insertSubject(name);
    setState(() {
      _subjects.add({'id': id, 'name': name});
    });
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

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    final attendanceRecords = await _dbHelper.getAttendance(widget.subjectId);
    setState(() {
      for (var record in attendanceRecords) {
        _attendance[DateTime.parse(record['date'])] = record['status'];
      }
    });
  }

  Future<void> _updateAttendance(String status) async {
    if (_selectedDay != null) {
      final date = _selectedDay!.toIso8601String().split('T')[0];
      await _dbHelper.updateAttendance(widget.subjectId, date, status);
      setState(() {
        _attendance[_selectedDay!] = status;
      });
    }
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
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  if (_attendance[day] == 'Present') {
                    return Container(
                      margin: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
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
                  } else if (_attendance[day] == 'Absent') {
                    return Container(
                      margin: const EdgeInsets.all(6.0),
                      decoration: BoxDecoration(
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
                formatButtonVisible: false, // Hides the 2-week toggle button
              ),
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month', // Only show the month view
              },
            ),
            const SizedBox(height: 16),
            if (_selectedDay != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Date: ${_selectedDay!.toLocal()}'.split(' ')[0],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          backgroundColor: _attendance[_selectedDay!] == 'Present'
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
                          backgroundColor: _attendance[_selectedDay!] == 'Absent'
                              ? Colors.red
                              : Colors.grey,
                        ),
                        child: const Text('Absent'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${_attendance[_selectedDay!] ?? 'Not Set'}',
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
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SubjectCard({required this.name, required this.onDelete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: double.infinity, // Full width
          height: 100, // Fixed height
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
                  if (value == 'delete') {
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
                    value: 'delete',
                    child: Text('Delete'),
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
