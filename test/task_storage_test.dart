import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/services/task_storage.dart';

void main() {
  test('saves and restores a task with its history', () async {
    final directory = await Directory.systemTemp.createTemp('taskforge_test_');
    addTearDown(() => directory.delete(recursive: true));
    final storage = TaskStorage.forDirectory(directory);
    final createdAt = DateTime.now();
    final task = Task(
      id: 'habit-1',
      type: TaskType.habit,
      title: 'Exercise',
      notes: 'Thirty minutes',
      schedule: const HabitSchedule(
        activeWeekdays: {1, 3, 5},
        targetCount: 3,
        period: HabitPeriod.week,
      ),
      habitCounters: const HabitCounters(
        positiveEnabled: true,
        negativeEnabled: true,
      ),
      reminder: const TaskReminder(
        time: ReminderTime(hour: 18, minute: 30),
        title: 'Exercise',
        message: 'Time to move',
        activeWeekdays: {1, 3, 5},
      ),
      createdAt: createdAt,
    );
    task.addHabitPoint(createdAt, positive: true);
    task.addHabitPoint(createdAt, positive: false);

    await storage.saveTask(task);
    final loaded = await storage.loadAll();
    final restored = loaded[TaskType.habit]!.single;

    expect(restored.id, task.id);
    expect(restored.title, task.title);
    expect(restored.createdAt, createdAt);
    expect(restored.positiveCount, 1);
    expect(restored.negativeCount, 1);
    expect(restored.history, hasLength(1));
    expect(restored.history.single.positiveCount, 1);
    expect(restored.history.single.negativeCount, 1);
    expect((restored.schedule as HabitSchedule).activeWeekdays, {1, 3, 5});
    expect(restored.reminder!.time.hour, 18);

    await storage.deleteTask(restored);
    final afterDelete = await storage.loadAll();
    expect(afterDelete[TaskType.habit], isEmpty);
  });

  test('editing today counters corrects totals and daily history', () {
    final task = Task(
      id: 'habit-2',
      type: TaskType.habit,
      title: 'Read',
      notes: '',
      schedule: const HabitSchedule(
        activeWeekdays: {1, 2, 3, 4, 5, 6, 7},
        targetCount: 1,
        period: HabitPeriod.day,
      ),
    );
    final today = DateTime(2026, 7, 12);
    task.addHabitPoint(today, positive: true);
    task.addHabitPoint(today, positive: false);

    task.setHabitPointsForDate(today, positive: 2, negative: 0);

    expect(task.positiveCount, 2);
    expect(task.negativeCount, 0);
    expect(task.historyEntryOn(today)!.positiveCount, 2);
    expect(task.historyEntryOn(today)!.negativeCount, 0);
  });
}
