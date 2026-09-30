import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/services/wardrobe_asset_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('el snapshot de Ropa conserva datos y migra snapshots anteriores', () {
    final instant = DateTime.utc(2026, 7, 15);
    final snapshot = AppStateSnapshot(
      tasks: const [],
      categories: const [],
      projects: const [],
      notes: const [],
      wardrobeItems: [
        WardrobeItem(
          id: 'item-1',
          name: 'Cárdigan azul',
          category: 'Cárdigans',
          imagePath: 'items/cardigan.png',
          imageSha256: 'hash',
          createdAt: instant,
          updatedAt: instant,
          colors: const ['azul'],
        ),
      ],
      wardrobeOutfits: [
        WardrobeOutfit(
          id: 'outfit-1',
          name: 'Oficina',
          itemIds: const ['item-1'],
          renderImagePath: 'outfits/oficina.png',
          createdAt: instant,
        ),
      ],
      daySettings: const DaySettings(),
      wardrobeDisplaySettings:
          const WardrobeDisplaySettings(showUsageCount: true),
      notificationSettings: const DeviceNotificationSettings(),
      calendarSettings: const CalendarIntegrationSettings(),
      section: AppSection.wardrobe,
      todaySort: TodaySort.manual,
      schemaVersion: 2,
    );

    final decoded = AppStateSnapshot.fromEncodedJson(snapshot.toEncodedJson());
    final legacy = AppStateSnapshot.fromJson(<String, dynamic>{});

    expect(decoded.wardrobeItems.single.name, 'Cárdigan azul');
    expect(
        decoded.wardrobeOutfits.single.renderImagePath, 'outfits/oficina.png');
    expect(decoded.section, AppSection.wardrobe);
    expect(decoded.wardrobeDisplaySettings.showUsageCount, isTrue);
    expect(legacy.wardrobeItems, isEmpty);
    expect(legacy.wardrobeOutfits, isEmpty);
    expect(legacy.wardrobeDisplaySettings.showUsageCount, isFalse);
  });

  test('el refresco incorpora imágenes sustituidas sin reiniciar la app', () {
    final initial = DateTime.utc(2026, 9, 17, 10);
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        wardrobeItems: [
          WardrobeItem(
            id: 'prenda-actualizada',
            name: 'Camiseta negra',
            category: 'Camisetas',
            imagePath: 'items/imagen-anterior.png',
            thumbnailPath: 'thumbnails/imagen-anterior.png',
            imageSha256: 'hash-anterior',
            createdAt: initial,
            updatedAt: initial,
          ),
        ],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.wardrobe,
        todaySort: TodaySort.manual,
      ),
    );
    final replacement = WardrobeItem(
      id: 'prenda-actualizada',
      name: 'Camiseta negra',
      category: 'Camisetas',
      imagePath: 'items/imagen-nueva.png',
      thumbnailPath: 'thumbnails/imagen-nueva.png',
      imageSha256: 'hash-nuevo',
      createdAt: initial,
      updatedAt: initial.add(const Duration(minutes: 1)),
    );

    expect(
      controller.mergeExternalWardrobeItemsForTest([replacement]),
      isTrue,
    );
    expect(
      controller.wardrobeItemById('prenda-actualizada')?.imagePath,
      'items/imagen-nueva.png',
    );
    expect(
      controller.wardrobeItemById('prenda-actualizada')?.imageSha256,
      'hash-nuevo',
    );

    final stale = replacement.copyWith(
      imagePath: 'items/imagen-obsoleta.png',
      updatedAt: initial.subtract(const Duration(minutes: 1)),
    );
    expect(controller.mergeExternalWardrobeItemsForTest([stale]), isFalse);
    expect(
      controller.wardrobeItemById('prenda-actualizada')?.imagePath,
      'items/imagen-nueva.png',
    );
  });

  test('el workspace gestiona conjuntos, usos, lavado, planes y maletas', () {
    final controller = TodoWorkspace.createForTest();
    final shirt = controller.createWardrobeItem(
      name: 'Camisa blanca',
      category: 'Camisas',
      occasions: const ['trabajo'],
      tags: const ['templado'],
      price: 40,
    );
    final trousers = controller.createWardrobeItem(
      name: 'Pantalón azul',
      category: 'Pantalones',
    );
    final outfit = controller.createWardrobeOutfit(
      name: 'Oficina',
      itemIds: [shirt.id, trousers.id],
      occasion: 'trabajo',
    );
    final editedOutfit = controller.updateWardrobeOutfit(
      id: outfit.id,
      name: 'Oficina informal',
      itemIds: outfit.itemIds,
      occasion: 'oficina',
      tags: const ['cómodo'],
    );

    controller.recordWardrobeWear(
      date: DateTime(2026, 7, 15),
      itemIds: editedOutfit.itemIds,
      outfitId: editedOutfit.id,
    );
    controller.setWardrobeLaundryStatus(
      [shirt.id],
      WardrobeLaundryStatus.toWash,
    );
    controller.setWardrobePlan(
      date: DateTime(2026, 7, 16),
      itemIds: outfit.itemIds,
      outfitId: outfit.id,
      weather: WardrobeWeather.mild,
    );
    final packing = controller.createWardrobePackingList(
      name: 'Fin de semana',
      startDate: DateTime(2026, 7, 18),
      endDate: DateTime(2026, 7, 20),
    );
    controller.addWardrobePackingItem(packing.id, trousers.id);

    expect(controller.wardrobeItemById(shirt.id)?.useCount, 1);
    expect(
      controller.wardrobeItemById(shirt.id)?.laundryStatus,
      WardrobeLaundryStatus.toWash,
    );
    expect(controller.wardrobePlanEntries, hasLength(1));
    expect(controller.wardrobePackingLists.single.entries, hasLength(1));
    expect(controller.wardrobeOutfits.single.name, 'Oficina informal');
    expect(controller.wardrobeOutfits.single.tags, const ['cómodo']);
    expect(
      controller.wardrobeSuggestions(occasion: 'trabajo'),
      isNot(contains(shirt)),
    );
  });

  test('cada maleta separa prendas disponibles, incluidas y descartadas', () {
    final controller = TodoWorkspace.createForTest();
    final shirt = controller.createWardrobeItem(
      name: 'Camisa blanca',
      category: 'Camisas',
    );
    final trousers = controller.createWardrobeItem(
      name: 'Pantalón azul',
      category: 'Pantalones',
    );
    final first = controller.createWardrobePackingList(
      name: 'Viaje corto',
      startDate: DateTime(2026, 9, 29),
      endDate: DateTime(2026, 10, 1),
    );
    final second = controller.createWardrobePackingList(
      name: 'Otro viaje',
      startDate: DateTime(2026, 10, 2),
      endDate: DateTime(2026, 10, 5),
    );

    controller.addWardrobePackingItem(first.id, shirt.id);
    controller.addWardrobePackingItem(first.id, shirt.id);
    controller.discardWardrobePackingItem(first.id, trousers.id);
    var current = controller.wardrobePackingLists.first;
    expect(current.entries.map((entry) => entry.itemId), [shirt.id]);
    expect(current.discardedItemIds, [trousers.id]);
    expect(controller.wardrobePackingLists.last.entries, isEmpty);
    expect(controller.wardrobePackingLists.last.discardedItemIds, isEmpty);
    expect(controller.wardrobeItems, hasLength(2));

    final decoded = WardrobePackingList.fromJson(current.toJson());
    expect(decoded.discardedItemIds, [trousers.id]);
    expect(
        WardrobePackingList.fromJson({
          'id': second.id,
          'name': second.name,
        }).discardedItemIds,
        isEmpty);

    controller.restoreWardrobePackingItem(first.id, trousers.id);
    controller.removeWardrobePackingItem(first.id, shirt.id);
    current = controller.wardrobePackingLists.first;
    expect(current.entries, isEmpty);
    expect(current.discardedItemIds, isEmpty);
    controller.discardWardrobePackingItem(first.id, shirt.id);
    controller.addWardrobePackingItem(first.id, shirt.id);
    expect(controller.wardrobePackingLists.first.discardedItemIds, isEmpty);
    controller.discardWardrobePackingItem(first.id, trousers.id);
    controller.deleteWardrobeItem(trousers.id);
    expect(controller.wardrobeItems, hasLength(1));
    expect(controller.wardrobePackingLists.first.discardedItemIds, isEmpty);
  });

  test('el servicio prepara y aprueba un lote PNG transparente', () async {
    final temp = await Directory.systemTemp.createTemp('todo-wardrobe-test-');
    addTearDown(() => temp.delete(recursive: true));
    final source = Directory('${temp.path}${Platform.pathSeparator}source')
      ..createSync();
    final picture = img.Image(width: 12, height: 12, numChannels: 4);
    img.fill(picture, color: img.ColorRgba8(0, 0, 0, 0));
    picture.setPixelRgba(6, 6, 20, 40, 200, 255);
    File('${source.path}${Platform.pathSeparator}camisa.png')
        .writeAsBytesSync(img.encodePng(picture));
    File('${source.path}${Platform.pathSeparator}manifest.json')
        .writeAsStringSync(jsonEncode(<String, dynamic>{
      'version': 1,
      'batchId': 'lote-prueba',
      'name': 'Lote de prueba',
      'items': [
        {
          'id': 'camisa',
          'file': 'camisa.png',
          'name': 'Camisa azul',
          'category': 'Camisas',
        },
      ],
    }));
    final service = WardrobeAssetService(
      rootOverride: Directory('${temp.path}${Platform.pathSeparator}wardrobe'),
    );

    final batch = await service.stageManifestDirectory(source.path, const []);
    final approved = await service.approveBatch(batch);

    expect(batch.items.single.errors, isEmpty);
    expect(approved, hasLength(1));
    expect(
      File(await service.absolutePath(approved.single.imagePath)).existsSync(),
      isTrue,
    );
    expect(
      File(await service.absolutePath(approved.single.thumbnailPath))
          .existsSync(),
      isTrue,
    );
  });

  test('la normalización iguala la escala visual de una misma categoría', () {
    img.Image source(int size, int left, int top, int width, int height) {
      final image = img.Image(width: size, height: size, numChannels: 4);
      for (var y = top; y < top + height; y++) {
        for (var x = left; x < left + width; x++) {
          image.setPixelRgba(x, y, 80, 70, 160, 255);
        }
      }
      return image;
    }

    (int, int) visibleSize(img.Image image) {
      var left = image.width;
      var top = image.height;
      var right = -1;
      var bottom = -1;
      for (final pixel in image) {
        if (pixel.a <= 8) continue;
        left = min(left, pixel.x);
        top = min(top, pixel.y);
        right = max(right, pixel.x);
        bottom = max(bottom, pixel.y);
      }
      return (right - left + 1, bottom - top + 1);
    }

    final service = WardrobeAssetService();
    final compact = img.decodePng(service.normalizeCatalogPng(
      Uint8List.fromList(img.encodePng(source(600, 80, 100, 440, 360))),
      'Pantalones cortos',
    ))!;
    final generous = img.decodePng(service.normalizeCatalogPng(
      Uint8List.fromList(img.encodePng(source(1000, 250, 270, 500, 410))),
      'Pantalones cortos',
    ))!;
    final compactVisible = visibleSize(compact);
    final generousVisible = visibleSize(generous);

    expect((compact.width, compact.height),
        equals((generous.width, generous.height)));
    expect(
        (compactVisible.$2 - generousVisible.$2).abs(), lessThanOrEqualTo(2));
    expect(compactVisible.$2, closeTo(864, 2));
  });

  test('la taxonomía normaliza alias y mantiene el orden canónico', () {
    expect(WardrobeTaxonomy.normalizeCategory('t-shirt'), 'Camisetas');
    expect(WardrobeTaxonomy.normalizeCategory('jackets'), 'Chaquetas');
    expect(WardrobeTaxonomy.normalizeCategory('bermudas'), 'Pantalones cortos');
    expect(WardrobeTaxonomy.normalizeColors(const ['burdeos', 'lavanda']),
        const ['granate', 'lila']);
    expect(WardrobeTaxonomy.compareCategories('Camisetas', 'Calzado'),
        lessThan(0));
  });

  test('el servicio admite una foto opaca y genera su miniatura', () async {
    final temp = await Directory.systemTemp.createTemp('todo-wardrobe-photo-');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}${Platform.pathSeparator}foto.jpg');
    final picture = img.Image(width: 640, height: 480);
    img.fill(picture, color: img.ColorRgb8(120, 80, 40));
    source.writeAsBytesSync(img.encodeJpg(picture));
    final service = WardrobeAssetService(
      rootOverride: Directory('${temp.path}${Platform.pathSeparator}wardrobe'),
    );

    final imported = await service.importItemImage(
      itemId: 'prenda-foto',
      sourcePath: source.path,
      category: 'Camisas',
    );

    final stored = img.decodePng(
      File(await service.absolutePath(imported.imagePath)).readAsBytesSync(),
    );
    expect(stored, isNotNull);
    expect(stored!.width, 640);
    expect(stored.height, 480);
    expect(
      File(await service.absolutePath(imported.thumbnailPath)).existsSync(),
      isTrue,
    );
  });

  test('el servicio guarda directamente una imagen pegada', () async {
    final temp = await Directory.systemTemp.createTemp('todo-wardrobe-paste-');
    addTearDown(() => temp.delete(recursive: true));
    final picture = img.Image(width: 40, height: 30, numChannels: 4);
    img.fill(picture, color: img.ColorRgba8(30, 80, 150, 255));
    final service = WardrobeAssetService(
      rootOverride: Directory('${temp.path}${Platform.pathSeparator}wardrobe'),
    );

    final imported = await service.importItemImageBytes(
      itemId: 'prenda-pegada',
      bytes: Uint8List.fromList(img.encodePng(picture)),
      category: 'Camisas',
    );

    expect(
      File(await service.absolutePath(imported.imagePath)).existsSync(),
      isTrue,
    );
    expect(
      File(await service.absolutePath(imported.thumbnailPath)).existsSync(),
      isTrue,
    );
  });

  test('el servicio importa renders de conjuntos como PNG', () async {
    final temp = await Directory.systemTemp.createTemp('todo-outfit-test-');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}${Platform.pathSeparator}render.jpg');
    final picture = img.Image(width: 700, height: 900);
    img.fill(picture, color: img.ColorRgb8(30, 40, 50));
    source.writeAsBytesSync(img.encodeJpg(picture));
    final service = WardrobeAssetService(
      rootOverride: Directory('${temp.path}${Platform.pathSeparator}wardrobe'),
    );

    final relative = await service.importOutfitRender('outfit-1', source.path);
    final destination = File(await service.absolutePath(relative));

    expect(relative, startsWith('outfits/outfit-1-'));
    expect(destination.existsSync(), isTrue);
    expect(img.decodePng(destination.readAsBytesSync()), isNotNull);
  });

  testWidgets('Ropa muestra seis áreas y abre importaciones desde la cabecera',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: WardrobePage(controller: controller)),
    ));

    expect(find.text('Armario'), findsOneWidget);
    expect(find.text('Conjuntos'), findsOneWidget);
    expect(find.text('Planificador'), findsOneWidget);
    expect(find.text('Lavandería'), findsOneWidget);
    expect(find.text('Maletas'), findsOneWidget);
    expect(find.text('Estadísticas'), findsOneWidget);
    expect(find.text('Importaciones'), findsNothing);
    expect(find.text('Importar'), findsOneWidget);

    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(find.text('Importar ropa'), findsOneWidget);
    expect(find.text('Importar lote desde carpeta'), findsOneWidget);
  });

  testWidgets(
      'Maletas permite añadir, quitar, descartar y recuperar desde tarjetas',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    controller.createWardrobeItem(name: 'Camisa blanca', category: 'Camisas');
    controller.createWardrobeItem(
        name: 'Pantalón azul', category: 'Pantalones');
    controller.createWardrobePackingList(
      name: 'Viaje corto',
      startDate: DateTime(2026, 9, 29),
      endDate: DateTime(2026, 10, 1),
    );
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(
          body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => WardrobePage(controller: controller),
      )),
    ));
    await tester.tap(find.text('Maletas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viaje corto'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Añadir a la maleta'), findsNWidgets(2));
    expect(find.byTooltip('Descartar para este viaje'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Añadir a la maleta').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Añadir a la maleta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('packing-view-included')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Quitar de la maleta'), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar de la maleta'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('packing-view-available')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Añadir a la maleta'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Descartar para este viaje').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Descartar para este viaje'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('packing-view-discarded')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Volver a disponibles'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver a disponibles'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('packing-view-available')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Añadir a la maleta'), findsNWidgets(2));
  });

  testWidgets('editar conjunto mantiene selección y ofrece búsqueda y filtros',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final shirt = controller.createWardrobeItem(
      name: 'Camisa azul',
      category: 'Camisas',
      colors: const ['azul'],
    );
    final trousers = controller.createWardrobeItem(
      name: 'Pantalón beige',
      category: 'Pantalones',
      colors: const ['beige'],
    );
    controller.createWardrobeItem(
      name: 'Zapatillas blancas',
      category: 'Calzado',
    );
    controller.createWardrobeOutfit(
      name: 'Trabajo',
      itemIds: [shirt.id, trousers.id],
    );
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: WardrobePage(controller: controller)),
    ));
    await tester.tap(find.text('Conjuntos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trabajo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar conjunto'));
    await tester.pumpAndSettle();

    expect(find.text('En el conjunto'), findsOneWidget);
    expect(find.text('Camisa azul'), findsOneWidget);
    expect(find.text('Pantalón beige'), findsOneWidget);
    expect(find.text('Buscar prendas para añadir'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Camisas'), findsWidgets);
    expect(find.text('Pantalones'), findsWidgets);
    expect(find.text('Calzado'), findsWidgets);
    expect(find.text('Zapatillas blancas'), findsOneWidget);
  });

  testWidgets('el armario filtra por categorías visibles y búsqueda completa',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    controller.createWardrobeItem(
      name: 'Pantalón beige',
      category: 'Pantalones',
      colors: const ['beige'],
    );
    controller.createWardrobeItem(
      name: 'Puma Palermo',
      category: 'Calzado',
      material: 'cuero',
      colors: const ['crema', 'burdeos'],
    );
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: WardrobePage(controller: controller)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Todo (2)'), findsOneWidget);
    expect(find.text('Favoritos (0)'), findsOneWidget);
    expect(find.text('Calzado (1)'), findsOneWidget);
    expect(find.text('Pantalones (1)'), findsOneWidget);

    await tester.tap(find.text('Todo (2)'));
    await tester.pump();
    expect(find.text('Puma Palermo'), findsNothing);
    expect(find.text('Pantalón beige'), findsNothing);

    await tester.tap(find.text('Pantalones (1)'));
    await tester.pump();
    expect(find.text('Puma Palermo'), findsNothing);
    expect(find.text('Pantalón beige'), findsOneWidget);

    await tester.tap(find.text('Todo (2)'));
    await tester.pump();
    expect(find.text('Puma Palermo'), findsOneWidget);
    expect(find.text('Pantalón beige'), findsOneWidget);

    await tester.tap(find.text('Calzado (1)'));
    await tester.pump();
    expect(find.text('Puma Palermo'), findsNothing);
    expect(find.text('Pantalón beige'), findsOneWidget);

    await tester.tap(find.text('Calzado (1)'));
    await tester.pump();
    expect(find.text('Puma Palermo'), findsOneWidget);
    expect(find.text('Pantalón beige'), findsOneWidget);

    await tester.tap(find.text('Pantalones (1)'));
    await tester.pump();
    expect(find.text('Puma Palermo'), findsOneWidget);
    expect(find.text('Pantalón beige'), findsNothing);

    await tester.tap(find.text('Todo (2)'));
    await tester.enterText(
        find.byKey(const ValueKey('wardrobe-search')), 'granate');
    await tester.pump();
    expect(find.text('Puma Palermo'), findsOneWidget);
    expect(find.text('Pantalón beige'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('al pulsar una prenda abre su detalle visual antes de editar',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    controller.createWardrobeItem(
      name: 'Camisa granate',
      category: 'Camisetas',
      material: 'algodón',
      colors: const ['granate'],
      tags: const ['casual'],
    );
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: WardrobePage(controller: controller)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Camisa granate').last);
    await tester.pumpAndSettle();

    expect(find.text('Detalle de prenda'), findsOneWidget);
    expect(find.text('algodón'), findsOneWidget);
    expect(find.text('granate'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar prenda'), findsOneWidget);
    expect(find.text('Información básica'), findsOneWidget);
    expect(find.text('Clasificación'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(find.text('Camisetas'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('wardrobe-editor-category')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('wardrobe-editor-form')),
      const Offset(0, -1100),
    );
    await tester.pumpAndSettle();
    expect(find.text('Estado y valor'), findsOneWidget);
    expect(find.text('Prenda favorita'), findsOneWidget);
  });

  testWidgets('añadir prenda usa la ficha completa sin separar por comas',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: WardrobePage(controller: controller)),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir prenda'));
    await tester.pumpAndSettle();

    expect(find.text('Información básica'), findsOneWidget);
    expect(find.text('Añadir imagen'), findsOneWidget);
    expect(find.text('Pegar imagen'), findsOneWidget);
    expect(find.textContaining('Ctrl+V'), findsOneWidget);
    expect(find.text('Separa varios valores con comas'), findsNothing);
    final categoryButton = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const ValueKey('wardrobe-editor-category')),
        matching: find.byWidgetPredicate(
          (widget) => widget is DropdownButton<String>,
        ),
      ),
    );
    expect(categoryButton.style?.fontWeight, FontWeight.w400);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Camiseta nueva',
    );
    await tester.tap(find.text('Elegir colores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('granate'));
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Elegir temporadas'));
    await tester.tap(find.text('Elegir temporadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('verano'));
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Elegir ocasiones'));
    await tester.tap(find.text('Elegir ocasiones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('diario'));
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.widgetWithText(TextField, 'Añadir etiqueta'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Añadir etiqueta'), 'favorita');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.drag(
      find.byKey(const ValueKey('wardrobe-editor-form')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir prenda').last);
    await tester.pumpAndSettle();

    final saved = controller.wardrobeItems.single;
    expect(saved.name, 'Camiseta nueva');
    expect(saved.category, 'Camisetas');
    expect(saved.colors, contains('granate'));
    expect(saved.seasons, contains('verano'));
    expect(saved.occasions, contains('diario'));
    expect(saved.tags, contains('favorita'));
  });

  testWidgets('las prendas favoritas se pueden mostrar por separado',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final favorite = controller.createWardrobeItem(
      name: 'Chaqueta favorita',
      category: 'Chaquetas',
    );
    controller.createWardrobeItem(
      name: 'Camiseta normal',
      category: 'Camisetas',
    );
    controller.toggleWardrobeFavorite(favorite.id);
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: WardrobePage(controller: controller)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Favoritos (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wardrobe-favorites-filter')));
    await tester.pump();

    expect(find.text('Chaqueta favorita'), findsOneWidget);
    expect(find.text('Camiseta normal'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('los usos están ocultos y pueden activarse desde Ajustes',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final item = controller.createWardrobeItem(
      name: 'Camisa de prueba',
      category: 'Camisas',
    );
    controller.recordWardrobeWear(
      date: DateTime(2026, 9, 2),
      itemIds: [item.id],
    );
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: WardrobePage(controller: controller)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1 usos'), findsNothing);

    controller.updateWardrobeDisplaySettings(
      const WardrobeDisplaySettings(showUsageCount: true),
    );
    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: WardrobePage(controller: controller)),
    ));
    await tester.pump();
    expect(find.text('1 usos'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('el armario agrupa las prendas por categoría y nombre',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    controller.createWardrobeItem(
      name: 'Pantalón negro',
      category: 'Pantalones',
    );
    controller.createWardrobeItem(
      name: 'Camiseta blanca',
      category: 'Camisetas',
    );
    controller.createWardrobeItem(
      name: 'Pantalón beige',
      category: 'Pantalones',
    );
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: WardrobePage(controller: controller)),
    ));
    await tester.pumpAndSettle();

    double visualOrder(String label) {
      final position = tester.getCenter(find.text(label).last);
      return position.dy * 10000 + position.dx;
    }

    expect(visualOrder('Camiseta blanca'),
        lessThan(visualOrder('Pantalón beige')));
    expect(
        visualOrder('Pantalón beige'), lessThan(visualOrder('Pantalón negro')));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
