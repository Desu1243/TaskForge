import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/models/task_tag.dart';

enum LaunchScreen { habits, dailies, todos }

enum FirstDayOfWeek { monday, sunday }

enum AppTheme { dark, light }

class AppSettings extends ChangeNotifier {
  AppSettings._({
    required SharedPreferencesAsync preferences,
    required LaunchScreen launchScreen,
    required int defaultReminderHour,
    required int defaultReminderMinute,
    required bool useCurrentTimeAsDefaultReminder,
    required bool notificationsEnabled,
    required bool notificationsDisabledByUser,
    required bool hideEmptyHabitHistory,
    required bool reviewSkippedDailies,
    required DateTime? lastDailyReviewDate,
    required bool autoAddTaskOnLaunch,
    required TaskType autoAddTaskType,
    required bool autoDeleteCompletedTodos,
    required int autoDeleteCompletedTodosAfterHours,
    required FirstDayOfWeek firstDayOfWeek,
    required AppTheme appTheme,
    required List<TaskTag> tags,
    required bool showTagColorBars,
    required int tagColorBarHeight,
    required TagAddButtonVisibility tagAddButtonVisibility,
  }) : _preferences = preferences,
       _launchScreen = launchScreen,
       _defaultReminderHour = defaultReminderHour,
       _defaultReminderMinute = defaultReminderMinute,
       _useCurrentTimeAsDefaultReminder = useCurrentTimeAsDefaultReminder,
       _notificationsEnabled = notificationsEnabled,
       _notificationsDisabledByUser = notificationsDisabledByUser,
       _hideEmptyHabitHistory = hideEmptyHabitHistory,
       _reviewSkippedDailies = reviewSkippedDailies,
       _lastDailyReviewDate = lastDailyReviewDate,
       _autoAddTaskOnLaunch = autoAddTaskOnLaunch,
       _autoAddTaskType = autoAddTaskType,
       _autoDeleteCompletedTodos = autoDeleteCompletedTodos,
       _autoDeleteCompletedTodosAfterHours = autoDeleteCompletedTodosAfterHours,
       _firstDayOfWeek = firstDayOfWeek,
       _appTheme = appTheme,
       _tags = tags,
       _showTagColorBars = showTagColorBars,
       _tagColorBarHeight = tagColorBarHeight,
       _tagAddButtonVisibility = tagAddButtonVisibility;

  static const _launchScreenKey = 'launch_screen';
  static const _reminderHourKey = 'default_reminder_hour';
  static const _reminderMinuteKey = 'default_reminder_minute';
  static const _useCurrentTimeAsDefaultReminderKey =
      'use_current_time_as_default_reminder';
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _notificationsDisabledByUserKey =
      'notifications_disabled_by_user';
  static const _hideEmptyHabitHistoryKey = 'hide_empty_habit_history';
  static const _reviewSkippedDailiesKey = 'review_skipped_dailies';
  static const _lastDailyReviewDateKey = 'last_daily_review_date';
  static const _autoAddTaskOnLaunchKey = 'auto_add_task_on_launch';
  static const _autoAddTaskTypeKey = 'auto_add_task_type';
  static const _autoDeleteCompletedTodosKey = 'auto_delete_completed_todos';
  static const _autoDeleteCompletedTodosAfterHoursKey =
      'auto_delete_completed_todos_after_hours';
  static const _firstDayOfWeekKey = 'first_day_of_week';
  static const _appThemeKey = 'app_theme';
  static const _tagsKey = 'task_tags';
  static const _showTagColorBarsKey = 'show_tag_color_bars';
  static const _tagColorBarHeightKey = 'tag_color_bar_height';
  static const _tagAddButtonVisibilityKey = 'tag_add_button_visibility';

  final SharedPreferencesAsync _preferences;
  LaunchScreen _launchScreen;
  int _defaultReminderHour;
  int _defaultReminderMinute;
  bool _useCurrentTimeAsDefaultReminder;
  bool _notificationsEnabled;
  bool _notificationsDisabledByUser;
  bool _hideEmptyHabitHistory;
  bool _reviewSkippedDailies;
  DateTime? _lastDailyReviewDate;
  bool _autoAddTaskOnLaunch;
  TaskType _autoAddTaskType;
  bool _autoDeleteCompletedTodos;
  int _autoDeleteCompletedTodosAfterHours;
  FirstDayOfWeek _firstDayOfWeek;
  AppTheme _appTheme;
  List<TaskTag> _tags;
  bool _showTagColorBars;
  int _tagColorBarHeight;
  TagAddButtonVisibility _tagAddButtonVisibility;
  Future<void> _pendingTagWrite = Future<void>.value();

