import '../../domain/models.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../services/notification_service.dart';

class NotificationServiceRepository implements NotificationRepository {
  NotificationServiceRepository(this._service);

  final NotificationService _service;

  @override
  Future<void> initialize() => _service.initialize();

  @override
  Future<bool> requestPermissions() => _service.requestPermissions();

  @override
  Future<void> syncSchedules({
    required List<NotificationPlan> plans,
    required DeviceNotificationSettings notificationSettings,
  }) =>
      _service.syncSchedules(
        plans: plans,
        notificationSettings: notificationSettings,
      );
}
