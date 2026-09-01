import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/services/household_asset_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('el snapshot conserva el inventario del hogar y migra datos antiguos',
      () {
    final instant = DateTime.utc(2026, 9, 1);
    final snapshot = AppStateSnapshot(
      tasks: const [],
      categories: const [],
      projects: const [],
      notes: const [],
      householdItems: [
        HouseholdItem(
          id: 'lavadora-1',
          name: 'Lavadora',
          category: 'Electrodomésticos',
          brand: 'Bosch',
          model: 'WGG244Z0ES',
          serialNumber: 'FD-1234',
          manualPath: 'manuals/lavadora.pdf',
          createdAt: instant,
          updatedAt: instant,
        ),
      ],
      daySettings: const DaySettings(),
      notificationSettings: const DeviceNotificationSettings(),
      calendarSettings: const CalendarIntegrationSettings(),
      section: AppSection.household,
      todaySort: TodaySort.manual,
    );

    final decoded = AppStateSnapshot.fromEncodedJson(snapshot.toEncodedJson());
    final legacy = AppStateSnapshot.fromJson(<String, dynamic>{});

    expect(decoded.householdItems.single.model, 'WGG244Z0ES');
    expect(decoded.householdItems.single.hasManual, isTrue);
    expect(decoded.section, AppSection.household);
    expect(legacy.householdItems, isEmpty);
  });

  test('el workspace crea y actualiza fichas completas del hogar', () {
    final controller = TodoWorkspace.createForTest();
    final item = controller.createHouseholdItem(
      name: 'Aspiradora',
      category: 'Limpieza',
      brand: 'Dyson',
      model: 'V15',
      location: 'Armario del pasillo',
      price: 649,
      tags: const ['filtro HEPA'],
    );

    controller.updateHouseholdItem(
      item.id,
      serialNumber: 'SN-0001',
      warrantyUntil: DateTime(2029, 9, 1),
      notes: 'Lavar el filtro una vez al mes.',
    );

    final updated = controller.householdItemById(item.id)!;
    expect(updated.brand, 'Dyson');
    expect(updated.serialNumber, 'SN-0001');
    expect(updated.warrantyUntil, DateTime(2029, 9, 1));
    expect(updated.tags, const ['filtro HEPA']);
  });

  test('el servicio guarda imagen, miniatura y documentos PDF', () async {
    final temp = await Directory.systemTemp.createTemp('todo-household-test-');
    addTearDown(() => temp.delete(recursive: true));
    final sourceImage = File('${temp.path}${Platform.pathSeparator}horno.jpg');
    final picture = img.Image(width: 640, height: 480);
    img.fill(picture, color: img.ColorRgb8(70, 80, 90));
    await sourceImage.writeAsBytes(img.encodeJpg(picture));
    final sourcePdf = File('${temp.path}${Platform.pathSeparator}manual.pdf');
    await sourcePdf.writeAsBytes('%PDF-1.4\nmanual de prueba'.codeUnits);
    final service = HouseholdAssetService(
      rootOverride: Directory('${temp.path}${Platform.pathSeparator}household'),
    );

    final imported = await service.importImage('horno-1', sourceImage.path);
    final manual = await service.importPdf(
      'horno-1',
      sourcePdf.path,
      kind: 'manuals',
    );

    expect(File(await service.absolutePath(imported.imagePath)).existsSync(),
        isTrue);
    expect(
        File(await service.absolutePath(imported.thumbnailPath)).existsSync(),
        isTrue);
    expect(File(await service.absolutePath(manual)).existsSync(), isTrue);
  });

  testWidgets('Hogar muestra el inventario visual y sus documentos',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    controller.createHouseholdItem(
      name: 'Cafetera',
      category: 'Cocina',
      brand: 'DeLonghi',
      model: 'Magnifica S',
      location: 'Cocina',
    );
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: HouseholdPage(controller: controller)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Hogar'), findsOneWidget);
    expect(find.text('Añadir compra'), findsOneWidget);
    expect(find.text('Cafetera'), findsOneWidget);
    expect(find.text('Cocina (1)'), findsOneWidget);
    expect(find.text('Marca y modelo pendientes'), findsNothing);

    await tester.enterText(
        find.byKey(const ValueKey('household-search')), 'DeLonghi');
    await tester.pump();
    expect(find.text('Cafetera'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });
}
