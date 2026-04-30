import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../domain/models.dart';
import 'notification_service.dart';

@JS('Notification')
extension type _BrowserNotification(JSObject _) implements JSObject {
  external static JSString get permission;
  external static JSPromise<JSString> requestPermission();
}

@JS('Notification')
external JSFunction _browserNotificationConstructor;

class WebNotificationService implements NotificationService {
  final Map<int, Timer> _timers = <int, Timer>{};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async {
    final permission = await _BrowserNotification.requestPermission().toDart;
    return permission.toDart == 'granted';
  }

  @override
  Future<void> syncSchedules({
    required List<NotificationPlan> plans,
    required DeviceNotificationSettings notificationSettings,
  }) async {
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
    final permission = _BrowserNotification.permission.toDart;
    if (permission != 'granted') {
      return;
    }
    _browserNotificationConstructor.callAsConstructor(title.toJS);
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
    WebNotificationService();
