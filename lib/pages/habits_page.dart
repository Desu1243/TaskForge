import 'package:flutter/material.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/themes/default_theme.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({
    required this.tasks,
    required this.onChanged,
    required this.onEdit,
    super.key,
  });

  final List<Task> tasks;
  final VoidCallback onChanged;
  final ValueChanged<Task> onEdit;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No habits yet. Tap + to create one.',
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
          _HabitTile(task: tasks[index], onChanged: onChanged, onEdit: onEdit),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({
    required this.task,
    required this.onChanged,
    required this.onEdit,
  });

  final Task task;
  final VoidCallback onChanged;
  final ValueChanged<Task> onEdit;

  Color _statusColor(HabitCounters counters) {
    final positive = counters.positiveEnabled ? task.positiveCount : 0;
    final negative = counters.negativeEnabled ? task.negativeCount : 0;
    if (positive > negative) return DefaultTheme.green;
    if (positive < negative) return DefaultTheme.red;
    return DefaultTheme.yellow;
  }

  Color _darkStatusColor(HabitCounters counters) {
    final positive = counters.positiveEnabled ? task.positiveCount : 0;
    final negative = counters.negativeEnabled ? task.negativeCount : 0;
    if (positive > negative) return DefaultTheme.darkGreen;
    if (positive < negative) return DefaultTheme.darkRed;
    return DefaultTheme.darkYellow;
  }

  String _counterLabel(HabitCounters counters) {
    if (counters.positiveEnabled && counters.negativeEnabled) {
      return '+${task.positiveCount} | -${task.negativeCount}';
    }
    if (counters.positiveEnabled) return '+${task.positiveCount}';
    return '-${task.negativeCount}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final counters =
        task.habitCounters ??
        const HabitCounters(positiveEnabled: true, negativeEnabled: true);
    final hasCounterValue =
        (counters.positiveEnabled && task.positiveCount != 0) ||
        (counters.negativeEnabled && task.negativeCount != 0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: task.notes.isEmpty ? 74 : 94,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HabitCounterButton(
              enabled: counters.positiveEnabled,
              color: _statusColor(counters),
              iconColor: _darkStatusColor(counters),
              icon: Icons.add,
              tooltip: 'Add positive point',
              onTap: () {
                task.addHabitPoint(DateTime.now(), positive: true);
                onChanged();
              },
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onSurface),
                        ),
                        if (task.notes.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            task.notes,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        if (hasCounterValue) ...[
                          const SizedBox(height: 3),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _counterLabel(counters),
                              style: TextStyle(
                                color: colors.onSurfaceVariant.withValues(
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
              ),
            ),
            _HabitCounterButton(
              enabled: counters.negativeEnabled,
              color: _statusColor(counters),
              iconColor: _darkStatusColor(counters),
              icon: Icons.remove,
              tooltip: 'Add negative point',
              onTap: () {
                task.addHabitPoint(DateTime.now(), positive: false);
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
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? color : colors.surfaceContainerHigh,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 52,
            child: Center(
              child: Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: enabled ? iconColor : colors.outline,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: enabled ? Colors.white : colors.onSurfaceVariant,
                  size: 23,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
