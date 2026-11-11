import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:taskforge/models/app_settings.dart';
import 'package:taskforge/pages/habits_page.dart';
import 'package:taskforge/models/task.dart';

Task habit(HabitPeriod period) => Task(
  id: 'habit',
  type: TaskType.habit,
  title: 'Exercise',
  notes: '',
  schedule: HabitSchedule(
    activeWeekdays: {1, 2, 3, 4, 5, 6, 7},
    targetCount: 3,
    period: period,
  ),
);

void main() {
  testWidgets(
    'habit tile hides zero and shows only current period, never lifetime totals',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final settings = await AppSettings.load();
      final task = habit(HabitPeriod.day);
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      task.setHabitPointsForDate(yesterday, positive: 40, negative: 20);
      Widget page() => MaterialApp(
        home: Scaffold(
          body: HabitsPage(
            tasks: [task],
            settings: settings,
            onChanged: (_) {},
            onEdit: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(page());
      expect(find.text('+0 | -0'), findsNothing);
      expect(find.text('+40 | -20'), findsNothing);
      task.setHabitPointsForDate(now, positive: 2, negative: 1);
      await tester.pumpWidget(page());
      expect(find.text('+2 | -1'), findsOneWidget);
      expect(find.text('+42 | -21'), findsNothing);
    },
  );
  test('day resets at midnight without clearing history', () {
    final task = habit(HabitPeriod.day);
    task.addHabitPoint(DateTime(2026, 11, 10, 23, 59), positive: true);
    expect(task.habitCountsForPeriod(DateTime(2026, 11, 10)), (
      positive: 1,
      negative: 0,
    ));
    expect(task.habitCountsForPeriod(DateTime(2026, 11, 11)), (
      positive: 0,
      negative: 0,
    ));
    task.addHabitPoint(DateTime(2026, 11, 11), positive: false);
    expect(task.habitCountsForPeriod(DateTime(2026, 11, 11)), (
      positive: 0,
      negative: 1,
    ));
    expect(task.historyEntryOn(DateTime(2026, 11, 10))!.positiveCount, 1);
  });

  test('week starts on the selected first weekday across year boundaries', () {
    final task = habit(HabitPeriod.week);
    task.addHabitPoint(DateTime(2026, 12, 27), positive: true); // Sunday
    task.addHabitPoint(DateTime(2026, 12, 28), positive: false); // Monday
    expect(task.habitCountsForPeriod(DateTime(2026, 12, 28)), (
      positive: 0,
      negative: 1,
    ));
    expect(
      task.habitCountsForPeriod(
        DateTime(2026, 12, 28),
        firstWeekday: DateTime.sunday,
      ),
      (positive: 1, negative: 1),
    );
    expect(task.habitCountsForPeriod(DateTime(2027, 1, 2)), (
      positive: 0,
      negative: 1,
    ));
    expect(
      task.habitCountsForPeriod(
        DateTime(2027, 1, 3),
        firstWeekday: DateTime.sunday,
      ),
      (positive: 0, negative: 0),
    );
    expect(task.habitCountsForPeriod(DateTime(2027, 1, 4)), (
      positive: 0,
      negative: 0,
    ));
  });

  test(
    'month resets on the first, including leap years; restored history is the source of counts',
    () {
      final task = habit(HabitPeriod.month);
      task.addHabitPoint(DateTime(2028, 2, 29), positive: true);
      task.addHabitPoint(DateTime(2028, 3, 1), positive: false);
      final restored = Task.fromJson(task.toJson());
      expect(restored.habitCountsForPeriod(DateTime(2028, 2, 29)), (
        positive: 1,
        negative: 0,
      ));
      expect(restored.habitCountsForPeriod(DateTime(2028, 3, 1)), (
        positive: 0,
        negative: 1,
      ));
      restored.setHabitPointsForDate(
        DateTime(2028, 3, 1),
        positive: 3,
        negative: 2,
      );
      expect(restored.habitCountsForPeriod(DateTime(2028, 3, 2)), (
        positive: 3,
        negative: 2,
      ));
      expect(restored.habitCountsForPeriod(DateTime(2028, 4, 1)), (
        positive: 0,
        negative: 0,
      ));
    },
  );
}
