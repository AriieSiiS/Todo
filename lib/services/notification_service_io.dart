import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:win32_registry/win32_registry.dart';

import '../domain/models.dart';
import 'notification_service.dart';

class IoNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<NotificationAction> _actions =
      StreamController<NotificationAction>.broadcast(sync: true);
  bool _initialized = false;
  bool _available = false;
  String _permissionIssue = '';

  @override
  Stream<NotificationAction> get actions => _actions.stream;

  @override
  String get permissionIssue => _permissionIssue;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
      tz_data.initializeTimeZones();
      _available = await _notifications.initialize(
            settings: InitializationSettings(
              android:
                  const AndroidInitializationSettings('@mipmap/ic_launcher'),
              iOS: const DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              ),
              windows: WindowsInitializationSettings(
                appName: 'Todo',
                appUserModelId: 'AlejandroAfonso.Todo.App',
                guid: 'cf7b9a93-31fc-45c5-8cee-31f61b7aac84',
                iconPath:
                    '${File(Platform.resolvedExecutable).parent.path}\\data\\flutter_assets\\assets\\branding\\todo_logo.png',
              ),
            ),
            onDidReceiveNotificationResponse: _handleResponse,
          ) ??
          false;

      final launchDetails =
          await _notifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        _emitPayload(launchDetails?.notificationResponse?.payload);
      }
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
    if (Platform.isWindows) {
      if (!_windowsToastsEnabled()) {
        _permissionIssue =
            'Las notificaciones están desactivadas en los ajustes de Windows.';
        return false;
      }
      _permissionIssue = '';
      return _available;
    }
    _permissionIssue =
        'Las notificaciones no están disponibles en este dispositivo.';
    return false;
  }

  @override
  Future<bool> isAvailable() async {
    await initialize();
    return _available;
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

    if (!_available) {
      return;
    }

    if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
      for (final plan in plans) {
        if (plan.when.isBefore(DateTime.now())) {
          continue;
        }
        await _notifications.zonedSchedule(
          id: plan.id,
          title: plan.title,
          body: plan.body,
          scheduledDate: tz.TZDateTime.from(plan.when, tz.UTC),
          notificationDetails: _notificationDetails(plan: plan),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: _payloadFor(plan.taskId, alarmId: plan.alarmId),
        );
      }
    }
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? taskId,
  }) async {
    await initialize();
    if (_available &&
        (Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
      await _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _notificationDetails(),
        payload: _payloadFor(taskId),
      );
    }
  }

  @override
  Future<int> pendingCount() async {
    await initialize();
    if (!_available ||
        !(Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
      return 0;
    }
    return (await _notifications.pendingNotificationRequests()).length;
  }

  @override
  Future<void> cancel(int id) async {
    if (_available &&
        (Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
      await _notifications.cancel(id: id);
    }
  }

  @override
  Future<void> cancelAll() async {
    if (_available &&
        (Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
      await _notifications.cancelAll();
    }
  }

  NotificationDetails _notificationDetails({NotificationPlan? plan}) {
    final important = plan?.isImportant ?? false;
    return NotificationDetails(
      android: const AndroidNotificationDetails(
        'todo_task_reminders',
        'Recordatorios de tareas',
        channelDescription: 'Avisos de tareas programadas en Todo.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(
        duration: important
            ? WindowsNotificationDuration.long
            : WindowsNotificationDuration.short,
        scenario: important ? WindowsNotificationScenario.urgent : null,
        actions: important
            ? const <WindowsAction>[
                WindowsAction(
                  content: 'Abrir alarma',
                  arguments: 'open_alarm',
                ),
              ]
            : const <WindowsAction>[],
      ),
    );
  }

  String _payloadFor(String? taskId, {String? alarmId}) {
    if (alarmId != null) {
      return 'alarm:$alarmId${taskId == null ? '' : '|task:$taskId'}';
    }
    return taskId == null ? 'section:today' : 'task:$taskId';
  }

  void _handleResponse(NotificationResponse response) {
    _emitPayload(response.payload, actionId: response.actionId);
  }

  void _emitPayload(String? payload, {String? actionId}) {
    if (payload == null || payload.isEmpty) {
      return;
    }
    String? taskId;
    String? alarmId;
    for (final part in payload.split('|')) {
      if (part.startsWith('task:')) taskId = part.substring(5);
      if (part.startsWith('alarm:')) alarmId = part.substring(6);
    }
    _actions.add(NotificationAction(
      taskId: taskId,
      alarmId: alarmId,
      actionId: actionId,
    ));
  }

  bool _windowsToastsEnabled() {
    const keyPath =
        r'Software\Microsoft\Windows\CurrentVersion\PushNotifications';
    try {
      final key = Registry.openPath(RegistryHive.currentUser, path: keyPath);
      try {
        return (key.getIntValue('ToastEnabled') ?? 1) != 0;
      } finally {
        key.close();
      }
    } catch (_) {
      return true;
    }
  }
}

NotificationService createNotificationServicePlatformImpl() =>
    IoNotificationService();
