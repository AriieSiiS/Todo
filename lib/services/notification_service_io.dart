import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart';
import 'notification_service.dart';

class IoNotificationService implements NotificationService {
  final Map<int, Timer> _timers = <int, Timer>{};
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      tz_data.initializeTimeZones();
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
    }
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();
    if (Platform.isAndroid) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<void> syncSchedules({
    required List<NotificationPlan> plans,
    required DeviceNotificationSettings notificationSettings,
  }) async {
    await initialize();
    await cancelAll();

    if (!notificationSettings.notificationsEnabled) {
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      for (final plan in plans) {
        if (plan.when.isBefore(DateTime.now())) {
          continue;
        }
        await _notifications.zonedSchedule(
          id: plan.id,
          title: plan.title,
          body: plan.body,
          scheduledDate: tz.TZDateTime.from(plan.when, tz.local),
          notificationDetails: _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      return;
    }

    for (final plan in plans) {
      final delay = plan.when.difference(DateTime.now());
      if (delay.isNegative) {
        continue;
      }
      _timers[plan.id] = Timer(delay, () async {
        await showNow(id: plan.id, title: plan.title, body: plan.body);
      });
    }
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (Platform.isAndroid || Platform.isIOS) {
      await _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _notificationDetails(),
      );
    }
    // Windows keeps timer scheduling as a lightweight local fallback for now.
  }

  @override
  Future<void> cancel(int id) async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _notifications.cancel(id: id);
    }
    _timers.remove(id)?.cancel();
  }

  @override
  Future<void> cancelAll() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _notifications.cancelAll();
    }
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'todo_task_reminders',
        'Recordatorios de tareas',
        channelDescription: 'Avisos de tareas programadas en Todo.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }
}

NotificationService createNotificationServicePlatformImpl() =>
    IoNotificationService();
