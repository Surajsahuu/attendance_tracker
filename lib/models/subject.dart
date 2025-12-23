class Subject {
  final int id;
  String name;
  int percentage;
  int total;
  final int? orderIndex;

  Subject({
    required this.id,
    required this.name,
    required this.percentage,
    required this.total,
    this.orderIndex,
  });

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'],
      name: map['name'],
      percentage: map['percentage'] ?? 0,
      total: map['total'] ?? 0,
      orderIndex: map['order_index'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'percentage': percentage,
      'total': total,
      'order_index': orderIndex,
    };
  }
}
