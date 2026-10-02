import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/mobile/mobile_wardrobe_snapshot.dart';
import 'package:todo/mobile/mobile_wardrobe_store.dart';

void main() {
  test('conserva una maleta desaparecida del PC y sus prendas', () {
    final old = MobileWardrobeSnapshot.fromJson({
      'protocolVersion': 1,
      'wardrobeVersion': 1,
      'serverId': 'pc',
      'revision': 'anterior',
      'items': [
        {'id': 'camisa', 'name': 'Camisa', 'imageAvailable': true}
      ],
      'packingLists': [
        {
          'id': 'viaje',
          'name': 'Viaje',
          'startDate': '2026-10-01',
          'endDate': '2026-10-05',
          'entries': [
            {'itemId': 'camisa', 'quantity': 3, 'packed': false}
          ],
        }
      ],
    });
    final next = MobileWardrobeSnapshot.fromJson({
      'protocolVersion': 1,
      'wardrobeVersion': 1,
      'serverId': 'pc',
      'revision': 'nueva',
      'items': [],
      'packingLists': [],
    }).mergePrevious(old);
    expect(next.packingLists, hasLength(1));
    expect(next.packingLists.single.localOnly, isTrue);
    expect(next.packingLists.single.entries.single.quantity, 3);
    expect(next.itemById('camisa'), isNotNull);
  });

  test('la falta de una foto se registra sin perder la maleta', () {
    final snapshot = MobileWardrobeSnapshot.fromJson({
      'protocolVersion': 1,
      'wardrobeVersion': 1,
      'serverId': 'pc',
      'revision': 'nueva',
      'items': [
        {
          'id': 'camisa',
          'imageAvailable': true,
          'thumbnailSha256': 'huella',
        }
      ],
      'packingLists': [],
    });
    final updated = snapshot.withUnavailableAssets({
      'camisa': {'original', 'thumbnail'}
    });
    expect(updated.itemById('camisa')!.imageAvailable, isFalse);
    expect(updated.itemById('camisa')!.thumbnailSha256, isEmpty);
    expect(updated.revision, 'nueva');
  });

  test('la caché conserva datos y unidades usadas tras un fallo de foto',
      () async {
    final directory = await Directory.systemTemp.createTemp('todo-ropa-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = MobileWardrobeStore(directory: directory);
    final snapshot = MobileWardrobeSnapshot.fromJson({
      'protocolVersion': 1,
      'wardrobeVersion': 1,
      'serverId': 'pc',
      'revision': 'uno',
      'items': [
        {'id': 'camisa', 'name': 'Camisa'}
      ],
      'packingLists': [
        {
          'id': 'viaje',
          'entries': [
            {'itemId': 'camisa', 'quantity': 3}
          ],
        }
      ],
    });
    await store.saveSnapshot(snapshot);
    await store.saveUsage({
      'viaje': {'camisa': 2}
    });
    final digest = sha256.convert([1, 2, 3]).toString();
    await expectLater(
      store.saveImage('camisa', 'original', digest, [9, 9, 9]),
      throwsFormatException,
    );
    expect((await store.loadSnapshot())?.revision, 'uno');
    expect((await store.loadUsage())['viaje']?['camisa'], 2);
    await store.saveImage('camisa', 'original', digest, [1, 2, 3]);
    expect(await store.hasImage('camisa', 'original', digest), isTrue);
    expect(await store.imageFile('../otro', 'original', digest), isNull);
  });
}
