import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/models/task_tag.dart';
import 'package:taskforge/pages/add_task_page.dart';
import 'package:taskforge/pages/dailies_page.dart';
import 'package:taskforge/pages/habits_page.dart';
import 'package:taskforge/pages/main_page.dart';
import 'package:taskforge/pages/to_dos_page.dart';
import 'package:taskforge/services/notification_service.dart';
import 'package:taskforge/services/task_storage.dart';
import 'package:taskforge/widgets/task_tags.dart';

const work = TaskTag(id: 'work', name: 'Work', color: 0xFF42A5F5);
const home = TaskTag(id: 'home', name: 'Home', color: 0xFF25CD90);

Task todo(String id, Set<String> tags) => Task(
  id: id,
  type: TaskType.todo,
  title: id,
  notes: '',
  schedule: const TodoSchedule(),
  tagIds: tags,
);

class _UnusedNotifications implements NotificationService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingStorage extends TaskStorage {
  _RecordingStorage() : super.forDirectory(Directory('.'));

  final saved = <String, Map<String, dynamic>>{};

  @override
  Future<void> saveTask(Task task) async {
    saved[task.id] = task.toJson();
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'tags and display preferences persist; edits preserve identity',
    () async {
      final settings = await AppSettings.load();
      expect(settings.tags, isEmpty);
      expect(settings.showTagColorBars, isTrue);
      expect(settings.tagAddButtonVisibility, TagAddButtonVisibility.both);
      await Future.wait([settings.saveTag(work), settings.saveTag(home)]);
      await settings.saveTag(
        const TaskTag(id: 'work', name: 'Office', color: 0xFFFF5353),
      );
      settings.setShowTagColorBars(false);
      settings.setTagAddButtonVisibility(TagAddButtonVisibility.tasksOnly);
      await Future<void>.delayed(Duration.zero);

      final restored = await AppSettings.load();
      expect(restored.tags.map((tag) => tag.id), ['work', 'home']);
      expect(restored.tags.first.name, 'Office');
      expect(restored.tags.first.color, 0xFFFF5353);
      expect(restored.showTagColorBars, isFalse);
      expect(restored.tagAddButtonVisibility, TagAddButtonVisibility.tasksOnly);
      await restored.deleteTag('work');
      expect((await AppSettings.load()).tags.single.id, 'home');
    },
  );

  test('task files preserve tags and legacy files load without tags', () async {
    final directory = await Directory.systemTemp.createTemp('taskforge_tags_');
    addTearDown(() => directory.delete(recursive: true));
    final storage = TaskStorage.forDirectory(directory);
    final task = todo('tagged', {'work', 'home'});
    await storage.saveTask(task);
    expect((await storage.loadAll())[TaskType.todo]!.single.tagIds, {
      'work',
      'home',
    });
    final legacy = task.toJson()..remove('tagIds');
    expect(Task.fromJson(legacy).tagIds, isEmpty);
  });

