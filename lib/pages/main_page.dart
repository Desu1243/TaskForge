import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/pages/add_task_page.dart';
import 'package:taskforge/pages/dailies_page.dart';
import 'package:taskforge/pages/habits_page.dart';
import 'package:taskforge/pages/to_dos_page.dart';
import 'package:taskforge/pages/settings_page.dart';
import 'package:taskforge/services/notification_service.dart';
import 'package:taskforge/services/task_storage.dart';

class MainPage extends StatefulWidget {
  const MainPage({
    required this.settings,
    required this.storage,
    required this.notificationService,
    required this.initialTasks,
    super.key,
  });

  final AppSettings settings;
  final TaskStorage storage;
  final NotificationService notificationService;
  final Map<TaskType, List<Task>> initialTasks;

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final List<String> pageTitles = ["Habits", "Dailies", "To-do's", "Settings"];
  late final Map<TaskType, List<Task>> tasks;
  late int currentPage;
  late final PageController controller;
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    tasks = {
      for (final type in TaskType.values)
        type: List.of(widget.initialTasks[type] ?? const []),
    };
    _notificationsEnabled = widget.settings.notificationsEnabled;
    widget.settings.addListener(_settingsChanged);
    currentPage = switch (widget.settings.launchScreen) {
      LaunchScreen.habits => 0,
      LaunchScreen.dailies => 1,
      LaunchScreen.todos => 2,
    };
    controller = PageController(initialPage: currentPage, keepPage: true);
  }

  TaskType? get currentTaskType => switch (currentPage) {
    0 => TaskType.habit,
    1 => TaskType.daily,
    2 => TaskType.todo,
    _ => null,
  };

  Future<void> addTask() async {
    final taskType = currentTaskType;
    if (taskType == null) return;

    final task = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTaskPage(taskType: taskType, settings: widget.settings),
      ),
    );
    if (task != null && mounted) {
      setState(() => tasks[task.type]!.add(task));
      await _saveTask(task);
      await _scheduleTaskNotification(task);
    }
  }

  Future<void> editTask(Task task) async {
    final editedTask = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (context) => AddTaskPage(
          taskType: task.type,
          settings: widget.settings,
          task: task,
          onDelete: () {
            setState(() => tasks[task.type]!.remove(task));
            unawaited(_deleteTask(task));
          },
        ),
      ),
    );
    if (editedTask == null || !mounted) return;

    final taskList = tasks[task.type]!;
    final index = taskList.indexWhere((element) => element.id == task.id);
    if (index != -1) {
      setState(() => taskList[index] = editedTask);
      await _saveTask(editedTask);
      await _scheduleTaskNotification(editedTask);
    }
  }

  void taskChanged(Task task) {
    setState(() {});
    unawaited(_saveTask(task));
  }

  Future<void> _saveTask(Task task) async {
    try {
      final now = DateTime.now();
      task.backfillHistoryThrough(DateTime(now.year, now.month, now.day - 1));
      await widget.storage.saveTask(task);
    } on Object {
      _showStorageError('Task changes could not be saved.');
    }
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await widget.storage.deleteTask(task);
      await widget.notificationService.cancelTask(task);
    } on Object {
      _showStorageError('The task file could not be deleted.');
    }
  }

  Future<void> _scheduleTaskNotification(Task task) async {
    try {
      if (widget.settings.notificationsEnabled) {
        await widget.notificationService.scheduleTask(task);
      } else {
        await widget.notificationService.cancelTask(task);
      }
    } on Object {
      _showStorageError('The task reminder could not be scheduled.');
    }
  }

  void _settingsChanged() {
    final enabled = widget.settings.notificationsEnabled;
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    unawaited(_applyNotificationSetting(enabled));
  }

  Future<void> _applyNotificationSetting(bool enabled) async {
    try {
      if (!enabled) {
        await widget.notificationService.cancelAll();
        return;
      }
      final permissionResult = await widget.notificationService
          .requestPermission();
      if (permissionResult == NotificationPermissionResult.denied) {
        widget.settings.setNotificationsEnabled(false);
        _showStorageError('Notification permission was not granted.');
        return;
      }
      if (permissionResult == NotificationPermissionResult.unavailable) {
        _showStorageError('Notifications could not be initialized.');
        return;
      }
      if (!widget.settings.notificationsEnabled) return;
      await widget.notificationService.syncAll(
        tasks.values.expand((taskList) => taskList),
      );
      if (!widget.settings.notificationsEnabled) {
        await widget.notificationService.cancelAll();
      }
    } on Object {
      _showStorageError('Notifications could not be updated.');
    }
  }

  void _showStorageError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    widget.settings.removeListener(_settingsChanged);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(pageTitles[currentPage])),
      body: PageView(
        controller: controller,
        onPageChanged: (value) {
          setState(() {
            currentPage = value;
          });
        },
        children: [
          HabitsPage(
            tasks: tasks[TaskType.habit]!,
            onChanged: taskChanged,
            onEdit: editTask,
          ),
          DailiesPage(
            tasks: tasks[TaskType.daily]!,
            onChanged: taskChanged,
            onEdit: editTask,
          ),
          ToDosPage(
            tasks: tasks[TaskType.todo]!,
            onChanged: taskChanged,
            onEdit: editTask,
          ),
          SettingsPage(settings: widget.settings),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Transform(
        transform: Matrix4.rotationZ(45 * 3.1415927 / 180),
        alignment: FractionalOffset.center,
        child: FloatingActionButton(
          onPressed: currentTaskType == null ? null : addTask,
          backgroundColor: currentTaskType == null ? colors.outline : null,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(5)),
          ),
          elevation: 0.0,
          child: Icon(
            Icons.clear_rounded,
            size: 45,
            color: currentTaskType == null
                ? colors.onSurfaceVariant
                : Colors.white,
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 0,
        padding: const EdgeInsets.all(0),
        height: 76,
        shape: const AutomaticNotchedShape(
          RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.zero)),
          StarBorder.polygon(sides: 4, rotation: 0, pointRounding: 0.2),
        ),
        notchMargin: 20,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton(
              style: const ButtonStyle(
                shape: WidgetStatePropertyAll(LinearBorder()),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                ),
              ),
              onPressed: () {
                setState(() {
                  controller.animateToPage(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.bounceInOut,
                  );
                });
              },
              child: Column(
                children: [
                  currentPage == 0
                      ? Icon(
                          Icons.add_box_rounded,
                          size: 32,
                          color: colors.onSurface,
                        )
                      : Icon(
                          Icons.add_box_outlined,
                          size: 32,
                          color: colors.onSurfaceVariant,
                        ),
                  currentPage == 0
                      ? Text(
                          "Habits",
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 12,
                          ),
                        )
                      : Text(
                          "Habits",
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                ],
              ),
            ),
            OutlinedButton(
              style: const ButtonStyle(
                shape: WidgetStatePropertyAll(LinearBorder()),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                ),
              ),
              onPressed: () {
                setState(() {
                  controller.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.bounceInOut,
                  );
                });
              },
              child: Column(
                children: [
                  currentPage == 1
                      ? Icon(
                          Icons.calendar_month_rounded,
                          size: 32,
                          color: colors.onSurface,
                        )
                      : Icon(
                          Icons.calendar_month_outlined,
                          size: 32,
                          color: colors.onSurfaceVariant,
                        ),
                  currentPage == 1
                      ? Text(
                          "Dailies",
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 12,
                          ),
                        )
                      : Text(
                          "Dailies",
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(width: 45),
            OutlinedButton(
              style: const ButtonStyle(
                shape: WidgetStatePropertyAll(LinearBorder()),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                ),
              ),
              onPressed: () {
                setState(() {
                  controller.animateToPage(
                    2,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.bounceInOut,
                  );
                });
              },
              child: Column(
                children: [
                  currentPage == 2
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: 32,
                          color: colors.onSurface,
                        )
                      : Icon(
                          Icons.check_circle_outline_rounded,
                          size: 32,
                          color: colors.onSurfaceVariant,
                        ),
                  currentPage == 2
                      ? Text(
                          "To-do's",
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 12,
                          ),
                        )
                      : Text(
                          "To-do's",
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                ],
              ),
            ),
            OutlinedButton(
              style: const ButtonStyle(
                shape: WidgetStatePropertyAll(LinearBorder()),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                ),
              ),
              onPressed: () {
                setState(() {
                  controller.animateToPage(
                    3,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.bounceInOut,
                  );
                });
              },
              child: Column(
                children: [
                  currentPage == 3
                      ? Icon(Icons.settings, size: 32, color: colors.onSurface)
                      : Icon(
                          Icons.settings_outlined,
                          size: 32,
                          color: colors.onSurfaceVariant,
                        ),
                  currentPage == 3
                      ? Text(
                          "Settings",
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 12,
                          ),
                        )
                      : Text(
                          "Settings",
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
