import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskforge/services/notification_service.dart';
import 'package:taskforge/models/task.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz_data.initializeTimeZones);

  test('maps Android GMT timezone alias to Etc/UTC', () {
    NotificationService.configureLocalTimezone('GMT');

    expect(tz.local.name, 'Etc/UTC');
  });

  test('falls back to Etc/UTC for an unknown timezone', () {
    NotificationService.configureLocalTimezone('Unknown/Timezone');

    expect(tz.local.name, 'Etc/UTC');
  });

  group('Android notifications', () {
    const pluginChannel = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    const timezoneChannel = MethodChannel('taskforge/timezone');
    const permissionChannel = MethodChannel(
      'taskforge/notification_permission',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var fromNotification = false;
    var failLaunchDetails = false;
    final calls = <MethodCall>[];
    final pending = <int, Map<String, dynamic>>{};

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      fromNotification = false;
      failLaunchDetails = false;
      calls.clear();
      pending.clear();
      messenger.setMockMethodCallHandler(
        timezoneChannel,
        (_) async => 'Europe/Warsaw',
      );
      messenger.setMockMethodCallHandler(permissionChannel, (_) async => true);
      messenger.setMockMethodCallHandler(pluginChannel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'pendingNotificationRequests':
            return pending.values.toList();
          case 'zonedSchedule':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            pending[args['id'] as int] = args;
            return null;
          case 'cancel':
            pending.remove((call.arguments as Map)['id']);
            return null;
          case 'cancelAll':
            pending.clear();
            return null;
          case 'initialize':
          case 'canScheduleExactNotifications':
            return true;
          case 'getNotificationAppLaunchDetails':
            if (failLaunchDetails) throw PlatformException(code: 'unavailable');
            return {
              'notificationLaunchedApp': fromNotification,
              if (fromNotification)
                'notificationResponse': {
                  'notificationId': 123,
                  'notificationResponseType': 0,
                  'payload': 'daily-1',
                },
            };
        }
        return null;
      });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(pluginChannel, null);
      messenger.setMockMethodCallHandler(timezoneChannel, null);
      messenger.setMockMethodCallHandler(permissionChannel, null);
    });

    test('remembers the task and notification origin on cold start', () async {
      fromNotification = true;
      final service = await NotificationService.open();
      expect(service.launchedFromNotification, isTrue);
      expect(service.notificationTaskId.value, 'daily-1');
    });

    test(
      'normal start has no task; running app receives notification taps',
      () async {
        final service = await NotificationService.open();
        expect(service.launchedFromNotification, isFalse);
        expect(service.notificationTaskId.value, isNull);
        await messenger.handlePlatformMessage(
          pluginChannel.name,
          pluginChannel.codec.encodeMethodCall(
            const MethodCall('didReceiveNotificationResponse', {
              'notificationId': 456,
              'notificationResponseType': 0,
              'payload': 'todo-1',
            }),
          ),
          (_) {},
        );
        expect(service.notificationTaskId.value, 'todo-1');
      },
    );

    test(
      'failure to read launch details does not disable notifications',
      () async {
        failLaunchDetails = true;
        final service = await NotificationService.open();
        expect(
          await service.requestPermission(),
          NotificationPermissionResult.granted,
        );
      },
    );

    test(
      'monthly reminders repeat by month day and are cancelled when switching to weekly',
      () async {
        final service = await NotificationService.open();
        final monthlyTask = Task(
          id: 'monthly',
          type: TaskType.daily,
          title: 'Clean',
          notes: '',
          schedule: const DailySchedule.monthly(activeMonthDays: {1, 15, 31}),
          reminders: const [
            TaskReminder(
              id: 'morning',
              time: ReminderTime(hour: 9, minute: 15),
            ),
            TaskReminder(
              id: 'evening',
              time: ReminderTime(hour: 18, minute: 0),
            ),
          ],
        );
        await service.scheduleTask(monthlyTask);
        final alarms = calls
            .where((call) => call.method == 'zonedSchedule')
            .map((call) => call.arguments as Map)
            .toList();
        expect(alarms, hasLength(6));
        expect(
          alarms
              .map(
                (alarm) =>
                    DateTime.parse(alarm['scheduledDateTime'] as String).day,
              )
              .toSet(),
          {1, 15, 31},
        );
        for (final alarm in alarms) {
          expect(
            alarm['matchDateTimeComponents'],
            DateTimeComponents.dayOfMonthAndTime.index,
          );
          expect(alarm['payload'], 'monthly');
          expect(alarm['title'], 'Clean');
          expect(alarm['body'], isNull);
        }
        final monthlyIds = alarms.map((alarm) => alarm['id']).toSet();
        expect(monthlyIds, hasLength(6));
        calls.clear();
        await service.scheduleTask(
          Task(
            id: 'monthly',
            type: TaskType.daily,
            title: 'Clean',
            notes: '',
            schedule: const DailySchedule(activeWeekdays: {1}),
            reminders: const [
              TaskReminder(
                id: 'morning',
                time: ReminderTime(hour: 9, minute: 15),
              ),
            ],
          ),
        );
        final cancelled = calls
            .where((call) => call.method == 'cancel')
            .map((call) => (call.arguments as Map)['id'])
            .toSet();
        expect(cancelled.containsAll(monthlyIds), isTrue);
        final weeklyAlarm =
            calls
                    .singleWhere((call) => call.method == 'zonedSchedule')
                    .arguments
                as Map;
        expect(
          weeklyAlarm['matchDateTimeComponents'],
          DateTimeComponents.dayOfWeekAndTime.index,
        );
      },
    );
    for (final type in TaskType.values) {
      test(
        '$type reminders have independent alarms and removed entries are cancelled',
        () async {
          final service = await NotificationService.open();
          final tomorrow = DateTime.now().add(const Duration(days: 1));
          final nextDay = DateTime.now().add(const Duration(days: 2));
          Task task(List<TaskReminder> reminders) => Task(
            id: 'multiple',
            type: type,
            title: 'Exercise',
            notes: 'Twenty minutes',
            schedule: switch (type) {
              TaskType.todo => const TodoSchedule(),
              TaskType.daily => const DailySchedule(activeWeekdays: {1, 3}),
              TaskType.habit => const HabitSchedule(
                activeWeekdays: {1, 3},
                targetCount: 2,
                period: HabitPeriod.week,
              ),
            },
            reminders: reminders,
          );
          final reminders = [
            TaskReminder(
              id: 'morning',
              time: const ReminderTime(hour: 9, minute: 0),
              date: type == TaskType.todo ? tomorrow : null,
            ),
            TaskReminder(
              id: 'evening',
              time: const ReminderTime(hour: 18, minute: 0),
              date: type == TaskType.todo ? nextDay : null,
            ),
          ];
          final otherTask = Task(
            id: 'other',
            type: TaskType.todo,
            title: 'Other',
            notes: '',
            schedule: const TodoSchedule(),
            reminders: [
              TaskReminder(
                id: 'other',
                time: const ReminderTime(hour: 12, minute: 0),
                date: tomorrow,
              ),
            ],
          );
          await service.scheduleTask(otherTask);
          final otherIds = pending.keys.toSet();
          calls.clear();
          await service.scheduleTask(task(reminders));
          final alarms = calls
              .where((call) => call.method == 'zonedSchedule')
              .map((call) => call.arguments as Map)
              .toList();
          final expected = type == TaskType.todo ? 2 : 4;
          expect(alarms, hasLength(expected));
          expect(
            alarms.map((alarm) => alarm['id']).toSet(),
            hasLength(expected),
          );
          for (final alarm in alarms) {
            expect(alarm['title'], 'Exercise');
            expect(alarm['body'], 'Twenty minutes');
            expect(alarm['payload'], 'multiple');
          }
          if (type == TaskType.todo) {
            expect(
              alarms.map(
                (alarm) =>
                    DateTime.parse(alarm['scheduledDateTime'] as String).day,
              ),
              [tomorrow.day, nextDay.day],
            );
          }
          await service.scheduleTask(task([reminders.first]));
          expect(
            pending.values.where((alarm) => alarm['payload'] == 'multiple'),
            hasLength(type == TaskType.todo ? 1 : 2),
          );
          expect(pending.keys.toSet().containsAll(otherIds), isTrue);
          await service.scheduleTask(task([]));
          expect(pending.keys.toSet(), otherIds);
        },
      );
    }

    test(
      'completed To-do cancels all reminders and expired dates never roll over',
      () async {
        final service = await NotificationService.open();
        final task = Task(
          id: 'todo',
          type: TaskType.todo,
          title: 'Todo',
          notes: '',
          schedule: const TodoSchedule(),
          reminders: [
            TaskReminder(
              id: 'past',
              time: const ReminderTime(hour: 9, minute: 0),
              date: DateTime.now().subtract(const Duration(days: 1)),
            ),
            TaskReminder(
              id: 'future',
              time: const ReminderTime(hour: 9, minute: 0),
              date: DateTime.now().add(const Duration(days: 1)),
            ),
            TaskReminder(
              id: 'later',
              time: const ReminderTime(hour: 12, minute: 0),
              date: DateTime.now().add(const Duration(days: 2)),
            ),
          ],
        );
        await service.scheduleTask(task);
        expect(pending, hasLength(2));
        task.setCompletedOn(DateTime.now(), completed: true);
        calls.clear();
        await service.scheduleTask(task);
        expect(pending, isEmpty);
        expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
      },
    );
  });
}
