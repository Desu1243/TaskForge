import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';

void main() {
  test('automatic task creation defaults to disabled To-do', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    final settings = await AppSettings.load();

    expect(settings.autoAddTaskOnLaunch, isFalse);
    expect(settings.autoAddTaskType, TaskType.todo);
    expect(settings.autoDeleteCompletedTodos, isFalse);
    expect(settings.autoDeleteCompletedTodosAfterHours, 24);
    expect(settings.firstDayOfWeek, FirstDayOfWeek.monday);
  });

  test('loads automatic task creation preferences', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'auto_add_task_on_launch': true,
          'auto_add_task_type': TaskType.daily.name,
          'auto_delete_completed_todos': true,
          'auto_delete_completed_todos_after_hours': 72,
          'first_day_of_week': FirstDayOfWeek.sunday.name,
        });

    final settings = await AppSettings.load();

    expect(settings.autoAddTaskOnLaunch, isTrue);
    expect(settings.autoAddTaskType, TaskType.daily);
    expect(settings.autoDeleteCompletedTodos, isTrue);
    expect(settings.autoDeleteCompletedTodosAfterHours, 72);
    expect(settings.firstDayOfWeek, FirstDayOfWeek.sunday);
  });
}
