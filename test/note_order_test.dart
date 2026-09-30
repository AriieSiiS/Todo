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

  for (final grid in [false, true]) {
    testWidgets(
        'las notas se arrastran directamente con animación en ${grid ? 'cuadrícula' : 'lista'}',
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
      if (grid) {
        await tester.tap(find.byTooltip('Vista de cuadrícula'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Ordenar notas'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      final stationary = find.byKey(ValueKey('arrastrar-nota-${first.id}'));
      final initialPosition = tester.getCenter(stationary);
      final handle = find.byKey(ValueKey('arrastrar-nota-${second.id}'));
      final gesture = await tester.startGesture(tester.getCenter(handle),
          kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 100));
      if (grid) {
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
        await gesture.moveTo(initialPosition);
      } else {
        final gap = initialPosition.dy - tester.getCenter(handle).dy;
        await gesture.moveBy(Offset(0, gap * 0.5));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final middle = tester.getCenter(stationary);
      expect(middle, isNot(initialPosition));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getCenter(stationary), isNot(middle));
      expect(controller.inboxNotes().take(2).map((note) => note.id),
          [second.id, first.id]);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.inboxNotes().take(2).map((note) => note.id),
          [first.id, second.id]);
      expect(find.text('Orden manual'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 300));
    });
  }

  test('mover notas filtradas conserva la posición de las ocultas y archivadas',
      () {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final last = controller.createNote('Casa dos');
    final hidden = controller.createNote('Trabajo');
    final first = controller.createNote('Casa uno');
    controller.archiveNote(hidden.id);
    controller.reorderNotes([last.id, first.id]);
    expect(controller.notes.map((note) => note.id),
        [last.id, hidden.id, first.id]);
    expect(controller.noteById(hidden.id)!.status, NoteStatus.archived);
  });

  testWidgets('la cuadrícula se desplaza al borde y cancela al soltar fuera',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    for (var i = 0; i < 12; i++) {
      controller.createNote('Idea $i');
    }
    final ids = controller.inboxNotes().map((note) => note.id).toList();
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: InboxPage(controller: controller))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Vista de cuadrícula'));
    await tester.pumpAndSettle();
    final handle = find.byKey(ValueKey('arrastrar-nota-${ids.first}'));
    final scrollable =
        find.ancestor(of: handle, matching: find.byType(Scrollable)).first;
    final bounds = tester.getRect(scrollable);
    final gesture = await tester.startGesture(tester.getCenter(handle),
        kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveTo(Offset(bounds.center.dx, bounds.bottom - 8));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0));
    await gesture.moveTo(Offset(bounds.right + 30, bounds.center.dy));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.inboxNotes().map((note) => note.id), ids);
    expect(
        tester
            .widget<AnimatedPositioned>(
                find.byKey(ValueKey('posicion-nota-${ids.first}')))
            .top,
        0);
    expect(tester.takeException(), isNull);
  });
}
