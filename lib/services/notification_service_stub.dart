import '../domain/models.dart';
import 'notification_service.dart';

class StubNotificationService implements NotificationService {
  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> syncSchedules({
    required List<NotificationPlan> plans,
    required DeviceNotificationSettings notificationSettings,
  }) async {}
}

NotificationService createNotificationServicePlatformImpl() =>
    StubNotificationService();
