import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/application/providers/todo_providers.dart';
import 'package:todo/app/app_launch_intent.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/data/runtime_state_paths.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _clearRuntimeFiles();
  });

  testWidgets('renders today workspace', (WidgetTester tester) async {
    final controller = TodoWorkspace.createForTest();

    _configureLargeSurface(tester);

    await _pumpShell(tester, controller);
    await tester.pump();

    expect(find.text('Hoy'), findsWidgets);
    expect(find.textContaining('Inbox'), findsWidgets);
  });

  testWidgets('loads persisted snapshot', (WidgetTester tester) async {
    final snapshot = AppStateSnapshot(
      tasks: const [
        TaskModel(
          id: 'persisted-task',
          title: 'Persisted task',
          priority: TaskPriority.high,
          manualOrder: 0,
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
    );

    final controller = TodoWorkspace.createForTest(snapshot: snapshot);

    _configureLargeSurface(tester);

    await _pumpShell(tester, controller);
    await tester.pump();

    expect(find.text('Persisted task'), findsOneWidget);
  });

  for (final entry in <AppSection, String>{
    AppSection.today: 'Hoy',
    AppSection.projects: 'Proyectos',
    AppSection.categories: 'Categorias',
    AppSection.calendar: 'Calendario',
    AppSection.completed: 'Completadas',
    AppSection.settings: 'Ajustes',
  }.entries) {
    testWidgets('renders ${entry.key.name} workspace',
        (WidgetTester tester) async {
      final controller = TodoWorkspace.createForTest(
        snapshot: _snapshotForSection(entry.key),
      );

      _configureLargeSurface(tester);
      await _ignoreRenderOverflow(() async {
        await _pumpShell(tester, controller);
        await tester.pump();
      });

      expect(find.text(entry.value), findsWidgets);
    });
  }

  testWidgets('music player expands and closes when tapping outside', (
    WidgetTester tester,
  ) async {
    final controller = TodoWorkspace.createForTest();

    _configureLargeSurface(tester);

    await _pumpShell(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('Abrir reproductor'), findsOneWidget);

    await tester.tap(find.text('Abrir reproductor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Se reproduce en bucle automaticamente.'), findsOneWidget);

    await tester.tapAt(const Offset(80, 80));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Se reproduce en bucle automaticamente.'), findsNothing);
  });

  test('controller imports json and can reset to seed', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = TodoWorkspace.createForTest();

    final snapshot = AppStateSnapshot(
      tasks: const [
        TaskModel(
          id: 'imported-task',
          title: 'Imported task',
          priority: TaskPriority.urgent,
          manualOrder: 0,
        ),
      ],
      categories: const [],
      projects: const [],
      notes: const [],
      daySettings: const DaySettings(dayEndsAtHour: 4),
      notificationSettings: const DeviceNotificationSettings(),
      calendarSettings: const CalendarIntegrationSettings(),
      section: AppSection.today,
      todaySort: TodaySort.priority,
    );

    expect(controller.importStateFromJson(snapshot.toEncodedJson()), isTrue);
    expect(
        controller.tasks.any((task) => task.title == 'Imported task'), isTrue);
    expect(controller.settings.dayEndsAtHour, 4);

    await controller.resetToSeed();

    expect(
        controller.tasks.any((task) => task.title == 'Weekly reset'), isTrue);
    expect(
        controller.tasks.any((task) => task.title == 'Imported task'), isFalse);
  });

  test('snapshot json keeps the shared persistence contract', () {
    final snapshot = AppStateSnapshot(
      tasks: const [
        TaskModel(
          id: 'json-task',
          title: 'JSON task',
          priority: TaskPriority.high,
          manualOrder: 1,
        ),
      ],
      categories: const [],
      projects: const [],
      notes: const [],
      daySettings: const DaySettings(dayEndsAtHour: 4),
      notificationSettings: const DeviceNotificationSettings(
        defaultMinutesBeforeTask: 20,
      ),
      calendarSettings: const CalendarIntegrationSettings(
        selectedCalendarId: 'primary',
      ),
      section: AppSection.calendar,
      todaySort: TodaySort.priority,
      visualMode: AppVisualMode.phantom,
      updatedAt: DateTime.utc(2026, 4, 29, 10),
      schemaVersion: 1,
      lastModifiedBy: 'test@example.com',
    );

    final decoded = AppStateSnapshot.fromEncodedJson(snapshot.toEncodedJson());
    final json = decoded.toJson();

    expect(
        json.keys,
        containsAll(<String>[
          'tasks',
          'categories',
          'projects',
          'notes',
          'daySettings',
          'notificationSettings',
          'calendarSettings',
          'section',
          'todaySort',
          'visualMode',
          'updatedAt',
          'schemaVersion',
          'lastModifiedBy',
        ]));
    expect(decoded.tasks.single.title, 'JSON task');
    expect(decoded.section, AppSection.calendar);
    expect(decoded.todaySort, TodaySort.priority);
    expect(decoded.visualMode, AppVisualMode.phantom);
    expect(decoded.lastModifiedBy, 'test@example.com');
  });

  test('riverpod workspace provider exposes the application state', () {
    final controller = TodoWorkspace.createForTest();
    final container = ProviderContainer(
      overrides: [
        todoWorkspaceProvider.overrideWith((ref) => controller),
      ],
    );
    addTearDown(container.dispose);

    final workspace = container.read(todoWorkspaceProvider);
    final task = workspace.createTask(title: 'Provider task');
    workspace.changePriority(task.id, TaskPriority.urgent);
    workspace.createProject(
      name: 'Provider project',
      colorValue: const Color(0xFF607A5A).toARGB32(),
      icon: Icons.folder_open_rounded,
    );

    expect(controller.taskById(task.id)?.priority, TaskPriority.urgent);
    expect(
      controller.projects.any((project) => project.name == 'Provider project'),
      isTrue,
    );
  });

  test(
      'controller creates next recurring instance and stores reminder settings',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final controller = TodoWorkspace.createForTest();

    final task = controller.createTask(
      title: 'Recurring sample',
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      recurrence: const RecurrenceRule(type: RecurrenceType.daily),
      reminderRule: const ReminderRule(enabled: true, minutesBefore: 15),
    );

    await controller.completeTask(task.id);

    final recurrenceTasks = controller.tasks
        .where((item) => item.title == 'Recurring sample')
        .toList();
    expect(recurrenceTasks.length, 2);
    expect(recurrenceTasks.any((item) => item.status == TaskStatus.active),
        isTrue);
    expect(
      recurrenceTasks.any((item) => item.reminderRule?.enabled ?? false),
      isTrue,
    );
  });
}

