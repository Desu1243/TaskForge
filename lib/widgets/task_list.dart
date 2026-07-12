import 'package:flutter/material.dart';
import 'package:taskforge/models/task.dart';

class TaskList extends StatelessWidget {
  const TaskList({
    required this.tasks,
    required this.emptyLabel,
    required this.onChanged,
    super.key,
  });

  final List<Task> tasks;
  final String emptyLabel;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 96),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Card(
          child: CheckboxListTile(
            value: task.isCompleted,
            onChanged: (value) {
              task.isCompleted = value ?? false;
              onChanged();
            },
            title: Text(task.title),
            subtitle: task.notes.isEmpty ? null : Text(task.notes),
            secondary: Icon(_iconFor(task.type)),
          ),
        );
      },
    );
  }

  IconData _iconFor(TaskType type) => switch (type) {
    TaskType.habit => Icons.add_box_outlined,
    TaskType.daily => Icons.calendar_month_outlined,
    TaskType.todo => Icons.check_circle_outline,
  };
}
