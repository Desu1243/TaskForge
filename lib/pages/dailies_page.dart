import 'package:flutter/material.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/themes/default_theme.dart';

class DailiesPage extends StatelessWidget {
  const DailiesPage({
    required this.tasks,
    required this.onChanged,
    required this.onEdit,
    super.key,
  });

  final List<Task> tasks;
  final ValueChanged<Task> onChanged;
  final ValueChanged<Task> onEdit;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            "You don't have any Dailies\nTap + to create one",
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
      itemBuilder: (context, index) =>
          _DailyTile(task: tasks[index], onChanged: onChanged, onEdit: onEdit),
    );
  }
}

class _DailyTile extends StatelessWidget {
  const _DailyTile({
    required this.task,
    required this.onChanged,
    required this.onEdit,
  });

  final Task task;
  final ValueChanged<Task> onChanged;
  final ValueChanged<Task> onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final isCompleted = task.isCompletedOn(today);
    final schedule = task.schedule;
    final isActiveToday =
        schedule is DailySchedule &&
        schedule.activeWeekdays.contains(today.weekday);
    final controlColor = isCompleted
        ? colors.surfaceContainer
        : isActiveToday
        ? DefaultTheme.yellow
        : DefaultTheme.gray;
    final checkboxColor = isCompleted
        ? DefaultTheme.gray
        : isActiveToday
        ? DefaultTheme.darkYellow
        : colors.surfaceContainerHigh;

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
                onTap: !isActiveToday
                    ? null
                    : () {
                        task.setCompletedOn(today, completed: !isCompleted);
                        onChanged(task);
                      },
                child: SizedBox(
                  width: 52,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(
                        color: checkboxColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: isCompleted
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
              child: Material(
                color: colors.surfaceContainer,
                child: InkWell(
                  onTap: () => onEdit(task),
                  child: _DailyContent(task: task, isCompleted: isCompleted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyContent extends StatelessWidget {
  const _DailyContent({required this.task, required this.isCompleted});

  final Task task;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              color: isCompleted
                  ? colors.onSurfaceVariant.withValues(alpha: 0.65)
                  : colors.onSurface,
            ),
          ),
          if (task.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
