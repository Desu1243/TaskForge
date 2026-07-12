import 'package:flutter/material.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/themes/DefaultTheme.dart';

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
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return task.type == TaskType.habit
            ? _HabitTile(task: task, onChanged: onChanged)
            : _CheckableTaskTile(task: task, onChanged: onChanged);
      },
    );
  }
}

class _CheckableTaskTile extends StatelessWidget {
  const _CheckableTaskTile({required this.task, required this.onChanged});

  final Task task;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isTodo = task.type == TaskType.todo;
    final controlColor = task.isCompleted
        ? DefaultTheme.gray
        : DefaultTheme.yellow;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: task.notes.isEmpty ? 72 : 88,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: controlColor,
              child: InkWell(
                onTap: () {
                  task.isCompleted = !task.isCompleted;
                  onChanged();
                },
                child: SizedBox(
                  width: 52,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: task.isCompleted
                            ? DefaultTheme.gray
                            : DefaultTheme.darkYellow,
                        shape: isTodo ? BoxShape.circle : BoxShape.rectangle,
                        borderRadius: isTodo ? null : BorderRadius.circular(7),
                      ),
                      child: task.isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 19,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: DefaultTheme.darkPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: task.isCompleted
                            ? DefaultTheme.lightGray.withValues(alpha: 0.65)
                            : DefaultTheme.fullWhite,
                      ),
                    ),
                    if (task.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: DefaultTheme.lightGray.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.task, required this.onChanged});

  final Task task;
  final VoidCallback onChanged;

  Color get _statusColor {
    if (task.positiveCount > task.negativeCount) return DefaultTheme.green;
    if (task.positiveCount < task.negativeCount) return DefaultTheme.red;
    return DefaultTheme.yellow;
  }

  Color get _darkStatusColor {
    if (task.positiveCount > task.negativeCount) return DefaultTheme.darkGreen;
    if (task.positiveCount < task.negativeCount) return DefaultTheme.darkRed;
    return DefaultTheme.darkYellow;
  }

  @override
  Widget build(BuildContext context) {
    final counters =
        task.habitCounters ??
        const HabitCounters(positiveEnabled: true, negativeEnabled: true);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: task.notes.isEmpty ? 74 : 94,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HabitCounterButton(
              enabled: counters.positiveEnabled,
              color: _statusColor,
              iconColor: _darkStatusColor,
              icon: Icons.add,
              tooltip: 'Add positive point',
              onTap: () {
                task.positiveCount++;
                onChanged();
              },
            ),
            Expanded(
              child: Container(
                color: DefaultTheme.darkPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: DefaultTheme.fullWhite),
                    ),
                    if (task.notes.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: DefaultTheme.lightGray,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (task.positiveCount != 0 || task.negativeCount != 0) ...[
                      const SizedBox(height: 3),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '+${task.positiveCount} / -${task.negativeCount}',
                          style: TextStyle(
                            color: DefaultTheme.lightGray.withValues(
                              alpha: 0.65,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _HabitCounterButton(
              enabled: counters.negativeEnabled,
              color: _statusColor,
              iconColor: _darkStatusColor,
              icon: Icons.remove,
              tooltip: 'Add negative point',
              onTap: () {
                task.negativeCount++;
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCounterButton extends StatelessWidget {
  const _HabitCounterButton({
    required this.enabled,
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final bool enabled;
  final Color color;
  final Color iconColor;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? color : DefaultTheme.accentPurple,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 52,
            child: Center(
              child: Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: enabled ? iconColor : DefaultTheme.gray,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: DefaultTheme.fullWhite, size: 23),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
