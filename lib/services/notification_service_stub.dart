import '../domain/models.dart';
import 'notification_service.dart';

class StubNotificationService implements NotificationService {
  @override
  Stream<NotificationAction> get actions => const Stream.empty();

  @override
  String get permissionIssue =>
      'Las notificaciones no están disponibles en esta plataforma.';

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? taskId,
  }) async {}

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<void> syncSchedules({
    required List<NotificationPlan> plans,
    required DeviceNotificationSettings notificationSettings,
  }) async {}
}

NotificationService createNotificationServicePlatformImpl() =>
    StubNotificationService();
