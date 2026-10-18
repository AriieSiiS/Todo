import '../../domain/models.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../services/notification_service.dart';

class NotificationServiceRepository implements NotificationRepository {
  NotificationServiceRepository(this._service);

  final NotificationService _service;

  @override
  Stream<NotificationAction> get actions => _service.actions;

  @override
  String get permissionIssue => _service.permissionIssue;

  @override
  Future<void> initialize() => _service.initialize();

  @override
  Future<bool> isAvailable() => _service.isAvailable();

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

  @override
  Future<void> showTest() => _service.showNow(
        id: 919999,
        title: 'Todo está listo',
        body: 'Las notificaciones de Windows funcionan correctamente.',
      );

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) =>
      _service.showNow(id: id, title: title, body: body);

  @override
  Future<int> pendingCount() => _service.pendingCount();
}