Future<void> _pumpShell(
  WidgetTester tester,
  TodoWorkspace controller,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todoWorkspaceProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(
        theme: buildTodoTheme(),
        home: const AppShell(
          launchIntent: AppLaunchIntent(),
        ),
      ),
    ),
  );
}

AppStateSnapshot _snapshotForSection(AppSection section) {
  return AppStateSnapshot(
    tasks: const [],
    categories: const [],
    projects: const [],
    notes: const [],
    daySettings: const DaySettings(),
    notificationSettings: const DeviceNotificationSettings(),
    calendarSettings: const CalendarIntegrationSettings(),
    section: section,
    todaySort: TodaySort.manual,
  );
}

Future<void> _ignoreRenderOverflow(Future<void> Function() body) async {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
      return;
    }
    previous?.call(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
}

Future<void> _clearRuntimeFiles() async {
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  final runtimeDirectory = Directory(
    '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}Todo${Platform.pathSeparator}${RuntimeStatePaths.runtimeDirectoryName}',
  );
  final stateFile = File(
    '${runtimeDirectory.path}${Platform.pathSeparator}${RuntimeStatePaths.stateFileName}',
  );
  final sessionFile = File(
    '${runtimeDirectory.path}${Platform.pathSeparator}${RuntimeStatePaths.calendarSessionFileName}',
  );
  if (await stateFile.exists()) {
    await stateFile.delete();
  }
  if (await sessionFile.exists()) {
    await sessionFile.delete();
  }
}

void _configureLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(3600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
