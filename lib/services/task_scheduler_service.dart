import '../domain/models.dart';

class TaskSchedulerService {
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
          ),
        );
      }
    }

    if (notificationSettings.dayStartReminderEnabled) {
      final nextStart = _nextDayStart(now, daySettings.nextDayVisibleAtHour);
      plans.add(
        NotificationPlan(
          id: 910001,
          title: 'Comienza tu día real',
          body:
              'Tienes ${tasks.where((task) => task.status == TaskStatus.active).length} tareas activas para revisar.',
          when: nextStart,
        ),
      );
    }

    if (notificationSettings.dayEndReminderEnabled &&
        notes.any((note) => note.status == NoteStatus.inbox)) {
      final nextEndWarning = _nextDayEndWarning(now, daySettings.dayEndsAtHour);
      plans.add(
        NotificationPlan(
          id: 910002,
          title: 'Notas pendientes antes del cierre del día',
          body:
              'Todavía tienes ${notes.where((note) => note.status == NoteStatus.inbox).length} notas sin procesar.',
          when: nextEndWarning,
        ),
      );
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

  DateTime _nextDayStart(DateTime now, int hour) {
    final candidate = DateTime(now.year, now.month, now.day, hour);
    return candidate.isAfter(now)
        ? candidate
        : candidate.add(const Duration(days: 1));
  }

  DateTime _nextDayEndWarning(DateTime now, int dayEndsAtHour) {
    final warningHour = dayEndsAtHour == 0 ? 23 : dayEndsAtHour - 1;
    final candidate = DateTime(now.year, now.month, now.day, warningHour);
    return candidate.isAfter(now)
        ? candidate
        : candidate.add(const Duration(days: 1));
  }
}
