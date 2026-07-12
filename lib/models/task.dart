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

class Task {
  Task({
    required this.id,
    required this.type,
    required this.title,
    required this.notes,
    required this.schedule,
    this.reminder,
    this.isCompleted = false,
    this.positiveCount = 0,
    this.negativeCount = 0,
  });

  final String id;
  final TaskType type;
  final String title;
  final String notes;
  final TaskSchedule schedule;
  final TaskReminder? reminder;
  bool isCompleted;
  int positiveCount;
  int negativeCount;
}
