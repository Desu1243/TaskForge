import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/pages/add_task_page.dart';
import 'package:taskforge/services/notification_service.dart';
import 'package:taskforge/services/task_storage.dart';

import 'main_page.dart';

class LoadingPage extends StatefulWidget {
  const LoadingPage({required this.settings, super.key});

  final AppSettings settings;

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  Object? _loadingError;

  Future<void> getAppData() async {
    setState(() => _loadingError = null);
    try {
      final storage = await TaskStorage.open();
      final tasks = await storage.loadAll();
      await _removeExpiredCompletedTodos(tasks, storage);
      final notificationService = await NotificationService.open();
      if (widget.settings.notificationsEnabled) {
        final permissionResult = await notificationService.requestPermission();
        if (permissionResult == NotificationPermissionResult.denied) {
          widget.settings.setNotificationsEnabled(false);
        }
      }
      if (widget.settings.notificationsEnabled) {
        await notificationService.syncAll(
          tasks.values.expand((taskList) => taskList),
        );
      } else {
        await notificationService.cancelAll();
      }
      if (!mounted) return;

      if (widget.settings.autoAddTaskOnLaunch) {
        final task = await Navigator.push<Task>(
          context,
          MaterialPageRoute(
            builder: (context) => AddTaskPage(
              taskType: widget.settings.autoAddTaskType,
              settings: widget.settings,
            ),
          ),
        );
        if (!mounted) return;
        if (task != null) {
          tasks[task.type]!.add(task);
          await storage.saveTask(task);
          if (widget.settings.notificationsEnabled) {
            await notificationService.scheduleTask(task);
          }
        }
      }
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainPage(
            settings: widget.settings,
            storage: storage,
            notificationService: notificationService,
            initialTasks: tasks,
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) setState(() => _loadingError = error);
    }
  }

  Future<void> _removeExpiredCompletedTodos(
    Map<TaskType, List<Task>> tasks,
    TaskStorage storage,
  ) async {
    if (!widget.settings.autoDeleteCompletedTodos) return;
    final now = DateTime.now();
    final delay = Duration(
      hours: widget.settings.autoDeleteCompletedTodosAfterHours,
    );
    final todos = tasks[TaskType.todo]!;
    for (final task in List<Task>.of(todos)) {
      if (!task.isCompleted) continue;
      if (task.completedAt == null) {
        task.completedAt = now;
        await storage.saveTask(task);
      } else if (task.shouldAutoDelete(now, delay)) {
        todos.remove(task);
        await storage.deleteTask(task);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    getAppData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingError == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Task data could not be loaded.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: getAppData, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
