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
        'las categorías abren hueco al arrastrar con búsqueda a ${size.width}',
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
      final lastCard = find.byKey(ValueKey('categoria-${last.id}'));
      final initialPosition = tester.getTopLeft(lastCard);
      final destination = tester.getCenter(lastCard);
      final gesture = await tester.startGesture(tester
          .getCenter(find.byKey(ValueKey('arrastrar-categoria-${first.id}'))));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(destination);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final intermediatePosition = tester.getTopLeft(lastCard);
      expect(intermediatePosition.dx, lessThan(initialPosition.dx));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getTopLeft(lastCard).dx, lessThan(intermediatePosition.dx));
      expect(controller.categories.map((category) => category.id),
          [first.id, hidden.id, last.id]);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.categories.map((category) => category.id),
          [last.id, hidden.id, first.id]);
      expect(find.text('Casa uno'), findsNWidgets(2));
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
