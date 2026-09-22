import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/services/plant_asset_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  PlantCareRoutine wateringRoutine({bool enabled = true}) => PlantCareRoutine(
        id: 'routine-watering-01',
        type: PlantCareType.watering,
        title: 'Comprobar el sustrato y regar Calatea',
        instructions: 'Regar solo cuando se haya secado la capa superior.',
        firstDueDate: DateTime(2026, 4, 30),
        recurrence: const RecurrenceRule(
          type: RecurrenceType.monthly,
          interval: 2,
          activeMonths: <int>[4, 5, 6, 7, 8, 9],
        ),
        enabled: enabled,
      );

  test('el snapshot conserva plantas y admite datos anteriores al esquema 10',
      () {
    final instant = DateTime.utc(2026, 9, 22);
    final snapshot = AppStateSnapshot(
      tasks: const <TaskModel>[],
      categories: const <CategoryModel>[],
      projects: const <ProjectModel>[],
      notes: const <QuickNote>[],
      plants: <Plant>[
        Plant(
          id: 'plant-01',
          name: 'Calatea',
          commonName: 'Calatea orbifolia',
          scientificName: 'Goeppertia orbifolia',
          catSafety: PlantCatSafety.nonToxic,
          sources: const <PlantSource>[
            PlantSource(title: 'ASPCA', url: 'https://example.com/aspca'),
          ],
          routines: <PlantCareRoutine>[wateringRoutine()],
          createdAt: instant,
          updatedAt: instant,
        ),
      ],
      daySettings: const DaySettings(),
      notificationSettings: const DeviceNotificationSettings(),
      calendarSettings: const CalendarIntegrationSettings(),
      section: AppSection.plants,
      todaySort: TodaySort.manual,
      schemaVersion: 10,
    );

    final decoded = AppStateSnapshot.fromEncodedJson(snapshot.toEncodedJson());
    final legacy = AppStateSnapshot.fromJson(<String, dynamic>{
      'schemaVersion': 9,
    });

    expect(decoded.plants.single.scientificName, 'Goeppertia orbifolia');
    expect(decoded.plants.single.catSafety, PlantCatSafety.nonToxic);
    expect(decoded.plants.single.routines.single.recurrence.activeMonths,
        <int>[4, 5, 6, 7, 8, 9]);
    expect(decoded.section, AppSection.plants);
    expect(legacy.plants, isEmpty);
  });

  test(
      'las rutinas actualizan su tarea sin duplicarla y conservan ajustes personales',
      () {
    final controller = TodoWorkspace.createForTest();
    final plant = controller.createPlant(
      name: 'Calatea',
      commonName: 'Calatea orbifolia',
      scientificName: 'Goeppertia orbifolia',
      location: 'Salón',
      catSafety: PlantCatSafety.nonToxic,
      routines: <PlantCareRoutine>[wateringRoutine()],
    );
    final originalTask = controller.tasks.single;
    final completion = DateTime(2026, 4, 30, 19);
    controller.updateTask(originalTask.copyWith(
      scheduledAt: DateTime(2026, 4, 30, 18, 30),
      reminderRules: const <ReminderRule>[
        ReminderRule(minutesBefore: 15),
      ],
      recurrenceCompletions: <String, DateTime>{'2026-04-30': completion},
    ));

    final changedRoutine = wateringRoutine().copyWith(
      instructions: 'Comprueba dos centímetros de sustrato antes de regar.',
      recurrence: const RecurrenceRule(
        type: RecurrenceType.monthly,
        interval: 1,
        activeMonths: <int>[4, 5, 6, 7, 8, 9],
      ),
    );
    controller.updatePlant(plant.copyWith(
      location: 'Dormitorio',
      routines: <PlantCareRoutine>[changedRoutine],
    ));

    final updatedTask = controller.tasks.single;
    expect(controller.categories.where((item) => item.name == 'Plantas'),
        hasLength(1));
    expect(updatedTask.id, originalTask.id);
    expect(updatedTask.scheduledAt, DateTime(2026, 4, 30, 18, 30));
    expect(updatedTask.reminderRules.single.minutesBefore, 15);
    expect(updatedTask.recurrenceCompletions['2026-04-30'], completion);
    expect(updatedTask.description,
        'Comprueba dos centímetros de sustrato antes de regar.');
    expect(updatedTask.sourcePlantId, plant.id);
    expect(updatedTask.sourcePlantCareRoutineId, changedRoutine.id);
    expect(updatedTask.origin, TaskOrigin.plant);

    expect(controller.tasksForDate(DateTime(2026, 5, 30)), hasLength(1));
    expect(controller.tasksForDate(DateTime(2026, 10, 30)), isEmpty);
    expect(controller.tasksForDate(DateTime(2027, 2, 28)), isEmpty);
  });

  test('desactivar, archivar, restaurar y borrar sincroniza las tareas', () {
    final controller = TodoWorkspace.createForTest();
    final plant = controller.createPlant(
      name: 'Pilea',
      commonName: 'Planta del dinero china',
      scientificName: 'Pilea peperomioides',
      routines: <PlantCareRoutine>[wateringRoutine()],
    );

    controller.updatePlant(
      plant.copyWith(routines: <PlantCareRoutine>[
        wateringRoutine(enabled: false),
      ]),
    );
    expect(controller.tasks.single.status, TaskStatus.archived);

    controller.updatePlant(
      plant.copyWith(routines: <PlantCareRoutine>[wateringRoutine()]),
    );
    controller.archivePlant(plant.id);
    expect(controller.tasks.single.status, TaskStatus.archived);
    controller.archivePlant(plant.id, archived: false);
    expect(controller.tasks.single.status, TaskStatus.active);

    controller.deletePlant(plant.id);
    expect(controller.plants, isEmpty);
    expect(controller.tasks, isEmpty);
  });

  test('el servicio guarda imagen y miniatura de una planta', () async {
    final temp = await Directory.systemTemp.createTemp('todo-plants-test-');
    addTearDown(() => temp.delete(recursive: true));
    final picture = img.Image(width: 640, height: 720);
    img.fill(picture, color: img.ColorRgb8(75, 125, 75));
    final service = PlantAssetService(
      rootOverride: Directory('${temp.path}${Platform.pathSeparator}plants'),
    );

    final imported = await service.importImageBytes(
      'plant-01',
      Uint8List.fromList(img.encodePng(picture)),
    );

    expect(File(await service.absolutePath(imported.imagePath)).existsSync(),
        isTrue);
    expect(
        File(await service.absolutePath(imported.thumbnailPath)).existsSync(),
        isTrue);
    expect(imported.sha256, hasLength(64));
  });

  test('la migración retira la muestra sin afectar a plantas reales', () async {
    final temp = await Directory.systemTemp.createTemp('todo-plants-seed-');
    addTearDown(() => temp.delete(recursive: true));
    final instant = DateTime.utc(2026, 9, 22);
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: <TaskModel>[
          TaskModel(
            id: 'task-example',
            title: 'Regar Cinta de ejemplo',
            sourcePlantId: 'plant-example-spider',
          ),
        ],
        categories: const <CategoryModel>[],
        projects: const <ProjectModel>[],
        notes: const <QuickNote>[],
        plants: <Plant>[
          Plant(
            id: 'plant-example-spider',
            name: 'Cinta de ejemplo',
            commonName: 'Cinta',
            scientificName: 'Chlorophytum comosum',
            createdAt: instant,
            updatedAt: instant,
          ),
          Plant(
            id: 'plant-real',
            name: 'Planta real',
            commonName: 'Planta real',
            scientificName: 'Planta realis',
            createdAt: instant,
            updatedAt: instant,
          ),
        ],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.plants,
        todaySort: TodaySort.manual,
        schemaVersion: 10,
      ),
      plantAssets: PlantAssetService(
        rootOverride: Directory('${temp.path}${Platform.pathSeparator}plants'),
      ),
    );

    final firstRun = await controller.prepareEmptyPlantsFeatureForTest();
    final secondRun = await controller.prepareEmptyPlantsFeatureForTest();

    expect(firstRun, isTrue);
    expect(secondRun, isFalse);
    expect(controller.plants, hasLength(1));
    expect(controller.plants.single.id, 'plant-real');
    expect(controller.tasks, isEmpty);
    expect(controller.categories.where((item) => item.name == 'Plantas'),
        hasLength(1));
  });

  testWidgets('Plantas muestra catálogo, filtros y ficha de seguridad felina',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    controller.createPlant(
      name: 'Calatea del salón',
      commonName: 'Calatea orbifolia',
      scientificName: 'Goeppertia orbifolia',
      location: 'Salón',
      catSafety: PlantCatSafety.nonToxic,
      catSafetyNotes: 'No tóxica para gatos según una fuente veterinaria.',
      sources: const <PlantSource>[
        PlantSource(title: 'ASPCA', url: 'https://example.com/aspca'),
      ],
      routines: <PlantCareRoutine>[wateringRoutine()],
    );
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: PlantsPage(controller: controller)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Plantas'), findsOneWidget);
    expect(find.text('Añadir planta'), findsOneWidget);
    expect(find.byKey(const ValueKey('plants-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('plants-filters')), findsOneWidget);
    expect(find.text('Calatea del salón'), findsOneWidget);
    expect(find.text('No tóxica'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('plants-search')), 'orbifolia');
    await tester.pump();
    expect(find.text('Calatea del salón'), findsOneWidget);

    await tester.tap(find.text('Calatea del salón'));
    await tester.pumpAndSettle();
    expect(find.text('Seguridad para gatos'), findsOneWidget);
    expect(find.text('No tóxica para gatos según una fuente veterinaria.'),
        findsOneWidget);
    expect(find.text('ASPCA'), findsOneWidget);
  });
}
