import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/pages/add_task_page.dart';
import 'package:taskforge/services/notification_service.dart';
import 'package:taskforge/services/task_storage.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

Task monthly({Set<int> days = const {15, 31}, DateTime? createdAt}) => Task(
  id: 'monthly',
  type: TaskType.daily,
  title: 'Clean social media',
  notes: 'Keep notes',
  schedule: DailySchedule.monthly(activeMonthDays: days),
  createdAt: createdAt,
  reminders: const [
    TaskReminder(id: 'morning', time: ReminderTime(hour: 9, minute: 15)),
  ],
);

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('daily reminder chooses today or tomorrow in local time across DST', () {
    final location = tz.getLocation('Europe/Warsaw');
    const time = ReminderTime(hour: 9, minute: 0);
    expect(
      NotificationService.nextDailyReminderDate(
        time,
        now: tz.TZDateTime(location, 2026, 3, 28, 8),
      ),
      tz.TZDateTime(location, 2026, 3, 28, 9),
    );
    expect(
      NotificationService.nextDailyReminderDate(
        time,
        now: tz.TZDateTime(location, 2026, 3, 28, 10),
      ),
      tz.TZDateTime(location, 2026, 3, 29, 9),
    );
    expect(
      NotificationService.nextDailyReminderDate(
        time,
        now: tz.TZDateTime(location, 2026, 12, 31, 10),
      ),
      tz.TZDateTime(location, 2027, 1, 1, 9),
    );
  });

  test('monthly activation skips missing days and includes leap days', () {
    final task = monthly(days: {29, 31});
    expect(task.isScheduledOn(DateTime(2026, 1, 31)), isTrue);
    expect(task.isScheduledOn(DateTime(2026, 2, 28)), isFalse);
    expect(task.isScheduledOn(DateTime(2026, 3, 1)), isFalse);
    expect(task.isScheduledOn(DateTime(2028, 2, 29)), isTrue);
    expect(task.isScheduledOn(DateTime(2026, 4, 30)), isFalse);
  });

  test(
    'review finds last monthly occurrence across short months and year boundaries',
    () {
      final task = monthly(days: {31}, createdAt: DateTime(2025, 1, 1));
      expect(
        task.mostRecentScheduledDateBefore(DateTime(2026, 3, 20)),
        DateTime(2026, 1, 31),
      );
      expect(
        task.mostRecentScheduledDateBefore(DateTime(2026, 1, 1)),
        DateTime(2025, 12, 31),
      );
      expect(task.mostRecentScheduledDateBefore(DateTime(2025, 1, 15)), isNull);
      expect(
        task.mostRecentScheduledDateBefore(DateTime(2026, 3, 31)),
        DateTime(2026, 1, 31),
      );
    },
  );

  test('history adds only scheduled dates and keeps extra completions', () {
    final task = monthly(days: {31}, createdAt: DateTime(2026, 1, 1));
    task.setCompletedOn(DateTime(2026, 2, 10), completed: true);
    task.backfillHistoryThrough(DateTime(2026, 3, 31));
    expect(task.history.map((entry) => entry.date), [
      DateTime(2026, 1, 31),
      DateTime(2026, 2, 10),
      DateTime(2026, 3, 31),
    ]);
    expect(task.isCompletedOn(DateTime(2026, 2, 10)), isTrue);
  });

  test(
    'monthly schedule and reminders survive disk storage; legacy weekly stays weekly',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'taskforge_monthly_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final storage = TaskStorage.forDirectory(directory);
      await storage.saveTask(monthly());
      final restored = (await storage.loadAll())[TaskType.daily]!.single;
      expect((restored.schedule as DailySchedule).isMonthly, isTrue);
      expect((restored.schedule as DailySchedule).activeMonthDays, {15, 31});
      expect(restored.reminders.single.id, 'morning');
      expect(restored.reminders.single.time.hour, 9);
      final json = restored.toJson();
      json['schedule'] = {
        'kind': 'daily',
        'activeWeekdays': [1, 3],
      };
      final weekly = Task.fromJson(json).schedule as DailySchedule;
      expect(weekly.isMonthly, isFalse);
      expect(weekly.activeWeekdays, {1, 3});
    },
  );

  test(
    'next monthly reminder skips February, handles leap years and elapsed time',
    () {
      final location = tz.getLocation('Europe/Warsaw');
      const time = ReminderTime(hour: 9, minute: 15);
      expect(
        NotificationService.nextMonthlyReminderDate(
          31,
          time,
          now: tz.TZDateTime(location, 2026, 1, 31, 10),
        ),
        tz.TZDateTime(location, 2026, 3, 31, 9, 15),
      );
      expect(
        NotificationService.nextMonthlyReminderDate(
          29,
          time,
          now: tz.TZDateTime(location, 2028, 2, 1),
        ),
        tz.TZDateTime(location, 2028, 2, 29, 9, 15),
      );
      expect(
        NotificationService.nextMonthlyReminderDate(
          15,
          time,
          now: tz.TZDateTime(location, 2026, 12, 15, 10),
        ),
        tz.TZDateTime(location, 2027, 1, 15, 9, 15),
      );
      expect(
        NotificationService.nextMonthlyReminderDate(
          15,
          time,
          now: tz.TZDateTime(location, 2026, 10, 15, 8),
        ),
        tz.TZDateTime(location, 2026, 10, 15, 9, 15),
      );
    },
  );

  testWidgets('monthly form preserves reminders when active days change', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final settings = await AppSettings.load();
    Task? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
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
                      task: monthly(),
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
    expect(find.text('Active days of the month'), findsOneWidget);
    // Reminders follow the task's remaining active days.
    final day15 = find
        .byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == 'Day 15',
        )
        .first;
    await tester.scrollUntilVisible(
      day15,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(day15);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect((saved!.schedule as DailySchedule).activeMonthDays, {31});
    expect(saved!.reminders.single.id, 'morning');
    expect(saved!.reminders.single.time.minute, 15);
    expect(saved!.notes, 'Keep notes');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new daily can switch to monthly and rejects an empty selection',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final settings = await AppSettings.load();
      await tester.pumpWidget(
        MaterialApp(
          home: AddTaskPage(taskType: TaskType.daily, settings: settings),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Monthly task',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final monthlyButton = find.text('Monthly');
      await tester.ensureVisible(monthlyButton);
      await tester.tap(monthlyButton);
      await tester.pumpAndSettle();
      final today = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Day ${DateTime.now().day}',
      );
      await tester.scrollUntilVisible(
        today,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(today), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(today);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Select at least one active day.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
