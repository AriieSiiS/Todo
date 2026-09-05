import '../domain/models.dart';
import 'notification_service_factory.dart';

abstract class NotificationService {
  Stream<NotificationAction> get actions;
  String get permissionIssue;
  Future<void> initialize();
  Future<bool> isAvailable();
  Future<bool> requestPermissions();
  Future<void> syncSchedules({
    required List<NotificationPlan> plans,
    required DeviceNotificationSettings notificationSettings,
  });
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? taskId,
  });
  Future<int> pendingCount();
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

NotificationService createNotificationService() =>
    createNotificationServicePlatform();