  List<TaskTag> get tags => List.unmodifiable(_tags);
  bool get showTagColorBars => _showTagColorBars;
  int get tagColorBarHeight => _tagColorBarHeight;
  TagAddButtonVisibility get tagAddButtonVisibility => _tagAddButtonVisibility;

  Future<void> saveTag(TaskTag tag) => _updateTags((updated) {
    final index = updated.indexWhere((item) => item.id == tag.id);
    if (index < 0) {
      updated.add(tag);
    } else {
      updated[index] = tag;
    }
    return updated;
  });

  Future<void> deleteTag(String id) =>
      _updateTags((tags) => tags.where((tag) => tag.id != id).toList());

  Future<void> _updateTags(List<TaskTag> Function(List<TaskTag>) update) {
    final write = _pendingTagWrite.then((_) async {
      final tags = update(List<TaskTag>.of(_tags));
      await _preferences.setString(
        _tagsKey,
        jsonEncode(tags.map((tag) => tag.toJson()).toList()),
      );
      _tags = tags;
      notifyListeners();
    });
    _pendingTagWrite = write.catchError((Object _) {});
    return write;
  }

  void setShowTagColorBars(bool value) {
    if (_showTagColorBars == value) return;
    _showTagColorBars = value;
    notifyListeners();
    unawaited(_preferences.setBool(_showTagColorBarsKey, value));
  }

  void setTagColorBarHeight(int value) {
    final height = value.clamp(1, 20);
    if (_tagColorBarHeight == height) return;
    _tagColorBarHeight = height;
    notifyListeners();
    unawaited(_preferences.setInt(_tagColorBarHeightKey, height));
  }

  void setTagAddButtonVisibility(TagAddButtonVisibility value) {
    if (_tagAddButtonVisibility == value) return;
    _tagAddButtonVisibility = value;
    notifyListeners();
    unawaited(_preferences.setString(_tagAddButtonVisibilityKey, value.name));
  }

  LaunchScreen get launchScreen => _launchScreen;
  TimeOfDay get defaultReminderTime =>
      TimeOfDay(hour: _defaultReminderHour, minute: _defaultReminderMinute);
  bool get useCurrentTimeAsDefaultReminder => _useCurrentTimeAsDefaultReminder;

  TimeOfDay defaultReminderTimeAt(DateTime now) =>
      _useCurrentTimeAsDefaultReminder
      ? TimeOfDay.fromDateTime(now)
      : defaultReminderTime;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get notificationsDisabledByUser => _notificationsDisabledByUser;
  bool get hideEmptyHabitHistory => _hideEmptyHabitHistory;
  bool get reviewSkippedDailies => _reviewSkippedDailies;
  bool get autoAddTaskOnLaunch => _autoAddTaskOnLaunch;
  TaskType get autoAddTaskType => _autoAddTaskType;
  bool get autoDeleteCompletedTodos => _autoDeleteCompletedTodos;
  int get autoDeleteCompletedTodosAfterHours =>
      _autoDeleteCompletedTodosAfterHours;
  FirstDayOfWeek get firstDayOfWeek => _firstDayOfWeek;
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
    final firstDayOfWeekName = await preferences.getString(_firstDayOfWeekKey);
    final tagButtonName = await preferences.getString(
      _tagAddButtonVisibilityKey,
    );
    final tags = <TaskTag>[];
    final encodedTags = await preferences.getString(_tagsKey);
    if (encodedTags != null) {
      try {
        for (final item in jsonDecode(encodedTags) as List<dynamic>) {
          tags.add(TaskTag.fromJson(Map<String, dynamic>.from(item as Map)));
        }
      } on FormatException {
        // Older settings remain usable if the tag registry cannot be decoded.
      }
    }

