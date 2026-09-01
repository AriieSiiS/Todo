import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/application/providers/todo_providers.dart';
import 'package:todo/app/app_launch_intent.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders today workspace', (WidgetTester tester) async {
    final controller = TodoWorkspace.createForTest();

    _configureLargeSurface(tester);

    await _ignoreRenderOverflow(() async {
      await _pumpShell(tester, controller);
      await tester.pump();
    });

    expect(find.text('Hoy'), findsWidgets);
    expect(find.textContaining('Entrada'), findsWidgets);
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

    await _ignoreRenderOverflow(() async {
      await _pumpShell(tester, controller);
      await tester.pump();
    });

    expect(find.text('Persisted task'), findsOneWidget);
  });

  for (final entry in <AppSection, String>{
    AppSection.today: 'Hoy',
    AppSection.projects: 'Proyectos',
    AppSection.categories: 'Categorías',
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

  testWidgets('monthly calendar keeps crowded days inside their row', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final crowdedDay = DateTime(now.year, now.month, 14, 10);
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: List<TaskModel>.generate(
          3,
          (index) => TaskModel(
            id: 'calendar-task-$index',
            title: 'Tarea de calendario $index',
            scheduledAt: crowdedDay.add(Duration(hours: index)),
            manualOrder: index.toDouble(),
          ),
        ),
        categories: const [],
        projects: const [],
        notes: const [],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.calendar,
        todaySort: TodaySort.manual,
      ),
    );

    tester.view.physicalSize = const Size(2200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: CalendarPage(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.text('+1 más'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library shows and remembers consumption status tabs', (
    WidgetTester tester,
  ) async {
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryItems: [
          LibraryItem(
            id: 'in-progress-game',
            type: LibraryItemType.game,
            title: 'Control',
            status: LibraryItemStatus.inProgress,
            createdAt: DateTime(2026, 7, 20),
            updatedAt: DateTime(2026, 7, 22),
          ),
        ],
        libraryStatusView: LibraryItemStatus.inProgress,
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
        schemaVersion: 3,
      ),
    );

    _configureLargeSurface(tester);
    await _ignoreRenderOverflow(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTodoTheme(),
          home: Scaffold(body: LibraryPage(controller: controller)),
        ),
      );
      await tester.pump();
    });

    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.text('En curso'), findsWidgets);
    expect(find.text('Completados'), findsOneWidget);
    expect(find.text('Control'), findsWidgets);

    await tester.tap(find.text('Pendientes'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.libraryStatusView, LibraryItemStatus.pending);

    await tester.tap(find.text('Añadir a Biblioteca'));
    await tester.pump();
    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Pendiente'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('biblioteca mantiene el filtro de tipo al cambiar de estado', (
    WidgetTester tester,
  ) async {
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryItems: [
          LibraryItem(
            id: 'pending-game',
            type: LibraryItemType.game,
            title: 'Juego pendiente',
            status: LibraryItemStatus.pending,
            createdAt: DateTime(2026, 8, 20),
            updatedAt: DateTime(2026, 8, 20),
          ),
          LibraryItem(
            id: 'in-progress-game',
            type: LibraryItemType.game,
            title: 'Juego en curso',
            status: LibraryItemStatus.inProgress,
            createdAt: DateTime(2026, 8, 21),
            updatedAt: DateTime(2026, 8, 21),
          ),
          LibraryItem(
            id: 'in-progress-book',
            type: LibraryItemType.book,
            title: 'Libro en curso',
            status: LibraryItemStatus.inProgress,
            createdAt: DateTime(2026, 8, 22),
            updatedAt: DateTime(2026, 8, 22),
          ),
        ],
        libraryStatusView: LibraryItemStatus.pending,
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
        schemaVersion: 3,
      ),
    );

    _configureLargeSurface(tester);
    await _ignoreRenderOverflow(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTodoTheme(),
          home: Scaffold(body: LibraryPage(controller: controller)),
        ),
      );
      await tester.pump();
    });

    await tester.tap(find.text('Juegos').first);
    await tester.pump();
    expect(find.text('Juego pendiente'), findsOneWidget);

    await tester.tap(find.text('En curso').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.libraryStatusView, LibraryItemStatus.inProgress);
    expect(find.text('Juego en curso'), findsOneWidget);
    expect(find.text('Libro en curso'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el detalle de un propósito da protagonismo a la portada', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryGoals: [
          LibraryGoal(
            id: 'goal-prey',
            type: LibraryItemType.game,
            title: 'Prey',
            targetYear: now.year,
            platform: 'PC',
            releaseYear: 2017,
            format: 'Digital',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
        schemaVersion: 3,
      ),
    );

    _configureLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: LibraryPage(controller: controller)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Propósitos'));
    await tester.pump();
    await tester.tap(find.text('Prey').first);
    await tester.pumpAndSettle();

    final cover = find.byKey(
      const ValueKey('library-goal-detail-cover'),
    );
    expect(cover, findsOneWidget);
    expect(tester.getSize(cover), const Size(244, 416));
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly calendar opens today and navigates between weeks', (
    WidgetTester tester,
  ) async {
    final controller = TodoWorkspace.createForTest(
      snapshot: _snapshotForSection(AppSection.calendar),
    );
    final today = controller.logicalDate();
    final currentWeek = _weekLabelForTest(today);
    final nextWeek = _weekLabelForTest(today.add(const Duration(days: 7)));

    tester.view.physicalSize = const Size(2200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: CalendarPage(controller: controller)),
      ),
    );

    await tester.tap(find.text('14').first);
    await tester.pump();
    await tester.tap(find.text('Semana'));
    await tester.pump();

    expect(find.text(currentWeek), findsOneWidget);

    await tester.tap(find.byTooltip('Semana siguiente'));
    await tester.pump();
    expect(find.text(nextWeek), findsOneWidget);

    await tester.tap(find.byTooltip('Semana anterior'));
    await tester.pump();
    expect(find.text(currentWeek), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile navigation keeps extra sections under more', (
    WidgetTester tester,
  ) async {
    final controller = TodoWorkspace.createForTest();

    _configureMobileSurface(tester);

    await _ignoreRenderOverflow(() async {
      await _pumpShell(tester, controller);
      await tester.pumpAndSettle();
    });

    expect(find.text('Hoy'), findsWidgets);
    expect(find.text('Entrada'), findsWidgets);
    expect(find.text('Calendario'), findsWidgets);
    expect(find.text('Proyectos'), findsWidgets);
    expect(find.text('Más'), findsOneWidget);

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    expect(find.text('Ajustes'), findsWidgets);
    expect(find.text('Completadas'), findsWidgets);
  });

  test('controller imports json and can reset to empty state', () async {
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

    expect(controller.tasks, isEmpty);
    expect(controller.categories, isEmpty);
    expect(controller.projects, isEmpty);
    expect(controller.notes, isEmpty);
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

  test('controller records recurring completion and keeps reminder settings',
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

    final recurringTask = controller.taskById(task.id)!;
    final today = controller.logicalDate();

    expect(
      controller.tasks.where((item) => item.title == 'Recurring sample'),
      hasLength(1),
    );
    expect(recurringTask.status, TaskStatus.active);
    expect(controller.isTaskCompletedOnDay(recurringTask, today), isTrue);
    expect(
      recurringTask.reminderRule?.enabled,
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

void _configureLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(3600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _configureMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

String _weekLabelForTest(DateTime anchor) {
  final start = DateTime(anchor.year, anchor.month, anchor.day)
      .subtract(Duration(days: anchor.weekday - 1));
  final end = start.add(const Duration(days: 6));
  const months = <int, String>{
    1: 'enero',
    2: 'febrero',
    3: 'marzo',
    4: 'abril',
    5: 'mayo',
    6: 'junio',
    7: 'julio',
    8: 'agosto',
    9: 'septiembre',
    10: 'octubre',
    11: 'noviembre',
    12: 'diciembre',
  };
  return 'Semana del ${start.day} de ${months[start.month]} al '
      '${end.day} de ${months[end.month]}';
}
