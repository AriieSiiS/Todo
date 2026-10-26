import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/mobile/mobile_shopping.dart';
import 'package:todo/mobile/mobile_shopping_store.dart';
import 'package:todo/mobile/mobile_task_snapshot.dart';

void main() {
  test('las listas de compra se separan de las tareas normales', () {
    final snapshot = MobileTaskSnapshot.fromJson({
      'protocolVersion': 1,
      'serverId': 'pc',
      'revision': 'r1',
      'generatedAt': '2026-10-22T09:00:00Z',
      'daySettings': {'dayEndsAtHour': 5},
      'categories': <Object>[],
      'projects': <Object>[],
      'tasks': [
        _task('lista', origin: 'shoppingList', subtaskIds: ['leche']),
        _task('leche', parentTaskId: 'lista'),
        _task('normal'),
      ],
    });

    expect(snapshot.shoppingLists.map((task) => task.id), ['lista']);
    expect(snapshot.allActiveTasks().map((task) => task.id), ['normal']);
    expect(snapshot.subtasksOf(snapshot.shoppingLists.single).single.title,
        'leche');
  });

  test('las listas antiguas de Recetas también aparecen en Compra', () {
    final legacy = _task('antigua', subtaskIds: ['pan'])
      ..['title'] = 'Comprar ingredientes para tortilla'
      ..['categoryIds'] = ['compras'];
    final snapshot = MobileTaskSnapshot.fromJson({
      'protocolVersion': 1,
      'serverId': 'pc',
      'revision': 'r1',
      'generatedAt': '2026-10-22T09:00:00Z',
      'daySettings': {'dayEndsAtHour': 5},
      'categories': [
        {'id': 'compras', 'name': 'Compras'},
      ],
      'projects': <Object>[],
      'tasks': [legacy, _task('pan', parentTaskId: 'antigua')],
    });
    expect(snapshot.shoppingLists.map((task) => task.id), ['antigua']);
    expect(snapshot.allActiveTasks(), isEmpty);
  });

  test('el progreso conserva precios y marcas al actualizar la lista', () {
    final progress = MobileShoppingProgress.fromJson({
      'lista': {
        'leche': {'bought': true, 'priceCents': 135},
        'pan': {'bought': false, 'priceCents': 90},
      },
    });
    expect(progress.isBought('lista', 'leche'), isTrue);
    expect(progress.priceCents('lista', 'leche'), 135);
    expect(progress.totalCents('lista', ['leche', 'pan']), 225);
    expect(progress.retainItems('lista', ['leche', 'huevos']).toJson(), {
      'lista': {
        'leche': {'bought': true, 'priceCents': 135},
      },
    });
  });

  test('las marcas y precios sobreviven a guardados sucesivos', () async {
    final directory = await Directory.systemTemp.createTemp('todo-compra-');
    try {
      final store = MobileShoppingStore(directory: directory);
      await store
          .save(MobileShoppingProgress().withBought('lista', 'pan', true));
      await store.save((await store.load()).withPrice('lista', 'pan', 120));
      final restored = await store.load();
      expect(restored.isBought('lista', 'pan'), isTrue);
      expect(restored.priceCents('lista', 'pan'), 120);
      final file = File(
        '${directory.path}${Platform.pathSeparator}Todo${Platform.pathSeparator}lan_sync${Platform.pathSeparator}shopping_progress_v1.json',
      );
      await file.rename('${file.path}.bak');
      expect((await store.load()).priceCents('lista', 'pan'), 120);
      await store.save(restored.withReceiptTotal('lista', 130));
      expect((await store.load()).receiptTotalCents('lista'), 130);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

Map<String, dynamic> _task(String id,
        {String origin = 'manual',
        String? parentTaskId,
        List<String> subtaskIds = const []}) =>
    {
      'id': id,
      'title': id,
      'status': 'active',
      'origin': origin,
      'priority': 'medium',
      'parentTaskId': parentTaskId,
      'categoryIds': <String>[],
      'projectIds': <String>[],
      'subtaskIds': subtaskIds,
      'checklist': <String>[],
      'materials': <String>[],
      'reminderRules': <Object>[],
      'recurrence': {'type': 'none', 'interval': 1},
    };
