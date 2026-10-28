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
    this.activeMonthDays,
  });

  final ReminderTime time;
  final String title;
  final String message;
  final Set<int>? activeWeekdays;
  final Set<int>? activeMonthDays;
}

sealed class TaskSchedule {
  const TaskSchedule();
}

class TodoSchedule extends TaskSchedule {
  const TodoSchedule({this.dueDate});

  final DateTime? dueDate;
}

class DailySchedule extends TaskSchedule {
  const DailySchedule({required this.activeWeekdays}) : activeMonthDays = null;

  const DailySchedule.monthly({required this.activeMonthDays})
    : assert(activeMonthDays != null),
      activeWeekdays = const {};

  final Set<int> activeWeekdays;
  final Set<int>? activeMonthDays;
  bool get isMonthly => activeMonthDays != null;
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

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'positiveCount': positiveCount,
    'negativeCount': negativeCount,
    'dailyCompleted': dailyCompleted,
  };

  factory TaskHistoryEntry.fromJson(Map<String, dynamic> json) =>
      TaskHistoryEntry(
        date: DateTime.parse(json['date'] as String),
        positiveCount: (json['positiveCount'] as num?)?.toInt() ?? 0,
        negativeCount: (json['negativeCount'] as num?)?.toInt() ?? 0,
        dailyCompleted: json['dailyCompleted'] as bool? ?? false,
      );
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
    this.completedAt,
    this.lastCompletedDate,
    this.positiveCount = 0,
    this.negativeCount = 0,
    DateTime? createdAt,
    List<TaskHistoryEntry>? history,
    Set<String>? tagIds,
  }) : createdAt = createdAt ?? DateTime.now(),
       tagIds = Set.of(tagIds ?? const {}),
       history = history ?? [];

  final String id;
  final TaskType type;
  final String title;
  final String notes;
  final TaskSchedule schedule;
  final TaskReminder? reminder;
  final HabitCounters? habitCounters;
  bool isCompleted;
  DateTime? completedAt;
  DateTime? lastCompletedDate;
  int positiveCount;
  int negativeCount;
  final DateTime createdAt;
  final List<TaskHistoryEntry> history;
  final Set<String> tagIds;

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

  void setHabitPointsForDate(
    DateTime date, {
    required int positive,
    required int negative,
  }) {
    final existingEntry = historyEntryOn(date);
    if (existingEntry == null && positive == 0 && negative == 0) return;
    final entry = existingEntry ?? _historyEntryFor(date);
    final adjustedPositive = positiveCount + positive - entry.positiveCount;
    final adjustedNegative = negativeCount + negative - entry.negativeCount;
    positiveCount = adjustedPositive < 0 ? 0 : adjustedPositive;
    negativeCount = adjustedNegative < 0 ? 0 : adjustedNegative;
    entry.positiveCount = positive;
    entry.negativeCount = negative;
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
      if (type == TaskType.todo) {
        completedAt = completed ? (completedAt ?? date) : null;
      }
    }
  }

  bool shouldAutoDelete(DateTime now, Duration delay) {
    final completionDate = completedAt;
    return type == TaskType.todo &&
        isCompleted &&
        completionDate != null &&
        !completionDate.add(delay).isAfter(now);
  }

  bool backfillHistoryThrough(DateTime endDate) {
    if (type == TaskType.todo) return false;
    var changed = false;
    var date = dateOnly(createdAt);
    final end = dateOnly(endDate);
    while (!date.isAfter(end)) {
      if (isScheduledOn(date) && historyEntryOn(date) == null) {
        history.add(TaskHistoryEntry(date: date));
        changed = true;
      }
      date = DateTime(date.year, date.month, date.day + 1);
    }
    if (changed) {
      history.sort((first, second) => first.date.compareTo(second.date));
    }
    return changed;
  }

  bool isScheduledOn(DateTime date) => switch (schedule) {
    DailySchedule(:final activeWeekdays, :final activeMonthDays) =>
      activeMonthDays?.contains(date.day) ??
          activeWeekdays.contains(date.weekday),
    HabitSchedule(:final activeWeekdays) => activeWeekdays.contains(
      date.weekday,
    ),
    _ => false,
  };

  DateTime? mostRecentScheduledDateBefore(DateTime date) {
    if (type != TaskType.daily) return null;
    final normalizedDate = dateOnly(date);
    final creationDate = dateOnly(createdAt);
    // A day such as the 31st can skip a short month (up to 62 days apart).
    final lookbackDays =
        schedule is DailySchedule && (schedule as DailySchedule).isMonthly
        ? 62
        : DateTime.daysPerWeek;
    for (var daysAgo = 1; daysAgo <= lookbackDays; daysAgo++) {
      final candidate = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day - daysAgo,
      );
      if (candidate.isBefore(creationDate)) return null;
      if (isScheduledOn(candidate)) return candidate;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'type': type.name,
    'title': title,
    'notes': notes,
    'tagIds': tagIds.toList(),
    'schedule': _scheduleToJson(schedule),
    'reminder': reminder == null ? null : _reminderToJson(reminder!),
    'habitCounters': habitCounters == null
        ? null
        : {
            'positiveEnabled': habitCounters!.positiveEnabled,
            'negativeEnabled': habitCounters!.negativeEnabled,
          },
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
    'lastCompletedDate': lastCompletedDate?.toIso8601String(),
    'positiveCount': positiveCount,
    'negativeCount': negativeCount,
    'createdAt': createdAt.toIso8601String(),
    'history': history.map((entry) => entry.toJson()).toList(),
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    final type = TaskType.values.byName(json['type'] as String);
    final reminderJson = json['reminder'];
    final countersJson = json['habitCounters'];
    final historyJson = json['history'] as List<dynamic>? ?? const [];

    return Task(
      id: json['id'] as String,
      type: type,
      title: json['title'] as String,
      notes: json['notes'] as String? ?? '',
      tagIds: (json['tagIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toSet(),
      schedule: _scheduleFromJson(
        Map<String, dynamic>.from(json['schedule'] as Map),
      ),
      reminder: reminderJson == null
          ? null
          : _reminderFromJson(Map<String, dynamic>.from(reminderJson as Map)),
      habitCounters: countersJson == null
          ? null
          : HabitCounters(
              positiveEnabled:
                  (countersJson as Map)['positiveEnabled'] as bool? ?? true,
              negativeEnabled: countersJson['negativeEnabled'] as bool? ?? true,
            ),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: _optionalDate(json['completedAt']),
      lastCompletedDate: _optionalDate(json['lastCompletedDate']),
      positiveCount: (json['positiveCount'] as num?)?.toInt() ?? 0,
      negativeCount: (json['negativeCount'] as num?)?.toInt() ?? 0,
      createdAt: _optionalDate(json['createdAt']),
      history: historyJson
          .map(
            (entry) => TaskHistoryEntry.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
    );
  }

  static Map<String, dynamic> _scheduleToJson(
    TaskSchedule schedule,
  ) => switch (schedule) {
    TodoSchedule(:final dueDate) => {
      'kind': 'todo',
      'dueDate': dueDate?.toIso8601String(),
    },
    DailySchedule(:final activeWeekdays, :final activeMonthDays) => {
      'kind': 'daily',
      'frequency': activeMonthDays == null ? 'weekly' : 'monthly',
      'activeWeekdays': activeWeekdays.toList()..sort(),
      if (activeMonthDays != null)
        'activeMonthDays': activeMonthDays.toList()..sort(),
    },
    HabitSchedule(:final activeWeekdays, :final targetCount, :final period) => {
      'kind': 'habit',
      'activeWeekdays': activeWeekdays.toList()..sort(),
      'targetCount': targetCount,
      'period': period.name,
    },
  };

  static TaskSchedule _scheduleFromJson(Map<String, dynamic> json) {
    final weekdays = (json['activeWeekdays'] as List<dynamic>? ?? const [])
        .map((value) => (value as num).toInt())
        .toSet();
    return switch (json['kind']) {
      'todo' => TodoSchedule(dueDate: _optionalDate(json['dueDate'])),
      'daily' =>
        json['frequency'] == 'monthly'
            ? DailySchedule.monthly(
                activeMonthDays:
                    _monthDaysFromJson(json['activeMonthDays']) ?? {},
              )
            : DailySchedule(activeWeekdays: weekdays),
      'habit' => HabitSchedule(
        activeWeekdays: weekdays,
        targetCount: (json['targetCount'] as num?)?.toInt() ?? 1,
        period: HabitPeriod.values.byName(
          json['period'] as String? ?? HabitPeriod.week.name,
        ),
      ),
      _ => throw const FormatException('Unknown task schedule type.'),
    };
  }

  static Map<String, dynamic> _reminderToJson(TaskReminder reminder) => {
    'hour': reminder.time.hour,
    'minute': reminder.time.minute,
    'title': reminder.title,
    'message': reminder.message,
    'activeWeekdays': reminder.activeWeekdays == null
        ? null
        : (reminder.activeWeekdays!.toList()..sort()),
    'activeMonthDays': reminder.activeMonthDays == null
        ? null
        : (reminder.activeMonthDays!.toList()..sort()),
  };

  static TaskReminder _reminderFromJson(Map<String, dynamic> json) =>
      TaskReminder(
        time: ReminderTime(
          hour: (json['hour'] as num).toInt(),
          minute: (json['minute'] as num).toInt(),
        ),
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        activeWeekdays: (json['activeWeekdays'] as List<dynamic>?)
            ?.map((value) => (value as num).toInt())
            .toSet(),
        activeMonthDays: _monthDaysFromJson(json['activeMonthDays']),
      );

  static Set<int>? _monthDaysFromJson(Object? value) => value == null
      ? null
      : (value as List<dynamic>)
            .whereType<num>()
            .map((day) => day.toInt())
            .where((day) => day >= 1 && day <= 31)
            .toSet();

  static DateTime? _optionalDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
