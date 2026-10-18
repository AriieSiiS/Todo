part of 'todo_workspace.dart';

extension TodoWorkspaceNotificaciones on TodoWorkspace {
  Future<void> updateNotificationSettings(
      DeviceNotificationSettings value) async {
    _notificationSettings = value;
    _commit();
  }

  Future<bool> requestNotificationPermissions() async {
    _notificationBusy = true;
    _notifyChanged();
    try {
      final granted = await _notificationService.requestPermissions();
      _notificationAvailable = granted;
      _notificationError = granted ? '' : _notificationService.permissionIssue;
      _notificationSettings = _notificationSettings.copyWith(
        permissionGranted: granted,
      );
      _commit();
      return granted;
    } finally {
      _notificationBusy = false;
      _notifyChanged();
    }
  }

  void setTaskReminder(String taskId, ReminderRule reminder) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final task = _tasks[index];
    final rules = task.reminderRules
        .where((rule) => !_sameReminder(rule, reminder))
        .toList()
      ..add(reminder);
    _tasks[index] = task.copyWith(reminderRules: rules);
    _commit();
  }

  void clearTaskReminder(String taskId, {ReminderRule? reminder}) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final task = _tasks[index];
    _tasks[index] = task.copyWith(
      reminderRules: reminder == null
          ? const <ReminderRule>[]
          : task.reminderRules
              .where((rule) => !_sameReminder(rule, reminder))
              .toList(),
    );
    _commit();
  }

  bool _sameReminder(ReminderRule left, ReminderRule right) {
    return left.triggerMode == right.triggerMode &&
        left.minutesBefore == right.minutesBefore &&
        left.firesAtDayStart == right.firesAtDayStart &&
        left.firesAtDayEnd == right.firesAtDayEnd &&
        left.deliveryMode == right.deliveryMode;
  }

  Future<void> rescheduleTaskReminders() async {
    final plans = _scheduler.buildPlans(
      tasks: tasks,
      notes: notes,
      daySettings: daySettings,
      notificationSettings: notificationSettings,
      now: DateTime.now(),
      fixedPayments: fixedPayments,
    );
    await _importantAlarmService.syncPlans(plans);
    try {
      _notificationAvailable = await _notificationService.isAvailable();
      if (!_notificationAvailable) {
        _scheduledNotificationCount = 0;
        _scheduledTaskNotificationCount = 0;
        _notificationError =
            'Las notificaciones no están disponibles en este dispositivo.';
        _notifyChanged();
        return;
      }
      await _notificationService.syncSchedules(
        plans: plans,
        notificationSettings: notificationSettings,
      );
      _scheduledNotificationCount = await _notificationService.pendingCount();
      _scheduledTaskNotificationCount =
          plans.where((plan) => plan.taskId != null).length;
      _notificationAvailable = true;
      _notificationError = '';
    } catch (error) {
      _scheduledNotificationCount = 0;
      _scheduledTaskNotificationCount = 0;
      _notificationAvailable = false;
      _notificationError = error.toString();
    }
    _notifyChanged();
  }

  Future<bool> sendTestNotification() async {
    _notificationBusy = true;
    _notifyChanged();
    try {
      final granted = await _notificationService.requestPermissions();
      if (!granted) {
        _notificationAvailable = false;
        _notificationError = _notificationService.permissionIssue;
        return false;
      }
      await _notificationService.showTest();
      _notificationAvailable = true;
      _notificationError = '';
      return true;
    } catch (error) {
      _notificationAvailable = false;
      _notificationError = error.toString();
      return false;
    } finally {
      _notificationBusy = false;
      _notifyChanged();
    }
  }

  String? takeNotificationTaskToOpen() {
    final taskId = _pendingNotificationTaskId;
    _pendingNotificationTaskId = null;
    return taskId;
  }

  void _handleNotificationAction(NotificationAction action) {
    if (action.alarmId != null) {
      unawaited(_importantAlarmService.activate(action.alarmId!));
      return;
    }
    _section = AppSection.today;
    _pendingNotificationTaskId = action.taskId;
    _notifyChanged();
  }

  void _handleImportantAlarmChange() => _notifyChanged();

  Future<void> showImportantAlarmTest() => _importantAlarmService.showTest();

  Future<void> stopImportantAlarm({bool keepApplicationOpen = false}) =>
      _importantAlarmService.stopCurrent(
        keepApplicationOpen: keepApplicationOpen,
      );

  Future<void> snoozeImportantAlarm() => _importantAlarmService.snoozeCurrent();

  void reportImportantAlarmAudioError(Object error) =>
      _importantAlarmService.reportAudioError(error);
}
