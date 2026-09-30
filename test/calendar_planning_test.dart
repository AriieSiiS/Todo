import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'reprogramar conserva la hora al cambiar de día y la duración del evento',
      () async {
    final controller = TodoWorkspace.createForTest();
    final task = controller.createTask(
        title: 'Preparar informe', scheduledAt: DateTime(2026, 9, 10, 10, 15));
    await controller.rescheduleCalendarEntry(
        id: task.id,
        isTask: true,
        destination: DateTime(2026, 9, 11),
        preserveTime: true);
    expect(controller.tasks.single.scheduledAt, DateTime(2026, 9, 11, 10, 15));
    final note = controller.createNote('Reunión');
    final event = controller.convertNoteToCalendarEvent(note.id,
        startAt: DateTime(2026, 9, 10, 12),
        duration: const Duration(minutes: 90));
    await controller.rescheduleCalendarEntry(
        id: event.id,
        isTask: false,
        destination: DateTime(2026, 9, 12, 15, 30));
    expect(controller.calendarEvents.single.startAt,
        DateTime(2026, 9, 12, 15, 30));
    expect(controller.calendarEvents.single.endAt, DateTime(2026, 9, 12, 17));
  });

  testWidgets('arrastrar una tarea en el mes cambia su fecha', (tester) async {
    final controller = TodoWorkspace.createForTest();
    addTearDown(controller.dispose);
    final today = controller.logicalDate();
    final source = DateTime(today.year, today.month, 10, 10, 15);
    final destination = DateTime(today.year, today.month, 11);
    final task =
        controller.createTask(title: 'Preparar informe', scheduledAt: source);
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: CalendarPage(controller: controller))));
    await tester.pumpAndSettle();
    final from = tester
        .getCenter(find.byKey(ValueKey('calendar-drag-${task.id}')).first);
    final to = tester.getCenter(
        find.byKey(ValueKey('calendar-drop-${destination.toIso8601String()}')));
    await tester.dragFrom(from, to - from);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(controller.tasks.single.scheduledAt,
        DateTime(today.year, today.month, 11, 10, 15));
    expect(tester.takeException(), isNull);
  });

  test(
      'los bloques se conservan y detectan solapamientos sin contar extremos contiguos',
      () {
    final controller = TodoWorkspace.createForTest();
    final first = controller.createTask(title: 'Escribir');
    final second = controller.createTask(title: 'Revisar');
    final start = DateTime(2026, 10, 1, 10);
    controller.reserveTaskTimeBlock(first.id, start, 90);
    controller.reserveTaskTimeBlock(
        second.id, start.add(const Duration(minutes: 60)), 30);
    expect(
        controller.calendarConflicts(
            start: start,
            end: start.add(const Duration(minutes: 90)),
            excludeTaskId: first.id),
        ['Revisar']);
    expect(
        controller.calendarConflicts(
            start: start.add(const Duration(minutes: 90)),
            end: start.add(const Duration(hours: 2))),
        isEmpty);
    expect(TaskModel.fromJson(controller.tasks.first.toJson()).timeBlockMinutes,
        90);
    expect(
        TaskModel.fromJson({'id': 'antigua', 'title': 'Antigua'})
            .timeBlockMinutes,
        isNull);
    expect(controller.tasks, hasLength(2));
  });

  testWidgets(
      'reservar un bloque avisa del evento y utiliza la tarea existente',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final task = controller.createTask(title: 'Escribir');
    final day = controller.logicalDate();
    final note = controller.createNote('Cita');
    controller.convertNoteToCalendarEvent(note.id,
        startAt: DateTime(day.year, day.month, day.day, 10, 30));
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: CalendarPage(controller: controller))));
    await tester.tap(find.text('Reservar bloque'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Se solapa con Cita'), findsOneWidget);
    await tester.tap(find.text('Reservar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(controller.tasks.single.id, task.id);
    expect(controller.tasks.single.timeBlockMinutes, 60);
    expect(find.textContaining('Hay solapamientos'), findsOneWidget);
    controller.dispose();
  });
}
