import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';
import 'package:todo/services/task_scheduler_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('la pausa conserva la rutina y se mantiene al recargar', () {
    final workspace = TodoWorkspace.createForTest();
    addTearDown(workspace.dispose);
    final today = workspace.logicalDate();
    final routine = workspace.createTask(
      title: 'Rutina diaria',
      scheduledAt: today,
      recurrence: const RecurrenceRule(type: RecurrenceType.daily),
      reminderRules: const [ReminderRule(minutesBefore: 15)],
    );
    final child = workspace.createSubtask(routine.id, 'Primer paso');
    final completion = DateTime(2026, 1, 1, 12);
    workspace.updateTask(workspace.taskById(routine.id)!.copyWith(
      recurrenceCompletions: {'2026-01-01': completion},
      skippedRecurrenceOccurrences: {'2026-01-02'},
    ));
    final single = workspace.createTask(title: 'Tarea puntual');

    workspace.setRoutinePaused(single.id, true);
    workspace.setRoutinePaused(child.id, true);
    workspace.setRoutinePaused(routine.id, true);

    final paused = workspace.taskById(routine.id)!;
    expect(paused.routinePaused, isTrue);
    expect(paused.status, TaskStatus.archived);
    expect(workspace.taskById(single.id)!.status, TaskStatus.active);
    expect(workspace.taskById(child.id)!.status, TaskStatus.active);
    expect(workspace.tasksForToday().map((task) => task.id),
        isNot(contains(routine.id)));
    expect(paused.recurrence.type, RecurrenceType.daily);
    expect(paused.reminderRules.single.minutesBefore, 15);
    expect(paused.subtaskIds, contains(child.id));
    expect(paused.recurrenceCompletions['2026-01-01'], completion);
    expect(paused.skippedRecurrenceOccurrences, contains('2026-01-02'));

    final restored = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot.fromJson({
        'tasks': workspace.tasks.map((task) => task.toJson()).toList(),
      }),
    );
    addTearDown(restored.dispose);
    expect(
        restored.pausedRoutines().map((task) => task.id), contains(routine.id));
    restored.setRoutinePaused(routine.id, false);
    expect(restored.taskById(routine.id)!.routinePaused, isFalse);
    expect(restored.taskById(routine.id)!.status, TaskStatus.active);
    expect(
        restored.tasksForToday().map((task) => task.id), contains(routine.id));
    expect(restored.taskById(routine.id)!.recurrenceCompletions['2026-01-01'],
        completion);
  });

  test('una rutina deja de estar en pausa si pasa a ser una tarea única', () {
    final workspace = TodoWorkspace.createForTest();
    addTearDown(workspace.dispose);
    final routine = workspace.createTask(
      title: 'Rutina semanal',
      recurrence: const RecurrenceRule(type: RecurrenceType.weekly),
    );
    workspace.setRoutinePaused(routine.id, true);
    workspace.updateTask(workspace.taskById(routine.id)!.copyWith(
          recurrence: const RecurrenceRule(),
        ));
    expect(workspace.taskById(routine.id)!.status, TaskStatus.active);
    expect(workspace.taskById(routine.id)!.routinePaused, isFalse);
    expect(workspace.pausedRoutines(), isEmpty);
  });

  test('la pausa evita los avisos de la rutina y sus subtareas', () {
    final scheduled = DateTime(2026, 10, 28, 18);
    final reminder = const [ReminderRule(minutesBefore: 0, enabled: true)];
    final plans = TaskSchedulerService().buildPlans(
      tasks: [
        TaskModel(
          id: 'rutina',
          title: 'Rutina pausada',
          status: TaskStatus.archived,
          routinePaused: true,
          recurrence: const RecurrenceRule(type: RecurrenceType.daily),
          scheduledAt: scheduled,
          reminderRules: reminder,
        ),
        TaskModel(
          id: 'paso',
          title: 'Paso de la rutina',
          parentTaskId: 'rutina',
          scheduledAt: scheduled,
          reminderRules: reminder,
        ),
        TaskModel(
          id: 'otra',
          title: 'Tarea independiente',
          scheduledAt: scheduled,
          reminderRules: reminder,
        ),
      ],
      notes: const [],
      daySettings: const DaySettings(),
      notificationSettings: const DeviceNotificationSettings(
        notificationsEnabled: true,
        dayStartReminderEnabled: false,
        dayEndReminderEnabled: false,
      ),
      now: DateTime(2026, 10, 28, 12),
    );
    expect(plans.map((plan) => plan.taskId), ['otra']);
  });

  testWidgets('una rutina pausada sin categoría se puede reanudar desde Hoy',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final routine = TaskModel.fromJson({
      'id': 'rutina',
      'title': 'Rutina sin categoría',
      'status': 'archived',
      'routinePaused': true,
      'recurrence': {'type': 'daily'},
    });
    final workspace = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot.fromJson({
        'tasks': [routine.toJson()]
      }),
    );
    addTearDown(workspace.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: workspace,
          builder: (context, child) => TodayPage(controller: workspace),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Rutinas en pausa (1)'), findsNothing);
    expect(find.byTooltip('Rutinas en pausa (1)'), findsOneWidget);
    await tester.tap(find.byTooltip('Rutinas en pausa (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Rutina sin categoría'), findsOneWidget);
    await tester.tap(find.text('Reanudar'));
    await tester.pumpAndSettle();

    expect(
        workspace.tasksForToday().map((task) => task.id), contains('rutina'));
    expect(workspace.taskById('rutina')!.status, TaskStatus.active);
  });

  testWidgets('el menú de una rutina permite pausarla', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workspace = TodoWorkspace.createForTest();
    addTearDown(workspace.dispose);
    final routine = workspace.createTask(
      title: 'Rutina diaria',
      scheduledAt: workspace.logicalDate(),
      recurrence: const RecurrenceRule(type: RecurrenceType.daily),
    );
    workspace.createTask(
      title: 'Tarea puntual',
      scheduledAt: workspace.logicalDate(),
    );
    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: workspace,
          builder: (context, child) => TodayPage(controller: workspace),
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Rutina diaria'),
        buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Pausar rutina'), findsOneWidget);
    await tester.tap(find.text('Pausar rutina'));
    await tester.pumpAndSettle();
    expect(workspace.taskById(routine.id)!.routinePaused, isTrue);
    expect(find.text('Rutinas en pausa (1)'), findsNothing);
    expect(find.byTooltip('Rutinas en pausa (1)'), findsOneWidget);
    await tester.tap(find.text('Tarea puntual'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Pausar rutina'), findsNothing);
  });

  testWidgets('la categoría permite reanudar su rutina pausada',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final workspace = TodoWorkspace.createForTest();
    addTearDown(workspace.dispose);
    final category = workspace.createCategory(
      name: 'Casa',
      colorValue: 0xff607a5a,
      icon: Icons.home_rounded,
    );
    final routine = workspace.createTask(
      title: 'Rutina de casa',
      categoryIds: [category.id],
      recurrence: const RecurrenceRule(type: RecurrenceType.weekly),
    );
    workspace.setRoutinePaused(routine.id, true);
    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: workspace,
          builder: (context, child) => CategoriesPage(controller: workspace),
        ),
      ),
    ));
    await tester.pump();
    await tester.ensureVisible(find.text('Reanudar'));
    await tester.tap(find.text('Reanudar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(workspace.taskById(routine.id)!.status, TaskStatus.active);
    expect(find.text('Pausar'), findsOneWidget);
  });
}
