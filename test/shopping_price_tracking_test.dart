import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/services/shopping_price_service.dart';
import 'package:todo/domain/models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Una ficha muestra y conserva las opciones al editarla',
      (tester) async {
    Map<String, dynamic>? sent;
    var tracking = false;
    late String bundleId;
    final service = ShoppingPriceService(apiCall: (method, path, body) async {
      if (method == 'PUT') {
        sent = body;
        tracking = body!['enabled'] as bool;
      }
      return {
        'engineAvailable': true,
        'watches': {
          if (tracking)
            bundleId: {
              'enabled': true,
              'offers': [
                {
                  'name': 'Black · 6 unidades',
                  'url': 'https://www.amazon.es/dp/B08R9R41SH',
                  'enabled': true,
                  'currentPrice': 17.45
                },
                {
                  'name': 'Apollo · 6 unidades',
                  'url': 'https://www.amazon.es/dp/B094D3XL55',
                  'enabled': true,
                  'currentPrice': 17.49
                },
              ]
            },
        },
        'alerts': []
      };
    });
    final workspace = TodoWorkspace.createForTest(priceService: service);
    addTearDown(workspace.dispose);
    final item = workspace.createShoppingItem(
        name: 'Desodorante AXE',
        category: 'Cuidado personal',
        offers: const [
          ShoppingOffer(
              name: 'Black · 6 unidades',
              sourceUrl: 'https://www.amazon.es/dp/B08R9R41SH'),
          ShoppingOffer(
              name: 'Apollo · 6 unidades',
              sourceUrl: 'https://www.amazon.es/dp/B094D3XL55'),
        ]);
    bundleId = item.id;
    await service.refresh();
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: ShoppingPage(controller: workspace))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desodorante AXE'));
    await tester.pumpAndSettle();
    expect(find.text('Black · 6 unidades'), findsOneWidget);
    expect(find.text('Apollo · 6 unidades'), findsOneWidget);
    await tester.ensureVisible(find.text('Seguir precio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seguir precio'));
    await tester.pumpAndSettle();
    expect((sent!['offers'] as List).length, 2);
    expect(find.text('Esperando una lectura válida.'), findsNothing);
    expect(find.text('17,45 €'), findsOneWidget);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Opciones de compra'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('shopping-editor-name')), 'AXE para comprar');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(workspace.shoppingItemById(item.id)!.offers.length, 2);
    final restored = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson(
            jsonDecode(workspace.exportSnapshot().toPrettyJson())
                as Map<String, dynamic>));
    addTearDown(restored.dispose);
    expect(restored.shoppingItems.single.offers[1].sourceUrl,
        'https://www.amazon.es/dp/B094D3XL55');
    expect(tester.takeException(), isNull);
  });

  test('un fallo de conexión conserva el precio y no modifica la referencia',
      () async {
    var fail = false;
    final service = ShoppingPriceService(apiCall: (method, path, body) async {
      if (fail) throw StateError('Sin conexión');
      return {
        'engineAvailable': true,
        'watches': {
          'prueba': {
            'enabled': true,
            'url': 'https://www.amazon.es/dp/B09VMPHY5W',
            'currentPrice': 249.99,
            'history': [
              {'price': 249.99, 'checkedAt': '2026-10-09T20:00:00Z'}
            ],
            'error': '',
          }
        },
        'alerts': [],
      };
    });
    addTearDown(service.dispose);
    await service.refresh();
    expect(service.available, isTrue);
    expect(service.watch('prueba')!.currentPrice, 249.99);
    fail = true;
    await service.refresh();
    expect(service.available, isFalse);
    expect(service.watch('prueba')!.currentPrice, 249.99);
  });

  testWidgets(
      'la ficha activa, revisa y pausa el seguimiento sin cambiar precios manuales',
      (tester) async {
    var enabled = false;
    final calls = <String>[];
    late String itemId;
    final service = ShoppingPriceService(apiCall: (method, path, body) async {
      calls.add('$method $path');
      if (method == 'PUT') enabled = body!['enabled'] as bool;
      return {
        'engineAvailable': true,
        'watches': {
          if (enabled || calls.any((call) => call.startsWith('PUT')))
            itemId: {
              'enabled': enabled,
              'url': 'https://www.amazon.es/dp/B09VMPHY5W',
              'currentPrice': 249.99,
              'checkedAt': '2026-10-09T20:00:00Z',
              'error': '',
              'history': [
                {'price': 249.99, 'checkedAt': '2026-10-09T20:00:00Z'}
              ],
            },
        },
        'alerts': [],
      };
    });
    final workspace = TodoWorkspace.createForTest(priceService: service);
    addTearDown(workspace.dispose);
    final item = workspace.createShoppingItem(
        name: 'Proyector de prueba',
        category: 'Electrónica',
        referencePrice: 299,
        sourceUrl: 'https://www.amazon.es/dp/B09VMPHY5W');
    itemId = item.id;
    await service.refresh();
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: HouseholdPage(controller: workspace))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proyector de prueba'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Seguir precio'));
    await tester.tap(find.text('Seguir precio'));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
    expect(find.textContaining('Cada 24 horas'), findsOneWidget);
    await tester.ensureVisible(find.text('Revisar ahora'));
    await tester.tap(find.text('Revisar ahora'));
    await tester.pumpAndSettle();
    expect(calls, contains('POST /watches/$itemId/check'));
    await tester.tap(find.text('Pausar'));
    await tester.pumpAndSettle();
    expect(enabled, isFalse);
    expect(workspace.shoppingItemById(itemId)!.referencePrice, 299);
    expect(workspace.shoppingItemById(itemId)!.targetPrice, isNull);
    expect(tester.takeException(), isNull);
  });
}
