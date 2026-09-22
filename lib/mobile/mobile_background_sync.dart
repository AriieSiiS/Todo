import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'mobile_lan_client.dart';
import 'mobile_lan_store.dart';
import 'mobile_notification_service.dart';
import 'mobile_task_snapshot.dart';

const String mobileDailySyncUniqueName = 'todo-lan-daily-sync-v1';
const String mobileDailySyncTaskName = 'sincronizar-tareas-locales';

@pragma('vm:entry-point')
void mobileBackgroundDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (task != mobileDailySyncTaskName) return true;
    final store = MobileLanStore();
    final config = await store.loadConfig();
    final token = await store.loadToken();
    if (config == null || token == null || token.isEmpty) return true;
    try {
      final result = await MobileLanClient().sync(config: config, token: token);
      var updated = config.copyWith(
        endpoint: result.endpoint,
        lastSyncAt: DateTime.now(),
      );
      if (result.changed && result.snapshot != null) {
        await store.saveSnapshot(result.snapshot!);
        final snapshot = MobileTaskSnapshot.fromJson(result.snapshot!);
        updated = updated.copyWith(revision: snapshot.revision);
        await MobileNotificationService().syncSnapshot(snapshot);
      }
      await store.saveConfig(updated);
      return true;
    } catch (_) {
      return true;
    }
  });
}

Future<void> initializeMobileBackgroundSync() async {
  if (!Platform.isAndroid) return;
  await Workmanager().initialize(mobileBackgroundDispatcher);
}

Future<void> scheduleMobileDailySync() async {
  if (!Platform.isAndroid) return;
  final now = DateTime.now();
  var nextMorning = DateTime(now.year, now.month, now.day, 7);
  if (!nextMorning.isAfter(now)) {
    nextMorning = nextMorning.add(const Duration(days: 1));
  }
  await Workmanager().registerPeriodicTask(
    mobileDailySyncUniqueName,
    mobileDailySyncTaskName,
    frequency: const Duration(days: 1),
    flexInterval: const Duration(hours: 3),
    initialDelay: nextMorning.difference(now),
    constraints: Constraints(
      networkType: NetworkType.unmetered,
      requiresBatteryNotLow: true,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}

Future<void> cancelMobileDailySync() async {
  if (!Platform.isAndroid) return;
  await Workmanager().cancelByUniqueName(mobileDailySyncUniqueName);
}
