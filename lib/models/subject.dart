class Subject {
  final int id;
  String name;
  double percentage;
  int total;
  int present;
  int absent;
  final int? orderIndex;

  Subject({
    required this.id,
    required this.name,
    required this.percentage,
    required this.total,
    required this.present,
    required this.absent,
    this.orderIndex,
  });

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'],
      name: map['name'],
      percentage: (map['percentage'] ?? 0).toDouble(),
      total: map['total'] ?? 0,
      present: map['present'] ?? 0,
      absent: map['absent'] ?? 0,
      orderIndex: map['order_index'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'percentage': percentage,
      'total': total,
      'present': present,
      'absent': absent,
      'order_index': orderIndex,
    };
  }
}
