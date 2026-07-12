import 'package:flutter/material.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/widgets/task_list.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({required this.tasks, required this.onChanged, super.key});

  final List<Task> tasks;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TaskList(
      tasks: tasks,
      emptyLabel: 'No habits yet. Tap + to create one.',
      onChanged: onChanged,
    );
  }
}
