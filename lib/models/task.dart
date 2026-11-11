enum TaskType { habit, daily, todo }

enum HabitPeriod { day, week, month }

typedef HabitPeriodCounts = ({int positive, int negative});

class ReminderTime {
  const ReminderTime({required this.hour, required this.minute});

  final int hour;
  final int minute;
}

class TaskReminder {
  const TaskReminder({
    required this.id,
    required this.time,
    DateTime? date,
    this.untilCompleted = false,
  }) : date = untilCompleted ? null : date;

  final String id;
  final ReminderTime time;
  final DateTime? date;
  final bool untilCompleted;
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
    List<TaskReminder>? reminders,
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
       reminders = List.unmodifiable(reminders ?? const []),
       tagIds = Set.of(tagIds ?? const {}),
       history = history ?? [];

  final String id;
  final TaskType type;
  final String title;
  final String notes;
  final TaskSchedule schedule;
  final List<TaskReminder> reminders;
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

  HabitPeriodCounts habitCountsForPeriod(
    DateTime date, {
    int firstWeekday = DateTime.monday,
  }) {
    final habitSchedule = schedule;
    if (habitSchedule is! HabitSchedule) return (positive: 0, negative: 0);
    final today = dateOnly(date);
    final start = switch (habitSchedule.period) {
      HabitPeriod.day => today,
      HabitPeriod.week => DateTime(
        today.year,
        today.month,
        today.day - (today.weekday - firstWeekday) % DateTime.daysPerWeek,
      ),
      HabitPeriod.month => DateTime(today.year, today.month),
    };
    final end = switch (habitSchedule.period) {
      HabitPeriod.day => DateTime(start.year, start.month, start.day + 1),
      HabitPeriod.week => DateTime(start.year, start.month, start.day + 7),
      HabitPeriod.month => DateTime(start.year, start.month + 1),
    };
    var positive = 0;
    var negative = 0;
    for (final entry in history) {
      final day = dateOnly(entry.date);
      if (!day.isBefore(start) && day.isBefore(end)) {
        positive += entry.positiveCount;
        negative += entry.negativeCount;
      }
    }
    return (positive: positive, negative: negative);
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
    'version': 2,
    'id': id,
    'type': type.name,
    'title': title,
    'notes': notes,
    'tagIds': tagIds.toList(),
    'schedule': _scheduleToJson(schedule),
    'reminders': reminders.map(_reminderToJson).toList(),
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
    final schedule = _scheduleFromJson(
      Map<String, dynamic>.from(json['schedule'] as Map),
    );
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
      schedule: schedule,
      reminders: json.containsKey('reminders')
          ? (json['reminders'] as List<dynamic>? ?? const [])
                .map(
                  (item) =>
                      _reminderFromJson(Map<String, dynamic>.from(item as Map)),
                )
                .toList()
          : _migrateLegacyReminder(json['reminder'], type, schedule),
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
    'id': reminder.id,
    'hour': reminder.time.hour,
    'minute': reminder.time.minute,
    'date': reminder.date?.toIso8601String(),
    'untilCompleted': reminder.untilCompleted,
  };

  static TaskReminder _reminderFromJson(Map<String, dynamic> json) =>
      TaskReminder(
        id: json['id'] as String,
        time: ReminderTime(
          hour: (json['hour'] as num).toInt(),
          minute: (json['minute'] as num).toInt(),
        ),
        date: _optionalDate(json['date']),
        untilCompleted: json['untilCompleted'] as bool? ?? false,
      );

  static List<TaskReminder> _migrateLegacyReminder(
    Object? value,
    TaskType type,
    TaskSchedule schedule,
  ) {
    if (value == null) return [];
    final json = Map<String, dynamic>.from(value as Map);
    final time = ReminderTime(
      hour: (json['hour'] as num).toInt(),
      minute: (json['minute'] as num).toInt(),
    );
    DateTime? date;
    if (type == TaskType.todo) {
      date = schedule is TodoSchedule ? schedule.dueDate : null;
      if (date == null) {
        final now = DateTime.now();
        final todayAt = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
        date = todayAt.isAfter(now)
            ? dateOnly(now)
            : DateTime(now.year, now.month, now.day + 1);
      }
    }
    return [TaskReminder(id: 'legacy', time: time, date: date)];
  }

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
