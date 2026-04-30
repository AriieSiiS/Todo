import '../models.dart';

abstract class NotificationRepository {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<void> syncSchedules({
    required List<NotificationPlan> plans,
    required DeviceNotificationSettings notificationSettings,
  });
}
