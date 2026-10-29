import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../features/alerts/data/alert.dart';

/// Local reminders that tell the user a scheduled alert is ready to send from
/// their phone. The backend stays the source of truth; [sync] reconciles.
class AlertReminders {
  AlertReminders({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Emits the alert id when the user taps a reminder.
  final ValueNotifier<String?> tappedAlertId = ValueNotifier(null);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'alert_reminders',
      'Alert reminders',
      channelDescription: 'Reminds you when an alert is ready to send',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => tappedAlertId.value = response.payload,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      tappedAlertId.value = launch!.notificationResponse?.payload;
    }
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  Future<void> schedule(Alert alert) async {
    if (alert.state != AlertState.scheduled || !alert.isDeviceChannel) return;
    await _plugin.zonedSchedule(
      id: notificationId(alert.id),
      title: 'Time to alert ${alert.recipientName ?? 'your contact'}',
      body: 'Still no reply on ${alert.platform.label}? Tap to send the SMS.',
      scheduledDate: tz.TZDateTime.from(alert.dueAt, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: alert.id,
    );
  }

  Future<void> cancel(String alertId) => _plugin.cancel(id: notificationId(alertId));

  /// Makes local reminders match the server's open alerts.
  Future<void> sync(List<Alert> openAlerts) async {
    final wanted = {
      for (final a in openAlerts.where((a) => a.state == AlertState.scheduled && a.isDeviceChannel))
        notificationId(a.id): a,
    };
    for (final pending in await _plugin.pendingNotificationRequests()) {
      if (!wanted.containsKey(pending.id)) await _plugin.cancel(id: pending.id);
    }
    for (final alert in wanted.values) {
      await schedule(alert);
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Stable 31-bit id derived from the alert UUID.
  @visibleForTesting
  static int notificationId(String alertId) {
    var hash = 0;
    for (final unit in alertId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
