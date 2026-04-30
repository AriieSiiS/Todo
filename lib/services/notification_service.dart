import '../domain/models.dart';
import 'notification_service_factory.dart';

abstract class NotificationService {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<void> syncSchedules({
    required List<NotificationPlan> plans,
    required DeviceNotificationSettings notificationSettings,
  });
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  });
  Future<void> cancel(int id);
  Future<void> cancelAll();
}

NotificationService createNotificationService() =>
    createNotificationServicePlatform();
