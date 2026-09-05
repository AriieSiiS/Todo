import '../domain/models.dart';

class TaskSchedulerService {
  static const int _dailyReminderHorizonDays = 45;

  List<NotificationPlan> buildPlans({
    required List<TaskModel> tasks,
    required List<QuickNote> notes,
    required DaySettings daySettings,
    required DeviceNotificationSettings notificationSettings,
    required DateTime now,
  }) {
    if (!notificationSettings.notificationsEnabled) {
      return const <NotificationPlan>[];
    }

    final plans = <NotificationPlan>[];

    for (final task in tasks) {
      final reminder = task.reminderRule;
      final scheduledAt = task.scheduledAt;
      if (task.status != TaskStatus.active ||
          scheduledAt == null ||
          reminder == null ||
          !reminder.enabled) {
        continue;
      }
      final trigger = reminder.triggerMode == ReminderTriggerMode.minutesBefore
          ? scheduledAt.subtract(Duration(minutes: reminder.minutesBefore))
          : scheduledAt;
      if (trigger.isAfter(now)) {
        plans.add(
          NotificationPlan(
            id: task.id.hashCode,
            title: task.title,
            body: _taskBody(task),
            when: trigger,
            taskId: task.id,
          ),
        );
      }
    }

    if (notificationSettings.dayStartReminderEnabled) {
      for (var offset = 0; offset < _dailyReminderHorizonDays; offset++) {
        final date = now.add(Duration(days: offset));
        final trigger = DateTime(
          date.year,
          date.month,
          date.day,
          daySettings.nextDayVisibleAtHour,
        );
        if (!trigger.isAfter(now)) {
          continue;
        }
        plans.add(
          NotificationPlan(
            id: 100000000 + _dateKey(trigger),
            title: 'Comienza tu día real',
            body:
                'Tienes ${tasks.where((task) => task.status == TaskStatus.active).length} tareas activas para revisar.',
            when: trigger,
          ),
        );
      }
    }

    if (notificationSettings.dayEndReminderEnabled &&
        notes.any((note) => note.status == NoteStatus.inbox)) {
      final warningHour =
          daySettings.dayEndsAtHour == 0 ? 23 : daySettings.dayEndsAtHour - 1;
      for (var offset = 0; offset < _dailyReminderHorizonDays; offset++) {
        final date = now.add(Duration(days: offset));
        final trigger = DateTime(date.year, date.month, date.day, warningHour);
        if (!trigger.isAfter(now)) {
          continue;
        }
        plans.add(
          NotificationPlan(
            id: 200000000 + _dateKey(trigger),
            title: 'Notas pendientes antes del cierre del día',
            body:
                'Todavía tienes ${notes.where((note) => note.status == NoteStatus.inbox).length} notas sin procesar.',
            when: trigger,
          ),
        );
      }
    }

    plans.sort((left, right) => left.when.compareTo(right.when));
    return plans;
  }

  String _taskBody(TaskModel task) {
    if (task.scheduledAt == null) {
      return 'Tarea pendiente';
    }
    final hour = task.scheduledAt!.hour.toString().padLeft(2, '0');
    final minute = task.scheduledAt!.minute.toString().padLeft(2, '0');
    return 'Programada para las $hour:$minute';
  }

  int _dateKey(DateTime value) =>
      value.year * 10000 + value.month * 100 + value.day;
}
