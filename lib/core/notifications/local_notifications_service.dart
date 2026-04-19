import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationsService {
  LocalNotificationsService._();
  static final LocalNotificationsService instance = LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const settings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
        macOS: iosInit,
      );

      await _plugin.initialize(settings);
      _initialized = true;
    } on MissingPluginException {
      // Plugin may be temporarily unavailable after hot restart/platform rebuild.
      _initialized = false;
    }
  }

  Future<void> requestPermissions() async {
    await initialize();
    if (!_initialized) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> syncWeeklyReminder({
    required bool enabled,
    required int hour,
    required int minute,
    required List<bool> days,
  }) async {
    await initialize();
    if (!_initialized) return;
    await _cancelReminderSeries();

    if (!enabled) return;
    if (days.length != 7) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_habit_reminder',
        'Alışkanlık Hatırlatıcıları',
        channelDescription: 'Alışkanlıklar için günlük/haftalık hatırlatmalar',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    for (int i = 0; i < days.length; i++) {
      if (!days[i]) continue;
      final targetWeekday = _weekdayFromIndex(i);
      final next = _nextWeeklyTime(
        weekday: targetWeekday,
        hour: hour,
        minute: minute,
      );
      await _plugin.zonedSchedule(
        _idFromDayIndex(i),
        'Octy',
        'Bugünkü alışkanlıklarını tamamlamayı unutma.',
        next,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _cancelReminderSeries() async {
    for (int i = 0; i < 7; i++) {
      await _plugin.cancel(_idFromDayIndex(i));
    }
  }

  int _idFromDayIndex(int index) => 7000 + index;

  int _weekdayFromIndex(int index) {
    // UI index: 0..6 => Sun..Sat, weekday: Mon=1..Sun=7
    if (index == 0) return DateTime.sunday;
    return index;
  }

  tz.TZDateTime _nextWeeklyTime({
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
