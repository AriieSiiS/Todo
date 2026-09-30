import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  test('reordenar categorías conserva las ocultas y guarda sus referencias',
      () {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final first = controller.createCategory(
        name: 'Casa uno', colorValue: 0xFF008000, icon: Icons.home);
    final hidden = controller.createCategory(
        name: 'Trabajo', colorValue: 0xFF0000FF, icon: Icons.work);
    final last = controller.createCategory(
        name: 'Casa dos', colorValue: 0xFF008000, icon: Icons.home);
    controller.reorderCategories([last.id, 'inexistente', last.id, first.id]);
    expect(controller.categories.map((category) => category.id),
        [last.id, hidden.id, first.id]);
    final restored = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson(
            jsonDecode(controller.exportSnapshot().toPrettyJson())));
    addTearDown(restored.dispose);
    expect(restored.categories.map((category) => category.id),
        [last.id, hidden.id, first.id]);
    expect(restored.categoryById(first.id)!.name, first.name);
  });

  for (final size in [const Size(1800, 1000), const Size(1000, 850)]) {
    testWidgets(
        'las categorías se arrastran directamente con búsqueda a ${size.width}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TodoWorkspace.createForTest();
      addTearDown(controller.dispose);
      final first = controller.createCategory(
          name: 'Casa uno', colorValue: 0xFF008000, icon: Icons.home);
      final hidden = controller.createCategory(
          name: 'Trabajo', colorValue: 0xFF0000FF, icon: Icons.work);
      final last = controller.createCategory(
          name: 'Casa dos', colorValue: 0xFF008000, icon: Icons.home);
      await tester.pumpWidget(MaterialApp(
          theme: buildTodoTheme(),
          home: Scaffold(body: CategoriesPage(controller: controller))));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Casa');
      await tester.pumpAndSettle();
      expect(find.text('Ordenar'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      final gesture = await tester.startGesture(tester
          .getCenter(find.byKey(ValueKey('arrastrar-categoria-${first.id}'))));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(
          tester.getCenter(find.byKey(ValueKey('categoria-${last.id}'))));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.categories.map((category) => category.id),
          [last.id, hidden.id, first.id]);
      expect(
          tester.getTopLeft(find.byKey(ValueKey('categoria-${last.id}'))).dx,
          lessThan(tester
              .getTopLeft(find.byKey(ValueKey('categoria-${first.id}')))
              .dx));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 300));
    });
  }
}
