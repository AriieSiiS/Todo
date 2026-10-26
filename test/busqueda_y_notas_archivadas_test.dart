import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/presentation/shared/texto_busqueda.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  test('la búsqueda ignora mayúsculas, tildes, diéresis y la eñe', () {
    expect(coincideBusqueda('Canción de cuna', 'cancion'), isTrue);
    expect(coincideBusqueda('cancion de cuna', 'CANCIÓN'), isTrue);
    expect(coincideBusqueda('Pingüino', 'pinguino'), isTrue);
    expect(coincideBusqueda('Año nuevo', 'ano'), isTrue);
    expect(coincideBusqueda('Lámpara', ''), isTrue);
    expect(coincideBusqueda('Lámpara', 'mesa'), isFalse);
    expect(normalizarBusqueda('Ácido Él Ñu'), 'acido el nu');
  });

  test('las notas archivadas se listan y se pueden restaurar', () {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final note = controller.createNote('Idea archivada');
    controller.archiveNote(note.id);
    expect(controller.archivedNotes().map((item) => item.id), [note.id]);
    expect(controller.inboxNotes().map((item) => item.id),
        isNot(contains(note.id)));
    controller.restoreNote(note.id);
    expect(controller.archivedNotes(), isEmpty);
    expect(controller.inboxNotes().map((item) => item.id), contains(note.id));
  });

  testWidgets('Notas busca sin tildes y restaura desde archivadas',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    controller.createNote('Canción para el viaje');
    final archived = controller.createNote('Receta guardada');
    controller.archiveNote(archived.id);

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme().copyWith(platform: TargetPlatform.windows),
      home: Scaffold(body: InboxPage(controller: controller)),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('inbox-search')),
        matching: find.byType(TextField),
      ),
      'cancion',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Canción para el viaje'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('inbox-show-archived')));
    await tester.pumpAndSettle();
    expect(find.text('Notas archivadas'), findsOneWidget);
    expect(find.text('Receta guardada'), findsOneWidget);

    await tester
        .tap(find.byKey(ValueKey('archived-note-restore-${archived.id}')));
    await tester.pumpAndSettle();
    expect(controller.archivedNotes(), isEmpty);
    expect(find.text('No hay notas archivadas.'), findsOneWidget);
  });
}
