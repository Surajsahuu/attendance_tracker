class Attendance {
  final int? id;
  final int subjectId;
  final DateTime date;
  final String status;

  Attendance({
    this.id,
    required this.subjectId,
    required this.date,
    required this.status,
  });

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'],
      subjectId: map['subject_id'],
      date: DateTime.parse(map['date']),
      status: map['status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'date': date.toIso8601String(),
      'status': status,
    };
  }
}
