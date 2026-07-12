import 'package:flutter_test/flutter_test.dart';
import 'package:taskforge/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('maps Android GMT timezone alias to Etc/UTC', () {
    NotificationService.configureLocalTimezone('GMT');

    expect(tz.local.name, 'Etc/UTC');
  });

  test('falls back to Etc/UTC for an unknown timezone', () {
    NotificationService.configureLocalTimezone('Unknown/Timezone');

    expect(tz.local.name, 'Etc/UTC');
  });
}
