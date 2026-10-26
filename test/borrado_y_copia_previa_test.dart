import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/services/full_backup_service.dart';

void main() {
  test('borrar tareas con subtareas se puede deshacer sin perder nada', () {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final parent = controller.createTask(title: 'Mudanza');
    final subtask = controller.createSubtask(parent.id, 'Embalar libros');
    final other = controller.createTask(title: 'Llamar al banco');
    final before = controller.tasks.map((task) => task.id).toList();

    final deletion = controller.deleteTasks(<String>[parent.id, other.id]);
    expect(deletion.count, 3);
    final remaining = controller.tasks.map((task) => task.id).toSet();
    expect(remaining, isNot(contains(parent.id)));
    expect(remaining, isNot(contains(subtask.id)));
    expect(remaining, isNot(contains(other.id)));

    controller.restoreDeletedTasks(deletion);
    expect(controller.tasks.map((task) => task.id).toList(), before);
    final restoredParent =
        controller.tasks.firstWhere((task) => task.id == parent.id);
    expect(restoredParent.subtaskIds, contains(subtask.id));
  });

  test('la copia previa a un cambio grande se verifica y rota', () async {
    final root = await Directory.systemTemp.createTemp('todo_copia_previa');
    addTearDown(() => root.delete(recursive: true));
    final service = FullBackupService(destinationRoot: root);

    File? last;
    for (var i = 0; i < 4; i++) {
      last = await service.saveSnapshotBeforeChange(
        '{"copia": $i}',
        label: 'importar json',
        keep: 3,
        now: DateTime(2026, 10, 18, 12, 0, i),
      );
    }
    expect(await last!.readAsString(), '{"copia": 3}');
    expect(last.path, contains('_antes-de-cambios'));
    expect(last.path, contains('todo_state-importar-json-20261018-120003'));
    final copies = service.snapshotsBeforeChangesDirectory
        .listSync()
        .whereType<File>()
        .toList();
    expect(copies, hasLength(3));
  });

  testWidgets('Hoy pide confirmación antes de borrar y deja deshacer',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final task = controller.createTask(
      title: 'Tarea para borrar',
      scheduledAt: controller.logicalDate(),
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme().copyWith(platform: TargetPlatform.windows),
      home: Scaffold(body: TodayPage(controller: controller)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seleccionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seleccionar visibles'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm-delete-tasks')), findsOneWidget);

    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    expect(controller.tasks.any((item) => item.id == task.id), isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-tasks')));
    await tester.pumpAndSettle();
    expect(controller.tasks.any((item) => item.id == task.id), isFalse);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(controller.tasks.any((item) => item.id == task.id), isTrue);
  });
}
