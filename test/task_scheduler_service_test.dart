import 'package:flutter_test/flutter_test.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/services/task_scheduler_service.dart';

void main() {
  test('task reminders retain their task destination', () {
    final now = DateTime(2026, 9, 5, 10);
    final plans = TaskSchedulerService().buildPlans(
      tasks: [
        TaskModel(
          id: 'task-1',
          title: 'Comprar pan',
          scheduledAt: DateTime(2026, 9, 5, 12),
          reminderRule: const ReminderRule(
            minutesBefore: 30,
            enabled: true,
          ),
        ),
      ],
      notes: const [],
      daySettings: const DaySettings(),
      notificationSettings: const DeviceNotificationSettings(
        notificationsEnabled: true,
        dayStartReminderEnabled: false,
        dayEndReminderEnabled: false,
      ),
      now: now,
    );

    expect(plans, hasLength(1));
    expect(plans.single.taskId, 'task-1');
    expect(plans.single.when, DateTime(2026, 9, 5, 11, 30));
  });

  test('daily reminders are materialized for the next 45 days', () {
    final now = DateTime(2026, 9, 5, 4);
    final plans = TaskSchedulerService().buildPlans(
      tasks: const [],
      notes: const [],
      daySettings: const DaySettings(nextDayVisibleAtHour: 6),
      notificationSettings: const DeviceNotificationSettings(
        notificationsEnabled: true,
        dayStartReminderEnabled: true,
        dayEndReminderEnabled: false,
      ),
      now: now,
    );

    expect(plans, hasLength(45));
    expect(plans.first.when, DateTime(2026, 9, 5, 6));
    expect(plans.last.when, DateTime(2026, 10, 19, 6));
    expect(plans.map((plan) => plan.id).toSet(), hasLength(45));
  });
}
