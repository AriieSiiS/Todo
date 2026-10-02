import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/mobile/mobile_lan_client.dart';
import 'package:todo/mobile/mobile_lan_store.dart';
import 'package:todo/mobile/mobile_notification_service.dart';
import 'package:todo/mobile/mobile_task_controller.dart';
import 'package:todo/mobile/mobile_task_snapshot.dart';
import 'package:todo/mobile/mobile_wardrobe_snapshot.dart';
import 'package:todo/mobile/mobile_wardrobe_store.dart';

void main() {
  test('solo inicia una sincronización mientras espera la credencial',
      () async {
    final store = _Store();
    final client = _Client();
    final controller = MobileTaskController(
        store: store,
        client: client,
        notifications: _Notifications(),
        wardrobeStore: _WardrobeStore());
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
        store: store,
        client: _Client(),
        notifications: _Notifications(),
        wardrobeStore: _WardrobeStore());
    addTearDown(controller.dispose);
    await controller.initialize();
    store.token.completeError(StateError('Credencial inaccesible'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.syncing, isFalse);
    expect(controller.error, contains('Credencial inaccesible'));
  });

  test('la maleta descuenta unidades y conserva las marcas al reabrir',
      () async {
    final wardrobe = _WardrobeStore(
      snapshot: MobileWardrobeSnapshot.fromJson({
        'protocolVersion': 1,
        'wardrobeVersion': 1,
        'serverId': 'pc',
        'revision': 'uno',
        'items': [
          {'id': 'camisa', 'name': 'Camisa', 'imageAvailable': false}
        ],
        'packingLists': [
          {
            'id': 'viaje',
            'entries': [
              {'itemId': 'camisa', 'quantity': 3, 'packed': false}
            ],
          }
        ],
      }),
    );
    final controller = MobileTaskController(
      store: _PairedStore(),
      client: _Client(),
      notifications: _Notifications(),
      wardrobeStore: wardrobe,
    );
    await controller.initialize();
    final entry =
        controller.wardrobeSnapshot!.packingLists.single.entries.single;
    await controller.changeUsedUnits('viaje', entry, 1);
    await controller.changeUsedUnits('viaje', entry, 1);
    expect(controller.remainingUnits('viaje', entry), 1);
    await controller.changeUsedUnits('viaje', entry, 10);
    expect(controller.remainingUnits('viaje', entry), 0);
    await controller.changeUsedUnits('viaje', entry, -1);
    expect(controller.remainingUnits('viaje', entry), 1);
    controller.dispose();

    final reopened = MobileTaskController(
      store: _PairedStore(),
      client: _Client(),
      notifications: _Notifications(),
      wardrobeStore: wardrobe,
    );
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.remainingUnits('viaje', entry), 1);
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

  @override
  Future<LanWardrobeResult> syncWardrobe({
    required LanConnectionConfig config,
    required String token,
    required String revision,
  }) async =>
      LanWardrobeResult(changed: false, endpoint: config.endpoint);
}

class _WardrobeStore extends MobileWardrobeStore {
  _WardrobeStore({this.snapshot});

  final MobileWardrobeSnapshot? snapshot;
  Map<String, Map<String, int>> usage = {};

  @override
  Future<MobileWardrobeSnapshot?> loadSnapshot() async => snapshot;

  @override
  Future<Map<String, Map<String, int>>> loadUsage() async => usage;

  @override
  Future<void> saveUsage(Map<String, Map<String, int>> value) async {
    usage = {
      for (final trip in value.entries) trip.key: {...trip.value},
    };
  }
}

class _PairedStore extends _Store {
  @override
  Future<String?> loadToken() async => null;
}

class _Notifications extends MobileNotificationService {
  @override
  Future<void> initialize() async {}
}
