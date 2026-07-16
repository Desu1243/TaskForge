import 'package:flutter/material.dart';
import 'package:taskforge/models/app_settings.dart';
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
