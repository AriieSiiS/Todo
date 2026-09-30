import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  test(
      'el orden manual de las notas se guarda sin alterar sus fechas ni duplicarlas',
      () {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final first = controller.createNote('Casa');
    final second = controller.createNote('Trabajo');
    controller.reorderNotes([first.id, first.id, 'inexistente', second.id]);
    expect(controller.inboxNotes().take(2).map((note) => note.id),
        [first.id, second.id]);
    expect(controller.noteById(first.id)!.createdAt, first.createdAt);
    final snapshot = AppStateSnapshot.fromJson(
        jsonDecode(controller.exportSnapshot().toPrettyJson()));
    final restored = TodoWorkspace.createForTest(snapshot: snapshot);
    addTearDown(restored.dispose);
    expect(restored.inboxNotes().take(2).map((note) => note.id),
        [first.id, second.id]);
    expect(restored.notes.map((note) => note.id).toSet(),
        hasLength(restored.notes.length));
  });

  testWidgets('ordenar notas permite arrastrar y guardar el orden',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final first = controller.createNote('Primera idea');
    final second = controller.createNote('Segunda idea');
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme().copyWith(platform: TargetPlatform.windows),
        home: Scaffold(body: InboxPage(controller: controller))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordenar notas'));
    await tester.pumpAndSettle();
    final handles = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ReorderableDragStartListener));
    final gesture = await tester.startGesture(tester.getCenter(handles.first),
        kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar orden'));
    await tester.pumpAndSettle();
    expect(controller.inboxNotes().take(2).map((note) => note.id),
        [first.id, second.id]);
    expect(find.text('Orden manual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
