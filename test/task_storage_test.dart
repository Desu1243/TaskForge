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

  test('saves a daily completion outside its schedule', () async {
    final directory = await Directory.systemTemp.createTemp('taskforge_test_');
    addTearDown(() => directory.delete(recursive: true));
    final storage = TaskStorage.forDirectory(directory);
    final unscheduledTuesday = DateTime(2026, 7, 14);
    final task = Task(
      id: 'daily-1',
      type: TaskType.daily,
      title: 'Weekly review',
      notes: '',
      schedule: const DailySchedule(activeWeekdays: {DateTime.monday}),
      createdAt: DateTime(2026, 7, 13),
    );

    task.setCompletedOn(unscheduledTuesday, completed: true);
    await storage.saveTask(task);
    final loaded = await storage.loadAll();
    final restored = loaded[TaskType.daily]!.single;

    expect(restored.isCompletedOn(unscheduledTuesday), isTrue);
    expect(restored.historyEntryOn(unscheduledTuesday), isNotNull);
    expect(restored.historyEntryOn(unscheduledTuesday)!.dailyCompleted, isTrue);
  });

  test('finds the most recent scheduled Daily occurrence', () {
    final task = Task(
      id: 'daily-schedule',
      type: TaskType.daily,
      title: 'Weekly review',
      notes: '',
      schedule: const DailySchedule(
        activeWeekdays: {DateTime.monday, DateTime.thursday},
      ),
      createdAt: DateTime(2026, 9, 1),
    );

    expect(
      task.mostRecentScheduledDateBefore(DateTime(2026, 9, 13)),
      DateTime(2026, 9, 10),
    );
    task.setCompletedOn(DateTime(2026, 9, 10), completed: true);
    expect(task.isCompletedOn(DateTime(2026, 9, 10)), isTrue);
  });

  test('does not find a scheduled occurrence from before task creation', () {
    final task = Task(
      id: 'new-daily',
      type: TaskType.daily,
      title: 'New Daily',
      notes: '',
      schedule: const DailySchedule(activeWeekdays: {DateTime.monday}),
      createdAt: DateTime(2026, 9, 8),
    );

    expect(task.mostRecentScheduledDateBefore(DateTime(2026, 9, 9)), isNull);
  });

  test(
    'saves To-do completion time and calculates auto-delete deadline',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'taskforge_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = TaskStorage.forDirectory(directory);
      final completedAt = DateTime(2026, 9, 12, 10);
      final task = Task(
        id: 'todo-1',
        type: TaskType.todo,
        title: 'Send report',
        notes: '',
        schedule: const TodoSchedule(),
      );

      task.setCompletedOn(completedAt, completed: true);
      await storage.saveTask(task);
      final loaded = await storage.loadAll();
      final restored = loaded[TaskType.todo]!.single;

      expect(restored.isCompleted, isTrue);
      expect(restored.completedAt, completedAt);
      expect(
        restored.shouldAutoDelete(
          completedAt.add(const Duration(hours: 23)),
          const Duration(hours: 24),
        ),
        isFalse,
      );
      expect(
        restored.shouldAutoDelete(
          completedAt.add(const Duration(hours: 24)),
          const Duration(hours: 24),
        ),
        isTrue,
      );

      restored.setCompletedOn(DateTime.now(), completed: false);
      expect(restored.completedAt, isNull);
    },
  );
}
