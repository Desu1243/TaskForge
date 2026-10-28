import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskforge/services/notification_service.dart';
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

  group('notification taps', () {
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

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      fromNotification = false;
      failLaunchDetails = false;
      messenger.setMockMethodCallHandler(
        timezoneChannel,
        (_) async => 'Europe/Warsaw',
      );
      messenger.setMockMethodCallHandler(permissionChannel, (_) async => true);
      messenger.setMockMethodCallHandler(pluginChannel, (call) async {
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
  });
}
