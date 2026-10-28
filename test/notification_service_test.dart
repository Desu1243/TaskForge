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

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      fromNotification = false;
      failLaunchDetails = false;
      calls.clear();
      messenger.setMockMethodCallHandler(
        timezoneChannel,
        (_) async => 'Europe/Warsaw',
      );
      messenger.setMockMethodCallHandler(permissionChannel, (_) async => true);
      messenger.setMockMethodCallHandler(pluginChannel, (call) async {
        calls.add(call);
        switch (call.method) {
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
          reminder: const TaskReminder(
            time: ReminderTime(hour: 9, minute: 15),
            title: '',
            message: '',
            activeMonthDays: {1, 31},
          ),
        );
        await service.scheduleTask(monthlyTask);
        final alarms = calls
            .where((call) => call.method == 'zonedSchedule')
            .map((call) => call.arguments as Map)
            .toList();
        expect(alarms, hasLength(2));
        expect(
          alarms
              .map(
                (alarm) =>
                    DateTime.parse(alarm['scheduledDateTime'] as String).day,
              )
              .toSet(),
          {1, 31},
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
        expect(monthlyIds, hasLength(2));
        calls.clear();
        await service.scheduleTask(
          Task(
            id: 'monthly',
            type: TaskType.daily,
            title: 'Clean',
            notes: '',
            schedule: const DailySchedule(activeWeekdays: {1}),
            reminder: const TaskReminder(
              time: ReminderTime(hour: 9, minute: 15),
              title: '',
              message: '',
              activeWeekdays: {1},
            ),
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
  });
}