    return AppSettings._(
      preferences: preferences,
      launchScreen:
          LaunchScreen.values.asNameMap()[launchScreenName] ??
          LaunchScreen.habits,
      defaultReminderHour: await preferences.getInt(_reminderHourKey) ?? 9,
      defaultReminderMinute: await preferences.getInt(_reminderMinuteKey) ?? 0,
      useCurrentTimeAsDefaultReminder:
          await preferences.getBool(_useCurrentTimeAsDefaultReminderKey) ??
          false,
      notificationsEnabled:
          await preferences.getBool(_notificationsEnabledKey) ?? true,
      notificationsDisabledByUser:
          await preferences.getBool(_notificationsDisabledByUserKey) ?? false,
      hideEmptyHabitHistory:
          await preferences.getBool(_hideEmptyHabitHistoryKey) ?? true,
      reviewSkippedDailies:
          await preferences.getBool(_reviewSkippedDailiesKey) ?? false,
      lastDailyReviewDate: DateTime.tryParse(
        await preferences.getString(_lastDailyReviewDateKey) ?? '',
      ),
      autoAddTaskOnLaunch:
          await preferences.getBool(_autoAddTaskOnLaunchKey) ?? false,
      autoAddTaskType:
          TaskType.values.asNameMap()[autoAddTaskTypeName] ?? TaskType.todo,
      autoDeleteCompletedTodos:
          await preferences.getBool(_autoDeleteCompletedTodosKey) ?? false,
      autoDeleteCompletedTodosAfterHours:
          await preferences.getInt(_autoDeleteCompletedTodosAfterHoursKey) ??
          24,
      firstDayOfWeek:
          FirstDayOfWeek.values.asNameMap()[firstDayOfWeekName] ??
          FirstDayOfWeek.monday,
      appTheme: AppTheme.values.asNameMap()[appThemeName] ?? AppTheme.dark,
      tags: tags,
      showTagColorBars: await preferences.getBool(_showTagColorBarsKey) ?? true,
      tagColorBarHeight: (await preferences.getInt(_tagColorBarHeightKey) ?? 4)
          .clamp(1, 20),
      tagAddButtonVisibility:
          TagAddButtonVisibility.values.asNameMap()[tagButtonName] ??
          TagAddButtonVisibility.both,
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

  void setUseCurrentTimeAsDefaultReminder(bool value) {
    if (_useCurrentTimeAsDefaultReminder == value) return;
    _useCurrentTimeAsDefaultReminder = value;
    notifyListeners();
    unawaited(_preferences.setBool(_useCurrentTimeAsDefaultReminderKey, value));
  }

  void setNotificationsEnabled(bool value) {
    final disabledByUser = !value;
    if (_notificationsEnabled == value &&
        _notificationsDisabledByUser == disabledByUser) {
      return;
    }
    _notificationsEnabled = value;
    _notificationsDisabledByUser = disabledByUser;
    notifyListeners();
    unawaited(_preferences.setBool(_notificationsEnabledKey, value));
    unawaited(
      _preferences.setBool(_notificationsDisabledByUserKey, disabledByUser),
    );
  }

  Future<void> restoreNotificationsAfterPermissionGrant() async {
    if (_notificationsEnabled || _notificationsDisabledByUser) return;
    _notificationsEnabled = true;
    notifyListeners();
    await _preferences.setBool(_notificationsEnabledKey, true);
  }

  void setHideEmptyHabitHistory(bool value) {
    if (_hideEmptyHabitHistory == value) return;
    _hideEmptyHabitHistory = value;
    notifyListeners();
    unawaited(_preferences.setBool(_hideEmptyHabitHistoryKey, value));
  }

  void setReviewSkippedDailies(bool value) {
    if (_reviewSkippedDailies == value) return;
    _reviewSkippedDailies = value;
    notifyListeners();
    unawaited(_preferences.setBool(_reviewSkippedDailiesKey, value));
  }

  bool wasDailyReviewShownOn(DateTime date) {
    final lastReviewDate = _lastDailyReviewDate;
    return lastReviewDate != null &&
        Task.dateOnly(lastReviewDate) == Task.dateOnly(date);
  }

  Future<void> markDailyReviewShownOn(DateTime date) async {
    final normalizedDate = Task.dateOnly(date);
    _lastDailyReviewDate = normalizedDate;
    await _preferences.setString(
      _lastDailyReviewDateKey,
      normalizedDate.toIso8601String(),
    );
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

  void setAutoDeleteCompletedTodos(bool value) {
    if (_autoDeleteCompletedTodos == value) return;
    _autoDeleteCompletedTodos = value;
    notifyListeners();
    unawaited(_preferences.setBool(_autoDeleteCompletedTodosKey, value));
  }

  void setAutoDeleteCompletedTodosAfterHours(int value) {
    if (value < 1 || _autoDeleteCompletedTodosAfterHours == value) return;
    _autoDeleteCompletedTodosAfterHours = value;
    notifyListeners();
    unawaited(
      _preferences.setInt(_autoDeleteCompletedTodosAfterHoursKey, value),
    );
  }

  void setFirstDayOfWeek(FirstDayOfWeek value) {
    if (_firstDayOfWeek == value) return;
    _firstDayOfWeek = value;
    notifyListeners();
    unawaited(_preferences.setString(_firstDayOfWeekKey, value.name));
  }

  void setAppTheme(AppTheme value) {
    if (_appTheme == value) return;
    _appTheme = value;
    notifyListeners();
    unawaited(_preferences.setString(_appThemeKey, value.name));
  }
}
