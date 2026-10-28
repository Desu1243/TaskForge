import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/models/task_tag.dart';
import 'package:taskforge/pages/add_task_page.dart';
import 'package:taskforge/pages/main_page.dart';
import 'package:taskforge/services/notification_service.dart';
import 'package:taskforge/services/task_storage.dart';

class _Notifications implements NotificationService {
  @override
  final notificationTaskId = ValueNotifier<String?>(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage extends TaskStorage {
  _Storage() : super.forDirectory(Directory('.'));
}

Task _task(TaskType type, {Set<String>? tags}) => Task(
  id: type.name,
  type: type,
  title: '${type.name} task',
  notes: '',
  tagIds: tags,
  schedule: switch (type) {
    TaskType.todo => const TodoSchedule(),
    TaskType.daily => const DailySchedule(activeWeekdays: {1, 2, 3}),
    TaskType.habit => const HabitSchedule(
      activeWeekdays: {1, 2, 3},
      targetCount: 1,
      period: HabitPeriod.day,
    ),
  },
);

String _pageTitle(WidgetTester tester) =>
    (tester.widget<AppBar>(find.byType(AppBar)).title! as Text).data!;

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  for (final type in TaskType.values) {
    testWidgets('notification cold start selects the $type tab', (
      tester,
    ) async {
      final settings = await AppSettings.load();
      final notifications = _Notifications()
        ..notificationTaskId.value = type.name;
      await tester.pumpWidget(
        MaterialApp(
          home: MainPage(
            settings: settings,
            storage: _Storage(),
            notificationService: notifications,
            initialTasks: {
              for (final type in TaskType.values) type: [_task(type)],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(_pageTitle(tester), switch (type) {
        TaskType.habit => 'Habits',
        TaskType.daily => 'Dailies',
        TaskType.todo => "To-do's",
      });
      expect(find.text('${type.name} task'), findsOneWidget);
      expect(notifications.notificationTaskId.value, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'warm taps clear filters, close editing and handle deleted tasks',
    (tester) async {
      final settings = await AppSettings.load();
      settings.setLaunchScreen(LaunchScreen.todos);
      await settings.saveTag(
        const TaskTag(id: 'work', name: 'Work', color: 0xFF42A5F5),
      );
      await settings.saveTag(
        const TaskTag(id: 'home', name: 'Home', color: 0xFF25CD90),
      );
      final notifications = _Notifications();
      await tester.pumpWidget(
        MaterialApp(
          home: MainPage(
            settings: settings,
            storage: _Storage(),
            notificationService: notifications,
            initialTasks: {
              TaskType.todo: [
                _task(TaskType.todo, tags: {'home'}),
              ],
              TaskType.habit: [_task(TaskType.habit)],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(find.text('todo task'), findsNothing);
      notifications.notificationTaskId.value = TaskType.todo.name;
      await tester.pumpAndSettle();
      expect(find.text('todo task'), findsOneWidget);

      await tester.tap(find.text('todo task'));
      await tester.pumpAndSettle();
      expect(find.byType(AddTaskPage), findsOneWidget);
      notifications.notificationTaskId.value = TaskType.habit.name;
      await tester.pumpAndSettle();
      expect(find.byType(AddTaskPage), findsNothing);
      expect(_pageTitle(tester), 'Habits');
      expect(find.text('habit task'), findsOneWidget);

      notifications.notificationTaskId.value = 'deleted-task';
      await tester.pumpAndSettle();
      expect(find.text('This task is no longer available.'), findsOneWidget);
      expect(_pageTitle(tester), 'Habits');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