  testWidgets(
    'filters by any selected tag, All resets and empty results are clear',
    (tester) async {
      final settings = await AppSettings.load();
      await settings.saveTag(work);
      await settings.saveTag(home);
      await settings.saveTag(
        const TaskTag(id: 'empty', name: 'Empty', color: 0xFFFF5353),
      );
      final tasks = [
        todo('Office task', {'work'}),
        todo('House task', {'home'}),
        todo('Untagged', {}),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskTagList(
              settings: settings,
              tasks: tasks,
              builder: (filtered) => ToDosPage(
                tasks: filtered,
                settings: settings,
                onChanged: (_) {},
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();
      expect(find.text('Office task'), findsOneWidget);
      expect(find.text('House task'), findsNothing);
      expect(find.text('Untagged'), findsNothing);
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('House task'), findsOneWidget);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Untagged'), findsOneWidget);
      await tester.tap(find.text('Empty'));
      await tester.pumpAndSettle();
      expect(find.text('No tasks match the selected tags.'), findsOneWidget);
    },
  );

  testWidgets(
    'task form creates and assigns a tag and preserves it when editing',
    (tester) async {
      final settings = await AppSettings.load();
      final task = todo('Original title', {});
      Task? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  saved = await Navigator.push<Task>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTaskPage(
                        taskType: TaskType.todo,
                        settings: settings,
                        task: task,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Health',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Custom color'),
        '12AB34',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(settings.tags.single.color, 0xFF12AB34);
      expect(find.text('Health'), findsOneWidget);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(saved!.title, 'Original title');
      expect(saved!.tagIds, {settings.tags.single.id});
    },
  );

  testWidgets(
    'long press edits tag; deletion requires confirmation and cleans stored tasks',
    (tester) async {
      final settings = await AppSettings.load();
      await settings.saveTag(work);
      await settings.saveTag(home);
      final storage = _RecordingStorage();
      final task = Task(
        id: 'daily',
        type: TaskType.daily,
        title: 'Read',
        notes: 'Keep this note',
        schedule: const DailySchedule(activeWeekdays: {1, 2, 3}),
        tagIds: {'work', 'home'},
      )..setCompletedOn(DateTime.now(), completed: true);
      await tester.pumpWidget(
        MaterialApp(
          home: MainPage(
            settings: settings,
            storage: storage,
            notificationService: _UnusedNotifications(),
            initialTasks: {
              TaskType.daily: [task],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Work'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Office',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(task.tagIds, {'work', 'home'});
      await tester.longPress(find.text('Office'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(settings.tags, hasLength(2));
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete').last);
      await tester.pumpAndSettle();
      expect(task.tagIds, {'home'});
      final restored = Task.fromJson(storage.saved[task.id]!);
      expect(restored.tagIds, {'home'});
      expect(restored.notes, 'Keep this note');
      expect(restored.isCompletedOn(DateTime.now()), isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('add buttons respect all four visibility modes', (tester) async {
    final settings = await AppSettings.load();
    for (final visibility in TagAddButtonVisibility.values) {
      settings.setTagAddButtonVisibility(visibility);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: TaskTagList(
                    settings: settings,
                    tasks: const [],
                    builder: (_) => const SizedBox(),
                  ),
                ),
                TaskTagPicker(
                  settings: settings,
                  selected: const {},
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final plus = find.text('+');
      expect(
        find.descendant(of: find.byType(TaskTagList), matching: plus),
        visibility.onLists ? findsOneWidget : findsNothing,
      );
      expect(
        find.descendant(of: find.byType(TaskTagPicker), matching: plus),
        visibility.onTasks ? findsOneWidget : findsNothing,
      );
    }
  });

  for (final type in TaskType.values) {
    testWidgets('$type bars split only the content area and can be hidden', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = await AppSettings.load();
      await settings.saveTag(work);
      await settings.saveTag(home);
      final task = Task(
        id: 'tile',
        type: type,
        title: 'Task',
        notes: 'Description',
        tagIds: {'work', 'home'},
        schedule: switch (type) {
          TaskType.todo => const TodoSchedule(),
          TaskType.daily => const DailySchedule(
            activeWeekdays: {1, 2, 3, 4, 5, 6, 7},
          ),
          TaskType.habit => const HabitSchedule(
            activeWeekdays: {1, 2, 3},
            targetCount: 1,
            period: HabitPeriod.day,
          ),
        },
      );
      final page = switch (type) {
        TaskType.todo => ToDosPage(
          tasks: [task],
          settings: settings,
          onChanged: (_) {},
          onEdit: (_) {},
        ),
        TaskType.daily => DailiesPage(
          tasks: [task],
          settings: settings,
          onChanged: (_) {},
          onEdit: (_) {},
        ),
        TaskType.habit => HabitsPage(
          tasks: [task],
          settings: settings,
          onChanged: (_) {},
          onEdit: (_) {},
        ),
      };
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
      final blue = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFF42A5F5),
      );
      final green = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0xFF25CD90),
      );
      expect(blue, findsOneWidget);
      expect(tester.getSize(blue).height, 4);
      expect(tester.getTopLeft(blue).dx, 64); // 12px list margin + 52px control
      expect(tester.getSize(blue), tester.getSize(green));
      expect(tester.getTopRight(blue), tester.getTopLeft(green));
      settings.setShowTagColorBars(false);
      await tester.pumpAndSettle();
      expect(blue, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
