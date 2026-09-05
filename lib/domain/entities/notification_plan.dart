class NotificationPlan {
  const NotificationPlan({
    required this.id,
    required this.title,
    required this.body,
    required this.when,
    this.taskId,
  });

  final int id;
  final String title;
  final String body;
  final DateTime when;
  final String? taskId;
}

class NotificationAction {
  const NotificationAction({this.taskId});

  final String? taskId;
}
