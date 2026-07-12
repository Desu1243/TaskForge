import 'package:flutter/material.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/themes/default_theme.dart';

class ToDosPage extends StatelessWidget {
  const ToDosPage({
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
            'No to-dos yet. Tap + to create one.',
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
          _TodoTile(task: tasks[index], onChanged: onChanged, onEdit: onEdit),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({
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
    final isCompleted = task.isCompleted;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: task.notes.isEmpty ? 72 : 88,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: isCompleted
                  ? colors.surfaceContainer
                  : DefaultTheme.yellow,
              child: InkWell(
                onTap: () {
                  task.isCompleted = !isCompleted;
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
                        color: isCompleted
                            ? DefaultTheme.gray
                            : DefaultTheme.darkYellow,
                        shape: BoxShape.circle,
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
                  child: Container(
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
                            color: isCompleted
                                ? colors.onSurfaceVariant.withValues(
                                    alpha: 0.65,
                                  )
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
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.75,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
