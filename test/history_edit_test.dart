import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/models/task.dart';
import 'package:taskforge/pages/task_history_page.dart';

void main() {
  for (final type in [TaskType.habit, TaskType.daily]) {
    testWidgets('$type history long press edits and persists a past day', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final settings = await AppSettings.load();
      settings.setHideEmptyHabitHistory(false);
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final task = Task(
        id: 'history',
        type: type,
        title: 'Task',
        notes: '',
        createdAt: yesterday,
        schedule: type == TaskType.habit
            ? const HabitSchedule(
                activeWeekdays: {1, 2, 3, 4, 5, 6, 7},
                targetCount: 1,
                period: HabitPeriod.week,
              )
            : const DailySchedule(activeWeekdays: {1, 2, 3, 4, 5, 6, 7}),
      );
      Task? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: TaskHistoryPage(
            task: task,
            settings: settings,
            onSave: (updated) async {
              saved = Task.fromJson(updated.toJson());
            },
          ),
        ),
      );
      final tile = find.byWidgetPredicate(
        (widget) => widget is ListTile && widget.onLongPress != null,
      );
      await tester.scrollUntilVisible(
        tile,
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.longPress(tile);
      await tester.pumpAndSettle();
      if (type == TaskType.habit) {
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Positive'),
          '3',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Negative'),
          '1',
        );
      } else {
        await tester.tap(find.byType(SwitchListTile));
      }
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      if (type == TaskType.habit) {
        expect(task.historyEntryOn(yesterday)!.positiveCount, 3);
        expect(saved!.historyEntryOn(yesterday)!.negativeCount, 1);
      } else {
        expect(task.isCompletedOn(yesterday), isTrue);
        expect(saved!.isCompletedOn(yesterday), isTrue);
        expect(
          find.descendant(of: tile, matching: find.text('Done')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
