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
  late bool _autoDeleteCompletedTodos;
  late int _autoDeleteCompletedTodosAfterHours;
  final Map<String, Timer> _todoDeletionTimers = {};

  @override
  void initState() {
    super.initState();
    tasks = {
      for (final type in TaskType.values)
        type: List.of(widget.initialTasks[type] ?? const []),
    };
    _notificationsEnabled = widget.settings.notificationsEnabled;
    _autoDeleteCompletedTodos = widget.settings.autoDeleteCompletedTodos;
    _autoDeleteCompletedTodosAfterHours =
        widget.settings.autoDeleteCompletedTodosAfterHours;
    widget.settings.addListener(_settingsChanged);
    currentPage = switch (widget.settings.launchScreen) {
      LaunchScreen.habits => 0,
      LaunchScreen.dailies => 1,
      LaunchScreen.todos => 2,
    };
    controller = PageController(initialPage: currentPage, keepPage: true);
    unawaited(_reconcileTodoDeletionTimers());
  }

  TaskType? get currentTaskType => switch (currentPage) {
    0 => TaskType.habit,
    1 => TaskType.daily,
    2 => TaskType.todo,
    _ => null,
  };

  void _selectPage(int page) {
    if (page == currentPage || !controller.hasClients) return;
    controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

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
      _scheduleTodoDeletion(editedTask);
    }
  }

  void taskChanged(Task task) {
    setState(() {});
    unawaited(_persistTaskChange(task));
  }

  Future<void> _persistTaskChange(Task task) async {
    await _saveTask(task);
    if (task.type != TaskType.todo) return;
    await _scheduleTaskNotification(task);
    _scheduleTodoDeletion(task);
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
    _todoDeletionTimers.remove(task.id)?.cancel();
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
    if (_notificationsEnabled != enabled) {
      _notificationsEnabled = enabled;
      unawaited(_applyNotificationSetting(enabled));
    }

    final autoDeleteEnabled = widget.settings.autoDeleteCompletedTodos;
    final autoDeleteHours = widget.settings.autoDeleteCompletedTodosAfterHours;
    if (_autoDeleteCompletedTodos != autoDeleteEnabled ||
        _autoDeleteCompletedTodosAfterHours != autoDeleteHours) {
      _autoDeleteCompletedTodos = autoDeleteEnabled;
      _autoDeleteCompletedTodosAfterHours = autoDeleteHours;
      unawaited(_reconcileTodoDeletionTimers());
    }
  }

  Future<void> _reconcileTodoDeletionTimers() async {
    for (final timer in _todoDeletionTimers.values) {
      timer.cancel();
    }
    _todoDeletionTimers.clear();
    if (!_autoDeleteCompletedTodos) return;

    final now = DateTime.now();
    for (final task in List<Task>.of(tasks[TaskType.todo]!)) {
      if (!task.isCompleted) continue;
      if (task.completedAt == null) {
        task.completedAt = now;
        await _saveTask(task);
      }
      _scheduleTodoDeletion(task);
    }
  }

  void _scheduleTodoDeletion(Task task) {
    _todoDeletionTimers.remove(task.id)?.cancel();
    final completedAt = task.completedAt;
    if (!_autoDeleteCompletedTodos ||
        !task.isCompleted ||
        completedAt == null) {
      return;
    }

    final deadline = completedAt.add(
      Duration(hours: _autoDeleteCompletedTodosAfterHours),
    );
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      unawaited(_deleteTodoIfExpired(task.id));
      return;
    }
    _todoDeletionTimers[task.id] = Timer(
      remaining,
      () => unawaited(_deleteTodoIfExpired(task.id)),
    );
  }

  Future<void> _deleteTodoIfExpired(String taskId) async {
    _todoDeletionTimers.remove(taskId)?.cancel();
    if (!mounted || !_autoDeleteCompletedTodos) return;
    final task = tasks[TaskType.todo]!
        .where((candidate) => candidate.id == taskId)
        .firstOrNull;
    if (task == null || !task.isCompleted || task.completedAt == null) return;
    final delay = Duration(hours: _autoDeleteCompletedTodosAfterHours);
    if (!task.shouldAutoDelete(DateTime.now(), delay)) {
      _scheduleTodoDeletion(task);
      return;
    }

    setState(() => tasks[TaskType.todo]!.remove(task));
    await _deleteTask(task);
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
    for (final timer in _todoDeletionTimers.values) {
      timer.cancel();
    }
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
              onPressed: () => _selectPage(0),
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
              onPressed: () => _selectPage(1),
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
              onPressed: () => _selectPage(2),
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
              onPressed: () => _selectPage(3),
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
