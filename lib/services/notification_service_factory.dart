import 'notification_service.dart';
import 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_io.dart';

NotificationService createNotificationServicePlatform() =>
    createNotificationServicePlatformImpl();
