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
          reminderRules: const <ReminderRule>[
            ReminderRule(minutesBefore: 30, enabled: true),
          ],
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

  test('los avisos de una tarea se acumulan y generan notificaciones distintas',
      () {
    final scheduler = TaskSchedulerService();
    const settings = DeviceNotificationSettings(
      notificationsEnabled: true,
      dayStartReminderEnabled: false,
      dayEndReminderEnabled: false,
    );
    final task = TaskModel(
      id: 'fisio',
      title: 'Fisio',
      scheduledAt: DateTime(2026, 9, 14, 18, 55),
      reminderRules: const <ReminderRule>[
        ReminderRule(minutesBefore: 0, enabled: true),
        ReminderRule(minutesBefore: 5, enabled: true),
      ],
    );

    final plans = scheduler.buildPlans(
      tasks: [task],
      notes: const [],
      daySettings: const DaySettings(),
      notificationSettings: settings,
      now: DateTime(2026, 9, 14, 18, 35),
    );

    expect(plans, hasLength(2));
    expect(
      plans.map((plan) => plan.when),
      <DateTime>[
        DateTime(2026, 9, 14, 18, 50),
        DateTime(2026, 9, 14, 18, 55),
      ],
    );
    expect(plans.map((plan) => plan.id).toSet(), hasLength(2));
  });

  test('el modelo migra un aviso antiguo y conserva varios en JSON', () {
    final migrated = TaskModel.fromJson(<String, dynamic>{
      'id': 'antigua',
      'title': 'Tarea antigua',
      'reminderRule': <String, dynamic>{
        'minutesBefore': 15,
        'enabled': true,
      },
    });

    expect(migrated.reminderRules, hasLength(1));
    expect(migrated.reminderRules.single.minutesBefore, 15);
    expect(
      migrated.reminderRules.single.deliveryMode,
      ReminderDeliveryMode.normal,
    );

    final restored = TaskModel.fromJson(
      TaskModel(
        id: 'nueva',
        title: 'Tarea nueva',
        reminderRules: const <ReminderRule>[
          ReminderRule(minutesBefore: 0, enabled: true),
          ReminderRule(minutesBefore: 5, enabled: true),
          ReminderRule(minutesBefore: 15, enabled: true),
        ],
      ).toJson(),
    );

    expect(
      restored.reminderRules.map((rule) => rule.minutesBefore),
      <int>[0, 5, 15],
    );
  });

  test('un aviso importante conserva el modo y obtiene identificador estable',
      () {
    final task = TaskModel(
      id: 'horno',
      title: 'Sacar el horno',
      scheduledAt: DateTime(2026, 9, 14, 19),
      reminderRules: const [
        ReminderRule(
          minutesBefore: 5,
          enabled: true,
          deliveryMode: ReminderDeliveryMode.important,
        ),
      ],
    );
    final plans = TaskSchedulerService().buildPlans(
      tasks: [task],
      notes: const [],
      daySettings: const DaySettings(),
      notificationSettings: const DeviceNotificationSettings(
        notificationsEnabled: true,
        dayStartReminderEnabled: false,
        dayEndReminderEnabled: false,
      ),
      now: DateTime(2026, 9, 14, 18),
    );

    expect(plans.single.isImportant, isTrue);
    expect(plans.single.alarmId, isNotEmpty);
    final restored = ReminderRule.fromJson(task.reminderRules.single.toJson());
    expect(restored.deliveryMode, ReminderDeliveryMode.important);
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
