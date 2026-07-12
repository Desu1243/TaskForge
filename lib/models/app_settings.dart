import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LaunchScreen { habits, dailies, todos }

enum AppTheme { dark, light }

class AppSettings extends ChangeNotifier {
  AppSettings._({
    required SharedPreferencesAsync preferences,
    required LaunchScreen launchScreen,
    required int defaultReminderHour,
    required int defaultReminderMinute,
    required bool notificationsEnabled,
    required AppTheme appTheme,
  }) : _preferences = preferences,
       _launchScreen = launchScreen,
       _defaultReminderHour = defaultReminderHour,
       _defaultReminderMinute = defaultReminderMinute,
       _notificationsEnabled = notificationsEnabled,
       _appTheme = appTheme;

  static const _launchScreenKey = 'launch_screen';
  static const _reminderHourKey = 'default_reminder_hour';
  static const _reminderMinuteKey = 'default_reminder_minute';
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _appThemeKey = 'app_theme';

  final SharedPreferencesAsync _preferences;
  LaunchScreen _launchScreen;
  int _defaultReminderHour;
  int _defaultReminderMinute;
  bool _notificationsEnabled;
  AppTheme _appTheme;

  LaunchScreen get launchScreen => _launchScreen;
  TimeOfDay get defaultReminderTime =>
      TimeOfDay(hour: _defaultReminderHour, minute: _defaultReminderMinute);
  bool get notificationsEnabled => _notificationsEnabled;
  AppTheme get appTheme => _appTheme;
  ThemeMode get themeMode =>
      _appTheme == AppTheme.dark ? ThemeMode.dark : ThemeMode.light;

  static Future<AppSettings> load() async {
    final preferences = SharedPreferencesAsync();
    final launchScreenName = await preferences.getString(_launchScreenKey);
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

  void setAppTheme(AppTheme value) {
    if (_appTheme == value) return;
    _appTheme = value;
    notifyListeners();
    unawaited(_preferences.setString(_appThemeKey, value.name));
  }
}
