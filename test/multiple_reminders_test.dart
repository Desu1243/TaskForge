import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/pages/add_task_page.dart';
import 'package:taskforge/services/task_storage.dart';

Task daily({List<TaskReminder> reminders = const []}) => Task(
  id: 'exercise',
  type: TaskType.daily,
  title: 'Exercise',
  notes: 'Twenty minutes',
  schedule: const DailySchedule(activeWeekdays: {1, 3, 5}),
  reminders: reminders,
);

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

Widget app(Widget home) => MaterialApp(
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en', 'GB'), Locale('en', 'US')],
  home: home,
);

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'reminder lists retain identity, separate dates and deletion across disk reloads',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'taskforge_reminders_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = TaskStorage.forDirectory(directory);
      final dates = [DateTime(2030, 3, 1), DateTime(2030, 3, 10)];
      Task todo(List<TaskReminder> reminders) => Task(
        id: 'todo',
        type: TaskType.todo,
        title: 'Appointment',
        notes: '',
        schedule: const TodoSchedule(),
        reminders: reminders,
      );
      final reminders = [
        for (var i = 0; i < 2; i++)
          TaskReminder(
            id: '$i',
            time: const ReminderTime(hour: 12, minute: 30),
            date: dates[i],
          ),
      ];
      await storage.saveTask(todo(reminders));
      final restored = (await storage.loadAll())[TaskType.todo]!.single;
      expect(restored.reminders.map((reminder) => reminder.date), dates);
      expect(restored.reminders.map((reminder) => reminder.id), ['0', '1']);
      await storage.saveTask(todo([]));
      expect(
        (await storage.loadAll())[TaskType.todo]!.single.reminders,
        isEmpty,
      );
    },
  );

  test(
    'legacy reminders migrate with their time, To-do date and task data',
    () {
      final task = daily()..setCompletedOn(DateTime.now(), completed: true);
      final json = task.toJson()..remove('reminders');
      json['version'] = 1;
      json['reminder'] = {
        'hour': 18,
        'minute': 45,
        'title': 'Old title',
        'message': 'Old body',
        'activeWeekdays': [1],
      };
      final migrated = Task.fromJson(json);
      expect(migrated.reminders.single.time.hour, 18);
      expect(migrated.reminders.single.time.minute, 45);
      expect(migrated.reminders.single.date, isNull);
      expect(migrated.notes, 'Twenty minutes');
      expect(migrated.isCompletedOn(DateTime.now()), isTrue);
      json['type'] = 'todo';
      json['schedule'] = {'kind': 'todo', 'dueDate': '2030-03-15T00:00:00.000'};
      expect(Task.fromJson(json).reminders.single.date, DateTime(2030, 3, 15));
      // An explicitly empty list must not resurrect the legacy reminder.
      json['reminders'] = [];
      expect(Task.fromJson(json).reminders, isEmpty);
    },
  );

  test(
    'undated legacy To-do reminder receives a date that is persisted only once',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'taskforge_migration_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final tasksDirectory = await Directory(
        '${directory.path}/tasks',
      ).create(recursive: true);
      final json = Task(
        id: 'old',
        type: TaskType.todo,
        title: 'Old',
        notes: '',
        schedule: const TodoSchedule(),
      ).toJson()..remove('reminders');
      json['reminder'] = {'hour': 9, 'minute': 0};
      final file = File('${tasksDirectory.path}/old.json');
      await file.writeAsString(jsonEncode(json));
      final storage = TaskStorage.forDirectory(directory);
      final first = (await storage.loadAll())[TaskType.todo]!.single;
      final persisted = jsonDecode(await file.readAsString()) as Map;
      expect(persisted.containsKey('reminder'), isFalse);
      expect((persisted['reminders'] as List).single['date'], isNotNull);
      final second = (await storage.loadAll())[TaskType.todo]!.single;
      expect(second.reminders.single.date, first.reminders.single.date);
    },
  );

  testWidgets(
    'daily reminders can be added, edited, cancelled and deleted independently',
    (tester) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = await AppSettings.load();
      Task? saved;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  saved = await Navigator.push<Task>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTaskPage(
                        taskType: TaskType.daily,
                        settings: settings,
                        task: daily(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Add reminder'));
      expect(find.text('No reminders set'), findsOneWidget);
      expect(find.text('Enable reminder'), findsNothing);
      expect(find.text('Notification title'), findsNothing);
      await tester.tap(find.text('Add reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+1h'));
      await scrollTo(tester, find.text('Add reminder'));
      await tester.tap(find.text('Add reminder'));
      await tester.pumpAndSettle();
      Finder tiles() => find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('reminder-'),
      );
      expect(tiles(), findsNWidgets(2));
      await scrollTo(tester, tiles().first);
      await tester.tap(tiles().first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('+15min'));
      await tester.tap(find.text('Save reminder'));
      await tester.pumpAndSettle();
      expect(tiles(), findsNWidgets(2));
      await scrollTo(tester, tiles().last);
      await tester.tap(tiles().last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('+15min'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await scrollTo(tester, tiles().last);
      await tester.tap(tiles().last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete reminder'));
      await tester.pumpAndSettle();
      expect(tiles(), findsOneWidget);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(saved!.reminders.single.time.hour, 9);
      expect(saved!.reminders.single.time.minute, 15);
      expect(saved!.reminders.single.date, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'To-do reminders have independent dates between time controls and Add reminder',
    (tester) async {
      final settings = await AppSettings.load();
      Task? saved;
      final original = Task(
        id: 'todo',
        type: TaskType.todo,
        title: 'Plan',
        notes: '',
        schedule: const TodoSchedule(),
        reminders: [
          TaskReminder(
            id: 'first',
            time: const ReminderTime(hour: 9, minute: 0),
            date: DateTime(2030, 3, 1),
          ),
        ],
      );
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  saved = await Navigator.push<Task>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddTaskPage(
                        taskType: TaskType.todo,
                        settings: settings,
                        task: original,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Reminder date'));
      await tester.tap(find.text('Reminder date'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      final localizations = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.byType(TextField),
        ),
        localizations.formatCompactDate(DateTime(2030, 3, 10)),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Add reminder'));
      await tester.tap(find.text('Add reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(saved!.reminders.map((reminder) => reminder.date), [
        DateTime(2030, 3, 1),
        DateTime(2030, 3, 10),
      ]);
      expect(saved!.reminders.first.id, 'first');
      expect(tester.takeException(), isNull);
    },
  );
}
