import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject.dart';
import 'database_provider.dart';

// Provides the list of subjects with their stats
final subjectsProvider = AsyncNotifierProvider<SubjectsNotifier, List<Subject>>(
  SubjectsNotifier.new,
);

class SubjectsNotifier extends AsyncNotifier<List<Subject>> {
  @override
  Future<List<Subject>> build() async {
    return _loadSubjects();
  }

  Future<List<Subject>> _loadSubjects() async {
    final dbHelper = ref.read(databaseProvider);
    final subjectsData = await dbHelper.getSubjects();
    List<Subject> subjectsList = [];

    for (var subjectData in subjectsData) {
      final stats = await dbHelper.getAttendanceStats(subjectData['id']);

      final combinedData = Map<String, dynamic>.from(subjectData);
      combinedData['percentage'] = stats['percentage'] ?? 0;
      combinedData['total'] = stats['total'] ?? 0;

      subjectsList.add(Subject.fromMap(combinedData));
    }

    // Sort by order_index
    subjectsList.sort((a, b) {
      if (a.orderIndex != null && b.orderIndex != null) {
        return a.orderIndex!.compareTo(b.orderIndex!);
      }
      return 0;
    });

    return subjectsList;
  }

  Future<void> addSubject(String name) async {
    final dbHelper = ref.read(databaseProvider);

    // Check for duplicates locally first
    if (state.hasValue) {
      final currentList = state.value!;
      if (currentList.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
        throw SubjectException('The "$name" subject already exists');
      }
    }

    await dbHelper.insertSubject(name);

    state = await AsyncValue.guard(() async {
      return _loadSubjects();
    });
  }

  Future<void> deleteSubject(int id) async {
    final dbHelper = ref.read(databaseProvider);

    await dbHelper.deleteSubject(id);

    if (state.hasValue) {
      final currentList = state.value!;
      if (currentList.any((s) => s.id == id)) {
        final newList = List<Subject>.from(currentList)
          ..removeWhere((s) => s.id == id);
        state = AsyncValue.data(newList);
      }
    }
  }

  Future<void> updateSubject(int id, String newName) async {
    final dbHelper = ref.read(databaseProvider);

    // Check for duplicates locally first
    if (state.hasValue) {
      final currentList = state.value!;
      // Check if any OTHER subject has the same name
      if (currentList.any(
        (s) => s.id != id && s.name.toLowerCase() == newName.toLowerCase(),
      )) {
        throw SubjectException('The "$newName" subject already exists');
      }
    }
    await dbHelper.updateSubject(id, newName);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return _loadSubjects();
    });
  }

  Future<void> reorderSubjects(int oldIndex, int newIndex) async {
    final currentList = state.value;
    if (currentList == null) return;

    final newList = List<Subject>.from(currentList);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final subject = newList.removeAt(oldIndex);
    newList.insert(newIndex, subject);

    // Optimistically update state
    state = AsyncValue.data(newList);

    // Persist changes
    final dbHelper = ref.read(databaseProvider);
    final subjectsMapList = newList.map((s) => s.toMap()).toList();
    await dbHelper.updateSubjectOrder(subjectsMapList);
  }

  void removeLocally(int id) {
    if (!state.hasValue) return;
    final currentList = state.value!;
    final newList = List<Subject>.from(currentList)
      ..removeWhere((s) => s.id == id);
    state = AsyncValue.data(newList);
  }

  void restoreLocally(Subject subject, int index) {
    if (!state.hasValue) return;
    final currentList = state.value!;

    if (currentList.any((s) => s.id == subject.id)) return;

    final newList = List<Subject>.from(currentList);
    if (index >= 0 && index <= newList.length) {
      newList.insert(index, subject);
    } else {
      newList.add(subject);
    }
    state = AsyncValue.data(newList);
  }
}

class SubjectException implements Exception {
  final String message;
  SubjectException(this.message);
  @override
  String toString() => message;
}
