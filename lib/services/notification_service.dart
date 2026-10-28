import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:taskforge/models/task.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum NotificationPermissionResult { granted, denied, unavailable }

class NotificationService {
  NotificationService._(
    this._plugin,
    this._scheduleMode, {
    required bool available,
    required this.notificationTaskId,
    this.launchedFromNotification = false,
  }) : _available = available;

  static const _timezoneChannel = MethodChannel('taskforge/timezone');
  static const _notificationPermissionChannel = MethodChannel(
    'taskforge/notification_permission',
  );
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
  final ValueNotifier<String?> notificationTaskId;
  final bool launchedFromNotification;

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
    final notificationTaskId = ValueNotifier<String?>(null);
    var launchedFromNotification = false;
    bool initialized;
    try {
      initialized =
          await plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('ic_stat_taskforge'),
            ),
            onDidReceiveNotificationResponse: (response) {
              final taskId = response.payload;
              if (taskId != null && taskId.isNotEmpty) {
                notificationTaskId.value = taskId;
              }
            },
          ) ??
          false;
    } on Object catch (error, stackTrace) {
      developer.log(
        'Notification plugin initialization failed.',
        name: 'TaskForge.NotificationService',
        error: error,
        stackTrace: stackTrace,
      );
      return NotificationService._(
        plugin,
        AndroidScheduleMode.inexactAllowWhileIdle,
        available: false,
        notificationTaskId: notificationTaskId,
        launchedFromNotification: launchedFromNotification,
      );
    }

    if (!initialized) {
      developer.log(
        'Notification plugin initialization returned false.',
        name: 'TaskForge.NotificationService',
      );
      return NotificationService._(
        plugin,
        AndroidScheduleMode.inexactAllowWhileIdle,
        available: false,
        notificationTaskId: notificationTaskId,
        launchedFromNotification: launchedFromNotification,
      );
    }

    try {
      final launchDetails = await plugin.getNotificationAppLaunchDetails();
      launchedFromNotification =
          launchDetails?.didNotificationLaunchApp ?? false;
      if (launchedFromNotification && notificationTaskId.value == null) {
        notificationTaskId.value = launchDetails?.notificationResponse?.payload;
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'Notification launch details could not be read.',
        name: 'TaskForge.NotificationService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canScheduleExactly = await _canScheduleExactly(android);
    return NotificationService._(
      plugin,
      canScheduleExactly
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      available: true,
      notificationTaskId: notificationTaskId,
      launchedFromNotification: launchedFromNotification,
    );
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

  Future<NotificationPermissionResult> requestPermission() async {
    if (!_available) return NotificationPermissionResult.unavailable;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return NotificationPermissionResult.granted;

    try {
      final notificationsGranted =
          defaultTargetPlatform == TargetPlatform.android
          ? await _notificationPermissionChannel.invokeMethod<bool>(
                  'requestNotificationPermission',
                ) ??
                false
          : await android.requestNotificationsPermission() ?? false;
      if (!notificationsGranted) {
        return NotificationPermissionResult.denied;
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'Notification permission could not be checked.',
        name: 'TaskForge.NotificationService',
        error: error,
        stackTrace: stackTrace,
      );
      return NotificationPermissionResult.unavailable;
    }

    var canScheduleExactly = await _canScheduleExactly(android);
    if (!canScheduleExactly) {
      try {
        canScheduleExactly =
            await android.requestExactAlarmsPermission() ?? false;
      } on Object catch (error, stackTrace) {
        developer.log(
          'Exact alarm permission could not be requested. Using inexact reminders.',
          name: 'TaskForge.NotificationService',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    _scheduleMode = canScheduleExactly
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    return NotificationPermissionResult.granted;
  }

  static Future<bool> _canScheduleExactly(
    AndroidFlutterLocalNotificationsPlugin? android,
  ) async {
    if (android == null) return false;
    try {
      return await android.canScheduleExactNotifications() ?? false;
    } on Object catch (error, stackTrace) {
      developer.log(
        'Exact alarm permission could not be checked. Using inexact reminders.',
        name: 'TaskForge.NotificationService',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
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
    // Cancel both schedule types so switching monthly/weekly leaves no old alarms.
    for (var day = 1; day <= 31; day++) {
      await _plugin.cancel(id: _monthlyNotificationId(task.id, day));
    }
  }

  Future<void> cancelAll() async {
    if (!_available) return;
    await _plugin.cancelAll();
  }

  Future<void> _scheduleTaskWithoutCancelling(Task task) async {
    if (task.type == TaskType.todo && task.isCompleted) return;
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

    final schedule = task.schedule;
    if (schedule is DailySchedule && schedule.isMonthly) {
      final days = (reminder.activeMonthDays ?? schedule.activeMonthDays!)
          .intersection(schedule.activeMonthDays!);
      for (final day in days) {
        await _plugin.zonedSchedule(
          id: _monthlyNotificationId(task.id, day),
          title: title,
          body: body,
          scheduledDate: nextMonthlyReminderDate(
            day,
            reminder.time,
            now: tz.TZDateTime.now(tz.local),
          ),
          notificationDetails: _notificationDetails,
          androidScheduleMode: _scheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
          payload: task.id,
        );
      }
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

  @visibleForTesting
  static tz.TZDateTime nextMonthlyReminderDate(
    int day,
    ReminderTime time, {
    required tz.TZDateTime now,
  }) {
    RangeError.checkValueInInterval(day, 1, 31, 'day');
    for (var offset = 0; ; offset++) {
      final month = DateTime(now.year, now.month + offset);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      if (day > daysInMonth) continue;
      final candidate = tz.TZDateTime(
        now.location,
        month.year,
        month.month,
        day,
        time.hour,
        time.minute,
      );
      if (candidate.isAfter(now)) return candidate;
    }
  }

  int _monthlyNotificationId(String taskId, int day) =>
      _notificationId('$taskId:monthly:$day', 0);

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
