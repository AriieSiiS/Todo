import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Una compra nueva respeta la agrupación guardada de su tipo', () {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final item = controller.createShoppingItem(
        name: 'Proyector', category: 'Electrónica', subcategory: 'Proyectores');
    final legacy = item.toJson()..remove('grouped');
    expect(ShoppingItem.fromJson(legacy).grouped, isTrue);
    controller.setShoppingGroupGrouped('Electrónica', 'Proyectores', false);
    final next = controller.createShoppingItem(
        name: 'Otra opción',
        category: 'Electrónica',
        subcategory: 'Proyectores');
    expect(next.grouped, isFalse);
    controller.updateShoppingItem(next.id, notes: 'Nota conservada');
    expect(controller.shoppingItemById(next.id)!.grouped, isFalse);
    controller.setShoppingGroupGrouped('Electrónica', 'Proyectores', true);
    expect(controller.shoppingItems.every((entry) => entry.grouped), isTrue);
    expect(controller.shoppingItemById(next.id)!.notes, 'Nota conservada');
  });

  testWidgets('Desagrupar y reagrupar se conserva tras exportar las compras',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    for (var i = 1; i <= 4; i++) {
      controller.createShoppingItem(
          name: 'Proyector $i',
          category: 'Electrónica',
          subcategory: 'Proyectores',
          sourceUrl: 'https://www.amazon.es/dp/B09VMPHY5W',
          referencePrice: 300 + i.toDouble());
    }
    controller.createShoppingItem(
        name: 'Otra compra', category: 'Otros', subcategory: 'Proyectores');
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Future<void> show(TodoWorkspace workspace) async {
      await tester.pumpWidget(MaterialApp(
          theme: buildTodoTheme(),
          home: Scaffold(body: ShoppingPage(controller: workspace))));
      await tester.pumpAndSettle();
    }

    final folder = find.byKey(
        const ValueKey(('shopping-folder', 'Electrónica', 'Proyectores')));
    await show(controller);
    await tester.tap(folder,
        buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Desagrupar'), findsOneWidget);
    await tester.tap(find.text('Desagrupar'));
    await tester.pumpAndSettle();
    expect(folder, findsNothing);
    for (var i = 1; i <= 4; i++) {
      expect(find.text('Proyector $i'), findsOneWidget);
    }
    final snapshot = AppStateSnapshot.fromJson(
        jsonDecode(controller.exportSnapshot().toPrettyJson())
            as Map<String, dynamic>);
    final restored = TodoWorkspace.createForTest(snapshot: snapshot);
    addTearDown(restored.dispose);
    await show(restored);
    expect(folder, findsNothing);
    // Agrupar desde un resultado de búsqueda incluye los demás productos.
    await tester.enterText(find.byType(TextField).first, 'Proyector 1');
    await tester.pumpAndSettle();
    await tester.tap(
        find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == 'Proyector 1'),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agrupar de nuevo'));
    await tester.pumpAndSettle();
    expect(folder, findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    expect(find.text('4 productos'), findsOneWidget);
    expect(find.text('Otra compra'), findsOneWidget);
    final regrouped = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson(
            jsonDecode(restored.exportSnapshot().toPrettyJson())
                as Map<String, dynamic>));
    addTearDown(regrouped.dispose);
    await show(regrouped);
    expect(folder, findsOneWidget);
    expect(regrouped.shoppingItems.length, 5);
    expect(regrouped.shoppingItems.first.referencePrice, 301);
    expect(regrouped.shoppingItems.first.sourceUrl,
        'https://www.amazon.es/dp/B09VMPHY5W');
    // El menú visible de la carpeta ofrece la misma acción que el clic derecho.
    await tester.tap(find.byTooltip('Opciones de carpeta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desagrupar'));
    await tester.pumpAndSettle();
    expect(folder, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compras agrupa proyectores y permite entrar y volver',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    for (var i = 1; i <= 4; i++) {
      controller.createShoppingItem(
          name: 'Proyector $i',
          category: 'Electrónica',
          subcategory: 'Proyectores');
    }
    controller.createShoppingItem(
        name: 'Otra compra', category: 'Gaming', subcategory: 'Ratones');
    // El mismo nombre de subcategoría en otra categoría no mezcla productos.
    controller.createShoppingItem(
        name: 'Otra categoría', category: 'Otros', subcategory: 'Proyectores');
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: ShoppingPage(controller: controller))));
    await tester.pumpAndSettle();
    final folder = find.byKey(
        const ValueKey(('shopping-folder', 'Electrónica', 'Proyectores')));
    expect(folder, findsOneWidget);
    expect(find.text('4 productos'), findsOneWidget);
    expect(find.text('Proyector 1'), findsNothing);
    expect(find.text('Otra compra'), findsOneWidget);
    await tester.tap(folder);
    await tester.pumpAndSettle();
    for (var i = 1; i <= 4; i++) {
      expect(find.text('Proyector $i'), findsOneWidget);
    }
    expect(find.text('Otra categoría'), findsNothing);
    await tester.tap(find.text('Proyector 1'),
        buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('shopping-editor-name')),
        'Proyector editado');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proyector editado'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shopping-detail-name')), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas las compras'));
    await tester.pumpAndSettle();
    expect(find.text('4 productos'), findsOneWidget);
    expect(find.text('Proyector editado'), findsNothing);
    expect(controller.shoppingItems.length, 6);
    // La búsqueda encuentra productos dentro de las carpetas.
    await tester.enterText(find.byType(TextField).first, 'editado');
    await tester.pumpAndSettle();
    expect(folder, findsOneWidget);
    expect(find.text('Otra compra'), findsNothing);
    await tester.tap(folder);
    await tester.pumpAndSettle();
    expect(find.text('Proyector editado'), findsOneWidget);
    expect(find.text('Proyector 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
      'las compras sobreviven a la exportación y no se mezclan con el inventario',
      () {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    controller.createHouseholdItem(name: 'Cafetera propia', category: 'Cocina');
    final item = controller.createShoppingItem(
      name: 'Tableta de prueba',
      category: 'Electrónica',
      subcategory: 'Tablets',
      sourceUrl: 'https://www.amazon.es/dp/PRUEBA',
      referencePrice: 299,
      targetPrice: 249,
      notes: 'Para leer',
      researchNotes: 'Comparar pantallas',
      priority: true,
    );
    controller.updateShoppingItem(item.id, status: ShoppingStatus.comparing);
    final snapshot = AppStateSnapshot.fromJson(
        jsonDecode(controller.exportSnapshot().toPrettyJson())
            as Map<String, dynamic>);
    final restored = TodoWorkspace.createForTest(snapshot: snapshot);
    addTearDown(restored.dispose);
    expect(restored.shoppingItems.single.subcategory, 'Tablets');
    expect(restored.shoppingItems.single.researchNotes, 'Comparar pantallas');
    expect(restored.shoppingItems.single.referencePrice, 299);
    expect(restored.shoppingItems.single.targetPrice, 249);
    expect(restored.shoppingItems.single.status, ShoppingStatus.comparing);
    expect(restored.householdItems.single.name, 'Cafetera propia');
    expect(AppStateSnapshot.fromJson({}).shoppingItems, isEmpty);
    restored.updateShoppingItem(item.id,
        clearTargetPrice: true, status: ShoppingStatus.purchased);
    expect(restored.shoppingItems.single.targetPrice, isNull);
    expect(restored.householdItems.length, 1);
  });

  testWidgets(
      'Compras filtra subcategorías y guarda las modificaciones de la ficha',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final item = controller.createShoppingItem(
        name: 'Tableta de prueba',
        category: 'Electrónica',
        subcategory: 'Tablets',
        referencePrice: 299,
        targetPrice: 249);
    controller.createShoppingItem(
        name: 'Ratón de prueba', category: 'Gaming', subcategory: 'Ratones');
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: HouseholdPage(controller: controller))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();
    expect(find.text('Añadir a compras'), findsOneWidget);
    expect(find.text('Lo que quiero comprar'), findsNothing);
    expect(find.byKey(const ValueKey('shopping-subcategory-Tablets')),
        findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('shopping-category-Electrónica')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('shopping-subcategory-Tablets')));
    await tester.pumpAndSettle();
    expect(find.text('Tableta de prueba'), findsOneWidget);
    expect(find.text('Ratón de prueba'), findsNothing);
    await tester.tap(find.text('Tableta de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('Me gustaría pagar'), findsOneWidget);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('shopping-editor-targetPrice')), '199,99');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(controller.shoppingItemById(item.id)!.targetPrice, 199.99);
    expect(find.text('199,99 €'), findsOneWidget);
    await tester.tap(find.byTooltip('Marcar como comprado'));
    await tester.pumpAndSettle();
    expect(
        controller.shoppingItemById(item.id)!.status, ShoppingStatus.purchased);
    expect(controller.householdItems, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('El clic derecho permite editar y eliminar solo tras confirmar',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final item = controller.createShoppingItem(
        name: 'Proyector de prueba', category: 'Electrónica');
    final other =
        controller.createShoppingItem(name: 'Otra compra', category: 'Gaming');
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: ShoppingPage(controller: controller)),
    ));
    await tester.pumpAndSettle();

    Future<void> openMenu() async {
      await tester.tap(find.text(controller.shoppingItemById(item.id)!.name),
          buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
      expect(find.byKey(const ValueKey('shopping-detail-name')), findsNothing);
    }

    await openMenu();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('shopping-editor-name')),
        'Proyector editado');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(controller.shoppingItemById(item.id)!.name, 'Proyector editado');

    await openMenu();
    await tester.tap(find.text('Marcar como prioritaria'));
    await tester.pumpAndSettle();
    expect(controller.shoppingItemById(item.id)!.priority, isTrue);
    await openMenu();
    expect(find.text('Quitar prioridad'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar compra'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(controller.shoppingItemById(item.id), isNotNull);

    await openMenu();
    await tester.tap(find.text('Marcar como comprado'));
    await tester.pumpAndSettle();
    expect(
        controller.shoppingItemById(item.id)!.status, ShoppingStatus.purchased);
    await tester.tap(find.text('Todos (2)'));
    await tester.pumpAndSettle();
    await openMenu();
    await tester.tap(find.text('Volver a pendientes'));
    await tester.pumpAndSettle();
    expect(controller.shoppingItemById(item.id)!.status, ShoppingStatus.saved);

    await openMenu();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(controller.shoppingItemById(item.id), isNull);
    expect(controller.shoppingItemById(other.id), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compras mantiene las acciones visibles con notas largas',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final item = controller.createShoppingItem(
      name: 'Batería externa de prueba con cable y pantalla',
      category: 'Electrónica',
      subcategory: 'Baterías externas',
      sourceUrl: 'https://www.anker.com/',
      referencePrice: 75,
      targetPrice: 65,
      notes: List.filled(30, 'Notas para comparar este producto.').join('\n'),
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(1100, 760), const Size(420, 760)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: ShoppingPage(controller: controller)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item.name));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('shopping-detail-name')), findsOneWidget);
      expect(find.text('Editar').hitTestable(), findsOneWidget);
      expect(find.text('Abrir enlace de origen').hitTestable(), findsOneWidget);
      await tester.drag(find.byKey(const ValueKey('shopping-detail-content')),
          const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Editar').hitTestable(), findsOneWidget);
      expect(
          find.byTooltip('Marcar como comprado').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
    }
  });
}
