import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart';
import 'mobile_task_snapshot.dart';

const String _normalChannelId = 'todo_mobile_reminders_v1';
const String _importantChannelId = 'todo_mobile_important_alarms_v1';

@pragma('vm:entry-point')
Future<void> mobileNotificationBackgroundResponse(
  NotificationResponse response,
) async {
  if (response.actionId != 'snooze') return;
  final service = MobileNotificationService();
  await service.initialize();
  await service.snooze(response);
}

class MobileNotificationPermissionState {
  const MobileNotificationPermissionState({
    required this.notifications,
    required this.exactAlarms,
    required this.fullScreenAlarms,
  });

  final bool notifications;
  final bool exactAlarms;
  final bool fullScreenAlarms;

  bool get fullyGranted => notifications && exactAlarms && fullScreenAlarms;
}

class MobileNotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<MobileNotificationOpen> _openedTasks =
      StreamController<MobileNotificationOpen>.broadcast();
  bool _initialized = false;

  Stream<MobileNotificationOpen> get openedTasks => _openedTasks.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _handleResponse,
      onDidReceiveBackgroundNotificationResponse:
          mobileNotificationBackgroundResponse,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _emitTask(
        launch?.notificationResponse?.payload,
        id: launch?.notificationResponse?.id,
      );
    }
    _initialized = true;
  }

  Future<MobileNotificationPermissionState> requestPermissions() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notifications =
        await android?.requestNotificationsPermission() ?? false;
    final exact = await android?.requestExactAlarmsPermission() ?? false;
    final fullScreen =
        await android?.requestFullScreenIntentPermission() ?? false;
    return MobileNotificationPermissionState(
      notifications: notifications,
      exactAlarms: exact,
      fullScreenAlarms: fullScreen,
    );
  }

  Future<void> syncSnapshot(MobileTaskSnapshot snapshot) async {
    await initialize();
    final desired = _plans(snapshot);
    final pending = await _plugin.pendingNotificationRequests();
    final desiredIds = desired.map((plan) => plan.id).toSet();
    for (final request in pending) {
      if (_isTodoPayload(request.payload) && !desiredIds.contains(request.id)) {
        await _plugin.cancel(id: request.id);
      }
    }
    final pendingIds = pending.map((request) => request.id).toSet();
    for (final plan in desired) {
      if (pendingIds.contains(plan.id)) continue;
      await _schedule(plan);
    }
  }

  Future<void> cancelAllTodoNotifications() async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (_isTodoPayload(request.payload)) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  Future<void> snooze(NotificationResponse response) async {
    final payload = _decodePayload(response.payload);
    if (payload == null) return;
    final plan = _MobileNotificationPlan(
      id: response.id ?? _stableId('${payload['taskId']}:snooze'),
      taskId: payload['taskId'] as String? ?? '',
      title: payload['title'] as String? ?? 'Alarma importante',
      body: payload['body'] as String? ?? 'Tarea pendiente',
      when: DateTime.now().add(const Duration(minutes: 5)),
      important: true,
    );
    await _schedule(plan);
  }

  Future<void> stopAlarm(MobileNotificationOpen alarm) async {
    if (alarm.id != null) await _plugin.cancel(id: alarm.id!);
  }

  Future<void> snoozeAlarm(MobileNotificationOpen alarm) async {
    final plan = _MobileNotificationPlan(
      id: alarm.id ?? _stableId('${alarm.taskId}:snooze'),
      taskId: alarm.taskId,
      title: alarm.title,
      body: alarm.body,
      when: DateTime.now().add(const Duration(minutes: 5)),
      important: true,
    );
    if (alarm.id != null) await _plugin.cancel(id: alarm.id!);
    await _schedule(plan);
  }

  List<_MobileNotificationPlan> _plans(MobileTaskSnapshot snapshot) {
    final now = DateTime.now();
    final result = <_MobileNotificationPlan>[];
    for (final task in snapshot.tasks.where(
      (value) =>
          value.status == TaskStatus.active &&
          !value.isSubtask &&
          value.reminderRules.any((rule) => rule.enabled),
    )) {
      final scheduled = _nextScheduledOccurrence(snapshot, task, now);
      if (scheduled == null) continue;
      final seen = <DateTime>{};
      for (final reminder in task.reminderRules.where((rule) => rule.enabled)) {
        final trigger =
            reminder.triggerMode == ReminderTriggerMode.minutesBefore
                ? scheduled.subtract(Duration(minutes: reminder.minutesBefore))
                : scheduled;
        if (!trigger.isAfter(now) || !seen.add(trigger)) continue;
        final body =
            'Programada para las ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}';
        result.add(
          _MobileNotificationPlan(
            id: _stableId(
              '${task.id}:${trigger.toUtc().toIso8601String()}:${reminder.deliveryMode.name}',
            ),
            taskId: task.id,
            title: task.title,
            body: body,
            when: trigger,
            important: reminder.isImportant,
          ),
        );
      }
    }
    return result;
  }

  DateTime? _nextScheduledOccurrence(
    MobileTaskSnapshot snapshot,
    TaskModel task,
    DateTime now,
  ) {
    final scheduled = task.scheduledAt;
    if (scheduled == null) return null;
    if (!task.recurrence.isRecurring) return scheduled;
    final today = snapshot.logicalDate(now);
    for (var offset = 0; offset <= 366; offset++) {
      final day = today.add(Duration(days: offset));
      if (snapshot.occursOnDay(task, day, today: today)) {
        final occurrence = DateTime(
          day.year,
          day.month,
          day.day,
          scheduled.hour,
          scheduled.minute,
        );
        if (occurrence.isAfter(now)) return occurrence;
      }
    }
    return null;
  }

  Future<void> _schedule(_MobileNotificationPlan plan) async {
    final details = NotificationDetails(
      android: plan.important
          ? AndroidNotificationDetails(
              _importantChannelId,
              'Alarmas importantes',
              channelDescription:
                  'Alarmas persistentes para avisos importantes de Todo.',
              importance: Importance.max,
              priority: Priority.max,
              category: AndroidNotificationCategory.alarm,
              fullScreenIntent: true,
              ongoing: true,
              autoCancel: false,
              enableVibration: true,
              playSound: true,
              audioAttributesUsage: AudioAttributesUsage.alarm,
              additionalFlags: Int32List.fromList(const [4]),
              actions: const [
                AndroidNotificationAction(
                  'stop',
                  'Detener',
                  cancelNotification: true,
                ),
                AndroidNotificationAction(
                  'snooze',
                  'Posponer 5 minutos',
                  showsUserInterface: false,
                ),
                AndroidNotificationAction(
                  'open',
                  'Ver tarea',
                  showsUserInterface: true,
                ),
              ],
            )
          : const AndroidNotificationDetails(
              _normalChannelId,
              'Recordatorios de tareas',
              channelDescription: 'Avisos de tareas sincronizadas con Todo.',
              importance: Importance.high,
              priority: Priority.high,
            ),
    );
    final payload = jsonEncode({
      'source': 'todo-lan',
      'taskId': plan.taskId,
      'title': plan.title,
      'body': plan.body,
      'important': plan.important,
    });
    try {
      await _plugin.zonedSchedule(
        id: plan.id,
        title: plan.title,
        body: plan.body,
        scheduledDate: tz.TZDateTime.from(plan.when, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: plan.important
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id: plan.id,
        title: plan.title,
        body: plan.body,
        scheduledDate: tz.TZDateTime.from(plan.when, tz.UTC),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  void _handleResponse(NotificationResponse response) {
    if (response.actionId == 'snooze') {
      unawaited(snooze(response));
      return;
    }
    if (response.actionId == 'stop') return;
    _emitTask(response.payload, id: response.id);
  }

  void _emitTask(String? payload, {int? id}) {
    final decoded = _decodePayload(payload);
    final taskId = decoded?['taskId'] as String?;
    if (taskId != null && taskId.isNotEmpty) {
      _openedTasks.add(
        MobileNotificationOpen(
          id: id,
          taskId: taskId,
          title: decoded?['title'] as String? ?? 'Tarea pendiente',
          body: decoded?['body'] as String? ?? '',
          important: decoded?['important'] as bool? ?? false,
        ),
      );
    }
  }

  Map<String, dynamic>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['source'] == 'todo-lan') {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {}
    return null;
  }

  bool _isTodoPayload(String? payload) => _decodePayload(payload) != null;
}

class MobileNotificationOpen {
  const MobileNotificationOpen({
    required this.id,
    required this.taskId,
    required this.title,
    required this.body,
    required this.important,
  });

  final int? id;
  final String taskId;
  final String title;
  final String body;
  final bool important;
}

class _MobileNotificationPlan {
  const _MobileNotificationPlan({
    required this.id,
    required this.taskId,
    required this.title,
    required this.body,
    required this.when,
    required this.important,
  });

  final int id;
  final String taskId;
  final String title;
  final String body;
  final DateTime when;
  final bool important;
}

int _stableId(String value) {
  final bytes = sha256.convert(utf8.encode(value)).bytes;
  return ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
      0x7fffffff;
}
