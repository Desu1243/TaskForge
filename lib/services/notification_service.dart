import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:taskforge/models/task.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._(
    this._plugin,
    this._scheduleMode, {
    required bool available,
  }) : _available = available;

  static const _timezoneChannel = MethodChannel('taskforge/timezone');
  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders',
      'Task reminders',
      channelDescription: 'Reminders configured for TaskForge tasks',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  AndroidScheduleMode _scheduleMode;
  final bool _available;

  static Future<NotificationService> open() async {
    tz_data.initializeTimeZones();
    String? timezoneName;
    try {
      timezoneName = await _timezoneChannel.invokeMethod<String>(
        'getLocalTimezone',
      );
    } on PlatformException {
      // UTC below is safer than preventing the entire app from starting.
    }
    configureLocalTimezone(timezoneName);

    final plugin = FlutterLocalNotificationsPlugin();
    try {
      final initialized = await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_taskforge'),
        ),
      );
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final canScheduleExactly =
          await android?.canScheduleExactNotifications() ?? false;
      return NotificationService._(
        plugin,
        canScheduleExactly
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        available: initialized ?? false,
      );
    } on Object {
      return NotificationService._(
        plugin,
        AndroidScheduleMode.inexactAllowWhileIdle,
        available: false,
      );
    }
  }

  static void configureLocalTimezone(String? timezoneName) {
    final normalizedName = switch (timezoneName) {
      null || '' || 'GMT' || 'UTC' || 'UCT' || 'Zulu' => 'Etc/UTC',
      _ => timezoneName,
    };
    try {
      tz.setLocalLocation(tz.getLocation(normalizedName));
    } on Object {
      tz.setLocalLocation(tz.getLocation('Etc/UTC'));
    }
  }

  Future<bool> requestPermission() async {
    if (!_available) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final notificationsGranted =
        await android?.requestNotificationsPermission() ?? true;
    if (!notificationsGranted) return false;

    var canScheduleExactly =
        await android?.canScheduleExactNotifications() ?? false;
    if (!canScheduleExactly) {
      canScheduleExactly =
          await android?.requestExactAlarmsPermission() ?? false;
    }
    _scheduleMode = canScheduleExactly
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    return true;
  }

  Future<void> syncAll(Iterable<Task> tasks) async {
    if (!_available) return;
    await _plugin.cancelAll();
    for (final task in tasks) {
      await _scheduleTaskWithoutCancelling(task);
    }
  }

  Future<void> scheduleTask(Task task) async {
    if (!_available) return;
    await cancelTask(task);
    await _scheduleTaskWithoutCancelling(task);
  }

  Future<void> cancelTask(Task task) async {
    if (!_available) return;
    for (var slot = 0; slot <= 7; slot++) {
      await _plugin.cancel(id: _notificationId(task.id, slot));
    }
  }

  Future<void> cancelAll() async {
    if (!_available) return;
    await _plugin.cancelAll();
  }

  Future<void> _scheduleTaskWithoutCancelling(Task task) async {
    final reminder = task.reminder;
    if (reminder == null) return;

    final title = reminder.title.trim().isEmpty
        ? task.title
        : reminder.title.trim();
    final trimmedMessage = reminder.message.trim();
    final body = trimmedMessage.isEmpty ? null : trimmedMessage;

    if (task.type == TaskType.todo) {
      final scheduledDate = _todoNotificationDate(task, reminder);
      if (scheduledDate == null) return;
      await _plugin.zonedSchedule(
        id: _notificationId(task.id, 0),
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails,
        androidScheduleMode: _scheduleMode,
        payload: task.id,
      );
      return;
    }

    final weekdays = reminder.activeWeekdays ?? _scheduledWeekdays(task);
    for (final weekday in weekdays) {
      await _plugin.zonedSchedule(
        id: _notificationId(task.id, weekday),
        title: title,
        body: body,
        scheduledDate: _nextWeekdayAt(weekday, reminder.time),
        notificationDetails: _notificationDetails,
        androidScheduleMode: _scheduleMode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: task.id,
      );
    }
  }

  tz.TZDateTime? _todoNotificationDate(Task task, TaskReminder reminder) {
    final now = tz.TZDateTime.now(tz.local);
    final schedule = task.schedule;
    if (schedule is TodoSchedule && schedule.dueDate != null) {
      final dueDate = schedule.dueDate!;
      final result = tz.TZDateTime(
        tz.local,
        dueDate.year,
        dueDate.month,
        dueDate.day,
        reminder.time.hour,
        reminder.time.minute,
      );
      return result.isAfter(now) ? result : null;
    }

    var result = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );
    if (!result.isAfter(now)) {
      result = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + 1,
        reminder.time.hour,
        reminder.time.minute,
      );
    }
    return result;
  }

  tz.TZDateTime _nextWeekdayAt(int weekday, ReminderTime time) {
    final now = tz.TZDateTime.now(tz.local);
    final daysUntilWeekday = (weekday - now.weekday) % DateTime.daysPerWeek;
    var result = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysUntilWeekday,
      time.hour,
      time.minute,
    );
    if (!result.isAfter(now)) {
      result = tz.TZDateTime(
        tz.local,
        result.year,
        result.month,
        result.day + DateTime.daysPerWeek,
        time.hour,
        time.minute,
      );
    }
    return result;
  }

  Set<int> _scheduledWeekdays(Task task) => switch (task.schedule) {
    DailySchedule(:final activeWeekdays) => activeWeekdays,
    HabitSchedule(:final activeWeekdays) => activeWeekdays,
    _ => const {},
  };

  int _notificationId(String taskId, int slot) {
    var hash = 0x811C9DC5;
    for (final codeUnit in taskId.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7FFFFFFF;
    }
    return (hash % 200000000) * 10 + slot;
  }
}
