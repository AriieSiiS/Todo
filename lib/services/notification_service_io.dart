import 'dart:async';

import '../domain/models.dart';
import 'notification_service.dart';

class IoNotificationService implements NotificationService {
  final Map<int, Timer> _timers = <int, Timer>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async {
    await initialize();
    return true;
  }

  @override
  Future<void> syncSchedules({
    required List<NotificationPlan> plans,
    required DeviceNotificationSettings notificationSettings,
  }) async {
    await initialize();
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    if (!notificationSettings.notificationsEnabled) {
      return;
    }

    for (final plan in plans) {
      final delay = plan.when.difference(DateTime.now());
      if (delay.isNegative) {
        continue;
      }
      _timers[plan.id] = Timer(delay, () async {
        await showNow(id: plan.id, title: plan.title, body: plan.body);
      });
    }
  }

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await initialize();
    // Placeholder for desktop-local notifications without native plugin dependency.
  }

  @override
  Future<void> cancel(int id) async {
    _timers.remove(id)?.cancel();
  }

  @override
  Future<void> cancelAll() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

NotificationService createNotificationServicePlatformImpl() =>
    IoNotificationService();
