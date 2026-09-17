import 'enums.dart';

class NotificationPlan {
  const NotificationPlan({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    this.taskId,
    this.deliveryMode = ReminderDeliveryMode.normal,
    this.alarmId,
    this.minutesBefore = 0,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String? taskId;
  final ReminderDeliveryMode deliveryMode;
  final String? alarmId;
  final int minutesBefore;

  bool get isImportant => deliveryMode == ReminderDeliveryMode.important;
}

class NotificationAction {
  const NotificationAction({this.taskId, this.alarmId, this.actionId});

  final String? taskId;
  final String? alarmId;
  final String? actionId;
}
