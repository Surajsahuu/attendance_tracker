import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject.dart';
import '../providers/subjects_provider.dart';
import '../widgets/subject_card.dart';
import 'subject_calendar_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _addSubject(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        String input = '';
        return AlertDialog(
          title: const Text('Add Subject'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter subject name'),
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
      try {
        await ref.read(subjectsProvider.notifier).addSubject(name);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editSubject(
    BuildContext context,
    WidgetRef ref,
    int id,
    String currentName,
  ) async {
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
        await ref.read(subjectsProvider.notifier).updateSubject(id, newName);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subject renamed to "$newName"'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _deleteSubject(BuildContext context, WidgetRef ref, Subject subject) {
    // Capture the messenger before any async gaps or context invalidation
    final messenger = ScaffoldMessenger.of(context);

    final subNotifier = ref.read(subjectsProvider.notifier);
    final subjectsList = ref.read(subjectsProvider).value ?? [];
    final index = subjectsList.indexWhere((s) => s.id == subject.id);

    if (index == -1) return;

    // Optimistically remove from UI
    subNotifier.removeLocally(subject.id);

    // clear any previous snackbars
    messenger.clearSnackBars();

    // Variable to track if undo was performed
    bool undoPerformed = false;

    // Start a timer for 4 seconds to permanently delete
    final Timer deleteTimer = Timer(const Duration(seconds: 4), () {
      if (!undoPerformed) {
        subNotifier.deleteSubject(subject.id);
        if (messenger.mounted) {
          // Force hide the snackbar if it's still visible for some reason
          messenger.hideCurrentSnackBar();
        }
      }
    });

    final snackBar = SnackBar(
      content: Text(
        '"${subject.name}" deleted',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.grey[900],
      duration: const Duration(seconds: 4), // Matches timer
      action: SnackBarAction(
        label: 'Undo',
        textColor: Colors.white,
        onPressed: () {
          undoPerformed = true;
          deleteTimer.cancel(); // Cancel the permanent delete
          subNotifier.restoreLocally(subject, index); // Restore to UI
          if (messenger.mounted) {
            messenger.hideCurrentSnackBar(); // Hide immediately
          }
        },
      ),
    );

    messenger.showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Attendance Tracker',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
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
                  onPressed: () => _addSubject(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Subject'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: subjectsAsync.when(
                data: (subjects) {
                  if (subjects.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No subjects yet.\nTap "Add Subject" to create one.',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return ReorderableListView.builder(
                    itemCount: subjects.length,
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(subjectsProvider.notifier)
                          .reorderSubjects(oldIndex, newIndex);
                    },
                    itemBuilder: (itemContext, index) {
                      final subject = subjects[index];
                      return Padding(
                        key: ValueKey(subject.id),
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: SubjectCard(
                          subject: subject,
                          onEdit: () => _editSubject(
                            context,
                            ref,
                            subject.id,
                            subject.name,
                          ),
                          onDelete: () => _deleteSubject(context, ref, subject),
                          onNavigate: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => SubjectCalendarPage(
                                  subjectId: subject.id,
                                  subjectName: subject.name,
                                ),
                              ),
                            );
                            ref.invalidate(subjectsProvider);
                          },
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
