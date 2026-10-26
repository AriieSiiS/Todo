import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/mobile/mobile_lan_client.dart';
import 'package:todo/mobile/mobile_lan_store.dart';
import 'package:todo/mobile/mobile_notification_service.dart';
import 'package:todo/mobile/mobile_shopping.dart';
import 'package:todo/mobile/mobile_shopping_store.dart';
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
        wardrobeStore: _WardrobeStore(),
        shoppingStore: _ShoppingStore());
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

  test('una respuesta que llega tras cerrar no guarda configuración', () async {
    final store = _Store();
    final client = _SlowClient();
    final controller = MobileTaskController(
        store: store,
        client: client,
        notifications: _Notifications(),
        wardrobeStore: _WardrobeStore(),
        shoppingStore: _ShoppingStore());
    await controller.initialize();
    store.token.complete('credencial-de-prueba');
    await client.started.future;
    controller.dispose();
    client.response.complete(
        const LanSyncResult(changed: false, endpoint: 'https://127.0.0.1'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(store.saved.isCompleted, isFalse);
  });

  test('un fallo al leer la credencial libera el estado de sincronización',
      () async {
    final store = _Store();
    final controller = MobileTaskController(
        store: store,
        client: _Client(),
        notifications: _Notifications(),
        wardrobeStore: _WardrobeStore(),
        shoppingStore: _ShoppingStore());
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
      shoppingStore: _ShoppingStore(),
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
      shoppingStore: _ShoppingStore(),
    );
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.remainingUnits('viaje', entry), 1);
  });

  test('la compra conserva marcas y precios sin conexión', () async {
    final shopping = _ShoppingStore();
    final controller = MobileTaskController(
      store: _PairedStore(),
      client: _Client(),
      notifications: _Notifications(),
      wardrobeStore: _WardrobeStore(),
      shoppingStore: shopping,
    );
    await controller.initialize();
    await controller.setShoppingBought('lista', 'pan', true);
    await controller.setShoppingPrice('lista', 'pan', 125);
    await controller.setShoppingReceiptTotal('lista', 140);
    controller.dispose();

    final reopened = MobileTaskController(
      store: _PairedStore(),
      client: _Client(),
      notifications: _Notifications(),
      wardrobeStore: _WardrobeStore(),
      shoppingStore: shopping,
    );
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.shoppingProgress.isBought('lista', 'pan'), isTrue);
    expect(reopened.shoppingProgress.priceCents('lista', 'pan'), 125);
    expect(reopened.shoppingProgress.receiptTotalCents('lista'), 140);
  });
}

class _ShoppingStore extends MobileShoppingStore {
  MobileShoppingProgress progress = MobileShoppingProgress();

  @override
  Future<MobileShoppingProgress> load() async => progress;

  @override
  Future<void> save(MobileShoppingProgress value) async {
    progress = value;
  }

  @override
  Future<void> clear() async {
    progress = MobileShoppingProgress();
  }
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

class _SlowClient extends _Client {
  final started = Completer<void>();
  final response = Completer<LanSyncResult>();
  @override
  Future<LanSyncResult> sync(
      {required LanConnectionConfig config, required String token}) {
    started.complete();
    return response.future;
  }
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
