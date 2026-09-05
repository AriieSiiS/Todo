import '../models.dart';

abstract class NotificationRepository {
  Stream<NotificationAction> get actions;
  String get permissionIssue;
  Future<void> initialize();
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<void> syncSchedules({
    required List<NotificationPlan> plans,
    required DeviceNotificationSettings notificationSettings,
  });
  Future<void> showTest();
  Future<int> pendingCount();
}
