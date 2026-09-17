import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shared/editors.dart';

Future<void> _pumpEditor(
  WidgetTester tester,
  TodoWorkspace controller, {
  TaskModel? initialTask,
  Size size = const Size(1800, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTodoTheme(),
      locale: const Locale('es', 'ES'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showTaskEditor(
              context,
              controller,
              initialTask: initialTask,
              initialDateOverride: DateTime(2026, 9, 14),
            ),
            child: const Text('Abrir editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir editor'));
  await tester.pumpAndSettle();
}

String _selectedTime(WidgetTester tester) {
  final value = find.descendant(
    of: find.byKey(const ValueKey('selector-hora-valor')),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(value).data!;
}

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

void main() {
  test('las listas antiguas se migran a subtareas visibles', () {
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: [
          TaskModel(
            id: 'estiramientos',
            title: 'Estiramientos',
            scheduledAt: DateTime(2026, 9, 14),
            checklist: const [
              'Estiramientos de mañana',
              'Estiramientos de noche',
            ],
          ),
        ],
        categories: const [],
        projects: const [],
        notes: const [],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.today,
        todaySort: TodaySort.manual,
      ),
    );

    final parent = controller.taskById('estiramientos')!;
    expect(parent.checklist, isEmpty);
    expect(
      controller.subtasksOf(parent).map((task) => task.title),
      ['Estiramientos de mañana', 'Estiramientos de noche'],
    );
    expect(parent.subtaskIds, hasLength(2));
  });

  testWidgets('las subtareas del editor se guardan como tareas enlazadas',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    await _pumpEditor(tester, controller);
    await tester.enterText(find.byType(TextField).first, 'Rutina diaria');

    await tester.ensureVisible(find.text('Añadir subtarea'));
    await tester.tap(find.text('Añadir subtarea'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('subtask-input-0')),
      'Primer paso',
    );

    await tester.tap(find.text('Guardar tarea'));
    await tester.pumpAndSettle();

    final parent = controller.tasks.singleWhere((task) => !task.isSubtask);
    expect(parent.checklist, isEmpty);
    expect(
      controller.subtasksOf(parent).map((task) => task.title),
      ['Primer paso'],
    );
  });

  testWidgets('el editor elimina vacíos y muestra los avisos acumulables',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    await _pumpEditor(tester, controller);

    expect(find.text('Sin subtareas todavía.'), findsNothing);
    expect(
      find.text('Usar limpiador multiusos y dejar todo ordenado.'),
      findsNothing,
    );
    expect(find.text('A la hora exacta'), findsOneWidget);
    expect(find.text('5 min antes'), findsOneWidget);
    expect(find.text('15 min antes'), findsOneWidget);
    expect(find.text('30 min antes'), findsOneWidget);
    expect(find.text('1 hora antes'), findsOneWidget);
    expect(find.text('24 horas antes'), findsOneWidget);
    expect(find.text('Avisos activos: ninguno'), findsOneWidget);
    expect(
      find.textContaining('Puedes activar tantos avisos como necesites.'),
      findsNothing,
    );
  });

  testWidgets('las flechas cambian la hora y activan el aviso exacto',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final task = controller.createTask(
      title: 'Fisio',
      scheduledAt: DateTime(2026, 9, 14, 18, 54),
    );
    await _pumpEditor(tester, controller, initialTask: task);

    await tester.tap(find.text('18:54'));
    await tester.pumpAndSettle();
    expect(find.text('Seleccionar hora'), findsOneWidget);
    expect(_selectedTime(tester), '18:54');

    await tester.tap(
      find.byKey(const ValueKey('selector-minutos-incrementar')),
    );
    await tester.pumpAndSettle();
    expect(_selectedTime(tester), '18:55');
    await tester.tap(find.byKey(const ValueKey('selector-hora-aceptar')));
    await tester.pumpAndSettle();

    final exactChip = tester.widget<FilterChip>(
      find.ancestor(
        of: find.text('A la hora exacta'),
        matching: find.byType(FilterChip),
      ),
    );
    expect(exactChip.selected, isTrue);
    expect(find.textContaining('a las 18:55'), findsOneWidget);

    await tester.ensureVisible(find.text('5 min antes'));
    await tester.tap(find.text('5 min antes'));
    await tester.pump();
    expect(find.text('Avisos activos (2)'), findsOneWidget);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(controller.tasks.single.scheduledAt?.hour, 18);
    expect(controller.tasks.single.scheduledAt?.minute, 55);
    expect(
      controller.tasks.single.reminderRules.map((rule) => rule.minutesBefore),
      <int>[0, 5],
    );
  });

  testWidgets('cada aviso permite activar y quitar el modo importante',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final task = controller.createTask(
      title: 'Apagar el horno',
      scheduledAt: DateTime(2026, 9, 14, 19),
      reminderRules: const [
        ReminderRule(enabled: true, minutesBefore: 5),
      ],
    );
    await _pumpEditor(tester, controller, initialTask: task);

    final importantSwitch = find.byKey(const ValueKey('important-reminder-5'));
    await tester.ensureVisible(importantSwitch);
    expect(tester.widget<Switch>(importantSwitch).value, isFalse);
    await tester.tap(importantSwitch);
    await tester.pump();
    expect(tester.widget<Switch>(importantSwitch).value, isTrue);

    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(
      controller.tasks.single.reminderRules.single.deliveryMode,
      ReminderDeliveryMode.important,
    );
  });

  testWidgets('Cada X días permite indicar y guardar el intervalo',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    await _pumpEditor(tester, controller);
    await tester.enterText(find.byType(TextField).first, 'Regar las plantas');

    await tester.ensureVisible(find.text('Sin repetición'));
    await tester.tap(find.text('Sin repetición'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cada X días').last);
    await tester.pumpAndSettle();

    final intervalInput =
        find.byKey(const ValueKey('recurrence-interval-input'));
    expect(intervalInput, findsOneWidget);
    await tester.enterText(intervalInput, '4');
    await tester.tap(find.text('Guardar tarea'));
    await tester.pumpAndSettle();

    expect(controller.tasks.single.recurrence.type, RecurrenceType.everyXDays);
    expect(controller.tasks.single.recurrence.interval, 4);
  });

  testWidgets('las ruedas responden a arrastre y rueda del ratón',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final task = controller.createTask(
      title: 'Temporizador',
      scheduledAt: DateTime(2026, 9, 14, 18, 54),
    );
    await _pumpEditor(tester, controller, initialTask: task);
    await tester.tap(find.text('18:54'));
    await tester.pumpAndSettle();

    final minuteWheel = find.byKey(const ValueKey('selector-minutos-rueda'));
    await tester.drag(minuteWheel, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(_selectedTime(tester), isNot('18:54'));

    final hourWheel = find.byKey(const ValueKey('selector-hora-rueda'));
    final beforeWheel = _selectedTime(tester);
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(hourWheel),
        scrollDelta: const Offset(0, 40),
      ),
    );
    await tester.pumpAndSettle();
    expect(_selectedTime(tester), isNot(beforeWheel));
  });

  testWidgets('Ahora y +30 min actualizan la selección sin aceptar',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final task = controller.createTask(
      title: 'Cocina',
      scheduledAt: DateTime(2026, 9, 14, 18, 55),
    );
    await _pumpEditor(tester, controller, initialTask: task);
    await tester.tap(find.text('18:55'));
    await tester.pumpAndSettle();

    final beforeNow = DateTime.now();
    await tester.tap(find.byKey(const ValueKey('selector-hora-ahora')));
    await tester.pumpAndSettle();
    final afterNow = DateTime.now();
    expect(
      _selectedTime(tester),
      anyOf(_formatTime(beforeNow), _formatTime(afterNow)),
    );

    final beforePlus = DateTime.now().add(const Duration(minutes: 30));
    await tester.tap(find.byKey(const ValueKey('selector-hora-mas-30')));
    await tester.pumpAndSettle();
    final afterPlus = DateTime.now().add(const Duration(minutes: 30));
    expect(
      _selectedTime(tester),
      anyOf(_formatTime(beforePlus), _formatTime(afterPlus)),
    );

    await tester.tap(find.byKey(const ValueKey('selector-hora-cerrar')));
    await tester.pumpAndSettle();
    expect(find.text('18:55'), findsOneWidget);
  });

  testWidgets('Cancelar conserva todo y Sin hora elimina todos los avisos',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final task = controller.createTask(
      title: 'Horno',
      scheduledAt: DateTime(2026, 9, 14, 18, 55),
      reminderRules: const [
        ReminderRule(enabled: true, minutesBefore: 0),
        ReminderRule(enabled: true, minutesBefore: 5),
      ],
    );
    await _pumpEditor(tester, controller, initialTask: task);

    await tester.tap(find.text('18:55'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selector-hora-sin-hora')));
    await tester.pump();
    expect(_selectedTime(tester), 'Sin hora');
    await tester.tap(find.byKey(const ValueKey('selector-hora-cancelar')));
    await tester.pumpAndSettle();
    expect(find.text('18:55'), findsOneWidget);
    expect(find.text('Avisos activos (2)'), findsOneWidget);

    await tester.tap(find.text('18:55'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selector-hora-sin-hora')));
    await tester.tap(find.byKey(const ValueKey('selector-hora-aceptar')));
    await tester.pumpAndSettle();
    expect(find.text('Avisos activos: ninguno'), findsOneWidget);
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(controller.tasks.single.scheduledAt?.hour, 0);
    expect(controller.tasks.single.scheduledAt?.minute, 0);
    expect(controller.tasks.single.reminderRules, isEmpty);
  });

  testWidgets(
      'el selector conserva todos los controles en una ventana estrecha',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    final task = controller.createTask(
      title: 'Ventana estrecha',
      scheduledAt: DateTime(2026, 9, 14, 18, 55),
    );
    await _pumpEditor(
      tester,
      controller,
      initialTask: task,
      size: const Size(480, 900),
    );
    await tester.ensureVisible(find.text('18:55'));
    await tester.tap(find.text('18:55'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('selector-hora-ahora')), findsOneWidget);
    expect(find.byKey(const ValueKey('selector-hora-mas-30')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('selector-hora-sin-hora')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('selector-hora-aceptar')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
