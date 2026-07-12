enum TaskType { habit, daily, todo }

enum HabitPeriod { day, week, month }

class ReminderTime {
  const ReminderTime({required this.hour, required this.minute});

  final int hour;
  final int minute;
}

class TaskReminder {
  const TaskReminder({
    required this.time,
    required this.title,
    required this.message,
    this.activeWeekdays,
  });

  final ReminderTime time;
  final String title;
  final String message;
  final Set<int>? activeWeekdays;
}

sealed class TaskSchedule {
  const TaskSchedule();
}

class TodoSchedule extends TaskSchedule {
  const TodoSchedule({this.dueDate});

  final DateTime? dueDate;
}

class DailySchedule extends TaskSchedule {
  const DailySchedule({required this.activeWeekdays});

  final Set<int> activeWeekdays;
}

class HabitSchedule extends TaskSchedule {
  const HabitSchedule({
    required this.activeWeekdays,
    required this.targetCount,
    required this.period,
  });

  final Set<int> activeWeekdays;
  final int targetCount;
  final HabitPeriod period;
}

class HabitCounters {
  const HabitCounters({
    required this.positiveEnabled,
    required this.negativeEnabled,
  });

  final bool positiveEnabled;
  final bool negativeEnabled;
}

class TaskHistoryEntry {
  TaskHistoryEntry({
    required this.date,
    this.positiveCount = 0,
    this.negativeCount = 0,
    this.dailyCompleted = false,
  });

  final DateTime date;
  int positiveCount;
  int negativeCount;
  bool dailyCompleted;
}

class Task {
  Task({
    required this.id,
    required this.type,
    required this.title,
    required this.notes,
    required this.schedule,
    this.reminder,
    this.habitCounters,
    this.isCompleted = false,
    this.lastCompletedDate,
    this.positiveCount = 0,
    this.negativeCount = 0,
    DateTime? createdAt,
    List<TaskHistoryEntry>? history,
  }) : createdAt = createdAt ?? DateTime.now(),
       history = history ?? [];

  final String id;
  final TaskType type;
  final String title;
  final String notes;
  final TaskSchedule schedule;
  final TaskReminder? reminder;
  final HabitCounters? habitCounters;
  bool isCompleted;
  DateTime? lastCompletedDate;
  int positiveCount;
  int negativeCount;
  final DateTime createdAt;
  final List<TaskHistoryEntry> history;

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  TaskHistoryEntry? historyEntryOn(DateTime date) {
    final normalizedDate = dateOnly(date);
    for (final entry in history) {
      if (dateOnly(entry.date) == normalizedDate) return entry;
    }
    return null;
  }

  TaskHistoryEntry _historyEntryFor(DateTime date) {
    final existingEntry = historyEntryOn(date);
    if (existingEntry != null) return existingEntry;

    final entry = TaskHistoryEntry(date: dateOnly(date));
    history.add(entry);
    return entry;
  }

  void addHabitPoint(DateTime date, {required bool positive}) {
    final entry = _historyEntryFor(date);
    if (positive) {
      entry.positiveCount++;
      positiveCount++;
    } else {
      entry.negativeCount++;
      negativeCount++;
    }
  }

  bool isCompletedOn(DateTime date) {
    if (type != TaskType.daily) return isCompleted;
    final historyEntry = historyEntryOn(date);
    if (historyEntry != null) return historyEntry.dailyCompleted;
    final completedDate = lastCompletedDate;
    return completedDate != null &&
        completedDate.year == date.year &&
        completedDate.month == date.month &&
        completedDate.day == date.day;
  }

  void setCompletedOn(DateTime date, {required bool completed}) {
    if (type == TaskType.daily) {
      lastCompletedDate = completed ? date : null;
      _historyEntryFor(date).dailyCompleted = completed;
    } else {
      isCompleted = completed;
    }
  }
}
