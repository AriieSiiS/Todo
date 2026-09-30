import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/application/state/todo_workspace.dart';

void main() {
  test('el orden manual se exporta y conserva categorías no incluidas', () {
    final controller = TodoWorkspace.createForTest();
    final first = controller.createCategory(
        name: 'Casa', colorValue: 0xFF008000, icon: Icons.home);
    final second = controller.createCategory(
        name: 'Trabajo', colorValue: 0xFF0000FF, icon: Icons.work);
    controller
        .reorderCategories([second.id, second.id, 'inexistente', first.id]);
    final ids = controller.categories.map((category) => category.id).toList();
    expect(ids.take(2), [second.id, first.id]);
    expect(ids.toSet(), hasLength(ids.length));
    expect(
        controller.exportSnapshot().categories.map((category) => category.id),
        ids);
  });
}
