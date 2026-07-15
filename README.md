# TaskForge

TaskForge is a local-first habit tracker and daily task manager built with Flutter. It combines simple to-do lists, recurring daily tasks, measurable habits, history charts, reminders, and persistent on-device storage in one application.

The project currently targets Android.

## Features

### Three task types

- **To-dos** are one-time tasks with an optional due date and a circular completion control.
- **Dailies** repeat on selected weekdays. Their state distinguishes between active, completed, and non-scheduled days.
- **Habits** support positive and negative counters, selected active weekdays, and daily, weekly, or monthly goals.

All task types support a title, notes, scheduling, optional reminders, editing, and deletion.

### Habit counters

Habits can expose either or both counter types:

- positive counter (`+`),
- negative counter (`-`).

The habit tile changes color based on the current balance:

- yellow when the counters are equal,
- green when the positive counter is higher,
- red when the negative counter is higher.

Today's counter values can be corrected from the task editing screen if a point was added by mistake.

### History and charts

Dailies and habits provide a dedicated history screen.

- Habit charts display positive and negative values as green and red lines.
- Daily charts use a yellow line to represent completed and skipped days.
- History entries are listed newest first.
- Empty habit entries (`+0 | -0`) can be hidden from both the chart and list.
- Previous scheduled days without activity are recorded as skipped or zero-value entries.

### Local notifications

Tasks with reminders are scheduled using Android local notifications.

- Habit and Daily reminders repeat at the selected time on selected weekdays.
- To-do reminders use the due date. Without a due date, the next occurrence of the selected time is used.
- A blank notification title falls back to the task title.
- A blank message produces a notification without body text.
- Reminder schedules are updated when a task is created, edited, or deleted.
- Scheduled reminders are restored after a device restart.
- Device time zones and daylight-saving changes are handled by timezone-aware scheduling.

On supported Android versions, TaskForge requests permission for exact alarms. When it is unavailable, reminders fall back to inexact scheduling instead of being disabled.

### Persistent local storage

Every task is stored as an individual JSON file in the application's private documents directory. The file contains the complete task configuration and its history list.

```text
taskforge/
├── habits/
├── daily/
└── tasks/
```

Changes are written after creating, editing, completing, counting, or deleting a task. Writes for the same task are queued to prevent rapid interactions from overwriting newer data.

### Settings

The settings page includes:

- launch screen selection,
- default reminder time,
- global notification switch,
- empty Habit history filtering,
- dark and light themes.

Settings are persisted with `shared_preferences`.

## Technology

- Flutter and Material 3
- Dart 3.10+
- [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) for Android notifications
- [`timezone`](https://pub.dev/packages/timezone) for timezone-aware scheduling
- [`path_provider`](https://pub.dev/packages/path_provider) for application storage paths
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) for user settings
- JSON files for task and history persistence

No backend or user account is required. Task data remains on the device.

## Requirements

- Flutter 3.38.1 or newer
- Dart 3.10 or newer
- Android SDK with API level 35 or newer available for compilation
- Java 17
- An Android device or emulator

## Project structure

```text
lib/
├── models/       # Tasks, history entries, and application settings
├── pages/        # Main tabs, task form, settings, and history screens
├── services/     # JSON persistence and notification scheduling
├── themes/       # Shared visual constants
└── main.dart     # Themes, settings initialization, and application entry point

test/
├── notification_service_test.dart
└── task_storage_test.dart
```

