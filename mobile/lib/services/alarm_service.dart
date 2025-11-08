import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ScheduledAlarm {
  ScheduledAlarm({
    required this.scheduledAt,
    required this.requireTranscription,
    this.note,
  });

  final DateTime scheduledAt;
  final bool requireTranscription;
  final String? note;
}

class WakeAlarmService {
  WakeAlarmService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'dream_weave_alarm_channel';
  static const _notificationId = 1123;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialised = false;
  ScheduledAlarm? _scheduledAlarm;

  ScheduledAlarm? get scheduledAlarm => _scheduledAlarm;

  Future<void> initialise() async {
    if (_initialised) {
      return;
    }

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: false,
    );

    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    _initialised = true;
  }

  Future<ScheduledAlarm> scheduleAlarm({
    required TimeOfDay time,
    bool requireTranscription = true,
    String? note,
  }) async {
    await initialise();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'DreamWeave Wake Alarm',
      channelDescription: 'Alarm nudging you to capture your dream transcripts.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      fullScreenIntent: true,
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true, presentAlert: true);

    await _plugin.zonedSchedule(
      _notificationId,
      'Time to capture your dream',
      requireTranscription
          ? 'Stop the alarm by recording a quick voice note. ${note ?? ''}'.trim()
          : 'Open DreamWeave to jot down the fragments you remember.',
      scheduled,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    final alarm = ScheduledAlarm(
      scheduledAt: scheduled.toLocal(),
      requireTranscription: requireTranscription,
      note: note,
    );
    _scheduledAlarm = alarm;
    return alarm;
  }

  Future<void> cancel() async {
    await initialise();
    await _plugin.cancel(_notificationId);
    _scheduledAlarm = null;
  }
}
