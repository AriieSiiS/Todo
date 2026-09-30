import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
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
}
