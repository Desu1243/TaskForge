import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskforge/models/task.dart';

enum LaunchScreen { habits, dailies, todos }

enum AppTheme { dark, light }

class AppSettings extends ChangeNotifier {
  AppSettings._({
    required SharedPreferencesAsync preferences,
    required LaunchScreen launchScreen,
    required int defaultReminderHour,
    required int defaultReminderMinute,
    required bool notificationsEnabled,
    required bool hideEmptyHabitHistory,
    required bool autoAddTaskOnLaunch,
    required TaskType autoAddTaskType,
    required AppTheme appTheme,
  }) : _preferences = preferences,
       _launchScreen = launchScreen,
       _defaultReminderHour = defaultReminderHour,
       _defaultReminderMinute = defaultReminderMinute,
       _notificationsEnabled = notificationsEnabled,
       _hideEmptyHabitHistory = hideEmptyHabitHistory,
       _autoAddTaskOnLaunch = autoAddTaskOnLaunch,
       _autoAddTaskType = autoAddTaskType,
       _appTheme = appTheme;

  static const _launchScreenKey = 'launch_screen';
  static const _reminderHourKey = 'default_reminder_hour';
  static const _reminderMinuteKey = 'default_reminder_minute';
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _hideEmptyHabitHistoryKey = 'hide_empty_habit_history';
  static const _autoAddTaskOnLaunchKey = 'auto_add_task_on_launch';
  static const _autoAddTaskTypeKey = 'auto_add_task_type';
  static const _appThemeKey = 'app_theme';

  final SharedPreferencesAsync _preferences;
  LaunchScreen _launchScreen;
  int _defaultReminderHour;
  int _defaultReminderMinute;
  bool _notificationsEnabled;
  bool _hideEmptyHabitHistory;
  bool _autoAddTaskOnLaunch;
  TaskType _autoAddTaskType;
  AppTheme _appTheme;

  LaunchScreen get launchScreen => _launchScreen;
  TimeOfDay get defaultReminderTime =>
      TimeOfDay(hour: _defaultReminderHour, minute: _defaultReminderMinute);
  bool get notificationsEnabled => _notificationsEnabled;
  bool get hideEmptyHabitHistory => _hideEmptyHabitHistory;
  bool get autoAddTaskOnLaunch => _autoAddTaskOnLaunch;
  TaskType get autoAddTaskType => _autoAddTaskType;
  AppTheme get appTheme => _appTheme;
  ThemeMode get themeMode =>
      _appTheme == AppTheme.dark ? ThemeMode.dark : ThemeMode.light;

  static Future<AppSettings> load() async {
    final preferences = SharedPreferencesAsync();
    final launchScreenName = await preferences.getString(_launchScreenKey);
    final autoAddTaskTypeName = await preferences.getString(
      _autoAddTaskTypeKey,
    );
    final appThemeName = await preferences.getString(_appThemeKey);

    return AppSettings._(
      preferences: preferences,
      launchScreen:
          LaunchScreen.values.asNameMap()[launchScreenName] ??
          LaunchScreen.habits,
      defaultReminderHour: await preferences.getInt(_reminderHourKey) ?? 9,
      defaultReminderMinute: await preferences.getInt(_reminderMinuteKey) ?? 0,
      notificationsEnabled:
          await preferences.getBool(_notificationsEnabledKey) ?? true,
      hideEmptyHabitHistory:
          await preferences.getBool(_hideEmptyHabitHistoryKey) ?? true,
      autoAddTaskOnLaunch:
          await preferences.getBool(_autoAddTaskOnLaunchKey) ?? false,
      autoAddTaskType:
          TaskType.values.asNameMap()[autoAddTaskTypeName] ?? TaskType.todo,
      appTheme: AppTheme.values.asNameMap()[appThemeName] ?? AppTheme.dark,
    );
  }

  void setLaunchScreen(LaunchScreen value) {
    if (_launchScreen == value) return;
    _launchScreen = value;
    notifyListeners();
    unawaited(_preferences.setString(_launchScreenKey, value.name));
  }

  void setDefaultReminderTime(TimeOfDay value) {
    if (_defaultReminderHour == value.hour &&
        _defaultReminderMinute == value.minute) {
      return;
    }
    _defaultReminderHour = value.hour;
    _defaultReminderMinute = value.minute;
    notifyListeners();
    unawaited(_preferences.setInt(_reminderHourKey, value.hour));
    unawaited(_preferences.setInt(_reminderMinuteKey, value.minute));
  }

  void setNotificationsEnabled(bool value) {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    notifyListeners();
    unawaited(_preferences.setBool(_notificationsEnabledKey, value));
  }

  void setHideEmptyHabitHistory(bool value) {
    if (_hideEmptyHabitHistory == value) return;
    _hideEmptyHabitHistory = value;
    notifyListeners();
    unawaited(_preferences.setBool(_hideEmptyHabitHistoryKey, value));
  }

  void setAutoAddTaskOnLaunch(bool value) {
    if (_autoAddTaskOnLaunch == value) return;
    _autoAddTaskOnLaunch = value;
    notifyListeners();
    unawaited(_preferences.setBool(_autoAddTaskOnLaunchKey, value));
  }

  void setAutoAddTaskType(TaskType value) {
    if (_autoAddTaskType == value) return;
    _autoAddTaskType = value;
    notifyListeners();
    unawaited(_preferences.setString(_autoAddTaskTypeKey, value.name));
  }

  void setAppTheme(AppTheme value) {
    if (_appTheme == value) return;
    _appTheme = value;
    notifyListeners();
    unawaited(_preferences.setString(_appThemeKey, value.name));
  }
}
