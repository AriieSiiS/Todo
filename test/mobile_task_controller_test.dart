import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/mobile/mobile_lan_client.dart';
import 'package:todo/mobile/mobile_lan_store.dart';
import 'package:todo/mobile/mobile_notification_service.dart';
import 'package:todo/mobile/mobile_task_controller.dart';
import 'package:todo/mobile/mobile_task_snapshot.dart';

void main() {
  test('solo inicia una sincronización mientras espera la credencial',
      () async {
    final store = _Store();
    final client = _Client();
    final controller = MobileTaskController(
        store: store, client: client, notifications: _Notifications());
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.syncing, isTrue);
    expect(await controller.sync(), isFalse);
    store.token.complete('credencial-de-prueba');
    await store.saved.future;
    await Future<void>.delayed(Duration.zero);
    expect(client.calls, 1);
    expect(controller.syncing, isFalse);
  });

  test('un fallo al leer la credencial libera el estado de sincronización',
      () async {
    final store = _Store();
    final controller = MobileTaskController(
        store: store, client: _Client(), notifications: _Notifications());
    addTearDown(controller.dispose);
    await controller.initialize();
    store.token.completeError(StateError('Credencial inaccesible'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.syncing, isFalse);
    expect(controller.error, contains('Credencial inaccesible'));
  });
}

class _Store extends MobileLanStore {
  final token = Completer<String?>();
  final saved = Completer<void>();
  @override
  Future<LanConnectionConfig?> loadConfig() async => const LanConnectionConfig(
        serverId: 'pc',
        deviceId: 'movil',
        endpoint: 'https://127.0.0.1',
        certificateFingerprint: '',
        revision: '',
        lastSyncAt: null,
      );
  @override
  Future<MobileTaskSnapshot?> loadSnapshot() async => null;
  @override
  Future<String?> loadToken() => token.future;
  @override
  Future<void> saveConfig(LanConnectionConfig config) async {
    saved.complete();
  }
}

class _Client extends MobileLanClient {
  int calls = 0;
  @override
  Future<LanSyncResult> sync(
      {required LanConnectionConfig config, required String token}) async {
    calls++;
    return LanSyncResult(changed: false, endpoint: config.endpoint);
  }
}

class _Notifications extends MobileNotificationService {
  @override
  Future<void> initialize() async {}
}
