import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

TodoWorkspace _restaurar(TodoWorkspace origen) {
  final snapshot = AppStateSnapshot.fromJson(
    jsonDecode(origen.exportSnapshot().toPrettyJson()) as Map<String, dynamic>,
  );
  return TodoWorkspace.createForTest(snapshot: snapshot);
}

void main() {
  test('una caja guarda figuras, guía y estado al reiniciar', () {
    final controller = TodoWorkspace.createForTest();
    final kit = controller.createMiniatureKit(
      name: 'Sentinel Guard Sodality',
      game: 'La Herejía de Horus',
      faction: 'Legio Custodes',
      modelCount: 6,
    );
    expect(kit.models, hasLength(6));
    expect(kit.status, MiniatureStatus.unbuilt);

    controller.setAllMiniatureModelsStatus(kit.id, MiniatureStatus.primed);
    controller.setMiniatureModelStatus(
        kit.id, kit.models.first.id, MiniatureStatus.painted);
    controller.addMiniaturePaint(kit.id, 'Retributor Armour', 'Base');
    controller.toggleMiniaturePaintOwned(kit.id, 0);
    controller.saveMiniatureGuideStep(
      kit.id,
      const MiniaturePaintStep(
        title: 'Armadura: capa base',
        paints: ['Retributor Armour'],
      ),
    );
    controller.saveMiniatureGuideStep(
      kit.id,
      const MiniaturePaintStep(title: 'Lavado'),
    );
    controller.moveMiniatureGuideStep(kit.id, 1, -1);

    final restaurado = _restaurar(controller).miniatureKitById(kit.id)!;
    expect(restaurado.paintedCount, 1);
    expect(restaurado.status, MiniatureStatus.primed);
    expect(restaurado.paints.single.owned, isTrue);
    expect(restaurado.guide.map((step) => step.title),
        ['Lavado', 'Armadura: capa base']);
    expect(restaurado.guide.last.paints, ['Retributor Armour']);
  });

  test('una barra guardada sin Miniaturas la muestra tras Biblioteca', () {
    final snapshot = AppStateSnapshot.fromJson(<String, dynamic>{
      'navOrder': ['today', 'library', 'wardrobe', 'settings'],
    });
    final controller = TodoWorkspace.createForTest(snapshot: snapshot);
    final order = controller.navOrder;
    expect(order.indexOf(AppSection.miniatures),
        order.indexOf(AppSection.library) + 1);
  });

  testWidgets('la ficha muestra figuras, guía y fotos', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = TodoWorkspace.createForTest();
    final kit = controller.createMiniatureKit(
      name: 'Sentinel Guard Sodality',
      faction: 'Legio Custodes',
      modelCount: 2,
    );
    controller.saveMiniatureGuideStep(
      kit.id,
      const MiniaturePaintStep(title: 'Armadura: capa base'),
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MiniaturesPage(controller: controller),
        ),
      ),
    ));
    expect(find.text('0/2'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('miniature-card-${kit.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Figuras 2'));
    await tester.pumpAndSettle();
    expect(find.text('Miniatura 1'), findsOneWidget);

    await tester.tap(find.text('Terminada').first);
    await tester.pumpAndSettle();
    expect(controller.miniatureKitById(kit.id)!.paintedCount, 1);

    await tester.tap(find.text('Pintura 0/1'));
    await tester.pumpAndSettle();
    expect(find.text('1. Armadura: capa base'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('miniature-step-done')));
    await tester.pumpAndSettle();
    expect(controller.miniatureKitById(kit.id)!.guideDone, 1);

    await tester.tap(find.text('Galería'));
    await tester.pumpAndSettle();
    expect(find.text('Cuando las termines, añade aquí tus fotos.'),
        findsOneWidget);
  });

  testWidgets('la vista de 360° gira y cambia de altura al arrastrar',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final snapshot = AppStateSnapshot.fromJson(<String, dynamic>{
      'miniatureKits': [
        {
          'id': 'caja',
          'name': 'Caja de prueba',
          'models': [
            {'id': 'f1', 'name': 'Figura'}
          ],
          'spins': [
            {'name': 'Giro', 'path': 'spins/prueba', 'rows': 4, 'cols': 12}
          ],
        }
      ],
    });
    final controller = TodoWorkspace.createForTest(snapshot: snapshot);
    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MiniaturesPage(controller: controller),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('miniature-card-caja')));
    await tester.pump();

    String fotoActual() {
      final imagen = tester.widget<Image>(find.descendant(
        of: find.byKey(const ValueKey('miniature-spin')),
        matching: find.byType(Image),
      ));
      final archivo = (imagen.image as FileImage).file.path;
      return archivo.substring(archivo.length - 9);
    }

    expect(fotoActual(), '01-01.jpg');
    await tester.drag(
        find.byKey(const ValueKey('miniature-spin')), const Offset(-60, 0));
    await tester.pump();
    expect(fotoActual(), '01-05.jpg');
    await tester.drag(
        find.byKey(const ValueKey('miniature-spin')), const Offset(0, 100));
    await tester.pump();
    expect(fotoActual(), '03-05.jpg');
  });
}
