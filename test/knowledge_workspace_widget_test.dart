import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:todo/application/providers/todo_providers.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/app/app_launch_intent.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/knowledge/knowledge_workspace_page.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  testWidgets('el espacio documental crea subpáginas y muestra sus paneles',
      (tester) async {
    final now = DateTime(2026, 7, 22);
    final item = LibraryItem(
      id: 'knowledge-film',
      type: LibraryItemType.movieSeries,
      title: 'Película de prueba',
      status: LibraryItemStatus.completed,
      completedDate: now,
      createdAt: now,
      updatedAt: now,
    );
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryItems: <LibraryItem>[item],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
        schemaVersion: 3,
      ),
    );
    await controller.knowledge.ensureLibraryRoots(<LibraryItem>[item]);
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTodoTheme(),
        locale: const Locale('es'),
        supportedLocales: const <Locale>[Locale('es')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppFlowyEditorLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: KnowledgeWorkspacePage(
          controller: controller,
          libraryItem: item,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Páginas'), findsOneWidget);
    expect(find.text('Esquema'), findsOneWidget);
    expect(find.text('Enlaces entrantes'), findsOneWidget);
    expect(find.text('Propiedades'), findsOneWidget);

    await tester.tap(find.byTooltip('Nueva subpágina'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Actores');
    await tester.tap(find.text('Guardar'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final root = controller.knowledge.rootForOwner('libraryItem', item.id)!;
    expect(controller.knowledge.childrenOf(root.id).single.title, 'Actores');
    expect(find.text('Actores'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('el espacio documental conserva la navegación principal visible',
      (tester) async {
    final now = DateTime(2026, 7, 22);
    final item = LibraryItem(
      id: 'knowledge-navigation-game',
      type: LibraryItemType.game,
      title: 'Juego con páginas',
      status: LibraryItemStatus.inProgress,
      createdAt: now,
      updatedAt: now,
    );
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryItems: <LibraryItem>[item],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
        schemaVersion: 3,
      ),
    );
    await controller.knowledge.ensureLibraryRoots(<LibraryItem>[item]);
    tester.view.physicalSize = const Size(2400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todoWorkspaceProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: buildTodoTheme(),
          locale: const Locale('es'),
          supportedLocales: const <Locale>[Locale('es')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            AppFlowyEditorLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppShell(launchIntent: AppLaunchIntent()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.openKnowledgeWorkspace(item);
    await tester.pumpAndSettle();

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Páginas'), findsOneWidget);
    expect(find.text('Juego con páginas'), findsWidgets);

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();

    expect(controller.section, AppSection.library);
    expect(controller.openKnowledgeLibraryItem, isNull);
    expect(find.text('Páginas'), findsNothing);
  });

  testWidgets('las imágenes se redimensionan y recortan sin perder el original',
      (tester) async {
    final now = DateTime(2026, 7, 22);
    final item = LibraryItem(
      id: 'knowledge-image-game',
      type: LibraryItemType.game,
      title: 'Juego con imagen',
      status: LibraryItemStatus.inProgress,
      createdAt: now,
      updatedAt: now,
    );
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryItems: <LibraryItem>[item],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
        schemaVersion: 3,
      ),
    );
    late Directory temporary;
    late KnowledgeAsset asset;
    await tester.runAsync(() async {
      temporary = await Directory.systemTemp.createTemp('todo-image-test-');
      final source =
          File('${temporary.path}${Platform.pathSeparator}sample.png');
      final bitmap = image_lib.Image(width: 640, height: 360);
      image_lib.fill(bitmap, color: image_lib.ColorRgb8(104, 132, 82));
      await source.writeAsBytes(image_lib.encodePng(bitmap));
      await controller.knowledge.ensureLibraryRoots(<LibraryItem>[item]);
      asset = await controller.knowledge.importAsset(source.path);
    });
    addTearDown(() async {
      controller.dispose();
      if (await temporary.exists()) {
        await temporary.delete(recursive: true);
      }
    });
    final root = controller.knowledge.rootForOwner('libraryItem', item.id)!;
    controller.knowledge.savePage(
      root.copyWith(
        document: <String, dynamic>{
          'document': <String, dynamic>{
            'type': 'page',
            'children': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'image',
                'data': <String, dynamic>{
                  'knowledgeAssetId': asset.id,
                  'knowledgeKind': 'image',
                  'knowledgeBlockId': 'block-image-test',
                  'knowledgeImageCropAspectRatio': 16 / 9,
                },
              },
            ],
          },
        },
      ),
    );
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTodoTheme(),
        locale: const Locale('es'),
        supportedLocales: const <Locale>[Locale('es')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppFlowyEditorLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: KnowledgeWorkspacePage(
          controller: controller,
          libraryItem: item,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    await tester.tap(find.byType(Image).last);
    await tester.pump();
    expect(find.byTooltip('Recortar imagen'), findsOneWidget);
    expect(find.byTooltip('Arrastra para cambiar el tamaño'), findsOneWidget);

    await tester.tap(find.byTooltip('Opciones de imagen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamaño: 50 %'));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('Recortar imagen'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Libre'));
    await tester.pump();
    final ratioLabel = find.byKey(
      const ValueKey('knowledge-image-crop-ratio-label'),
    );
    expect(ratioLabel, findsOneWidget);
    expect(tester.widget<Text>(ratioLabel).maxLines, 1);
    expect(tester.getSize(ratioLabel).height, lessThan(30));
    await tester.tap(find.text('Cuadrada'));
    await tester.tap(find.text('Aplicar recorte'));
    await tester.pump(const Duration(seconds: 1));

    final saved = controller.knowledge.rootForOwner('libraryItem', item.id)!;
    final document = saved.document['document'] as Map<String, dynamic>;
    final children = document['children'] as List<dynamic>;
    final data = (children.single as Map<String, dynamic>)['data']
        as Map<String, dynamic>;
    expect(data['knowledgeAssetId'], asset.id);
    expect(data['knowledgeImageWidth'], isA<num>());
    expect((data['knowledgeImageWidth'] as num).toDouble(), lessThan(900));
    expect(data['knowledgeImageCropAspectRatio'], 1.0);
  });
}
