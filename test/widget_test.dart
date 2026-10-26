import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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

  testWidgets('la captura con teclado guarda una nota sin cambiar de sección',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    controller.setSection(AppSection.projects);
    _configureLargeSurface(tester);
    await _pumpShell(tester, controller);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Título de la nota'),
        'Una idea rápida');
    await tester.tap(find.text('Guardar nota'));
    await tester.pumpAndSettle();
    expect(controller.inboxNotes().single.content, 'Una idea rápida');
    expect(controller.section, AppSection.projects);
  });

  testWidgets('renders today workspace', (WidgetTester tester) async {
    final controller = TodoWorkspace.createForTest();

    _configureLargeSurface(tester);

    await _ignoreRenderOverflow(() async {
      await _pumpShell(tester, controller);
      await tester.pump();
    });

    expect(find.text('Hoy'), findsWidgets);
    expect(find.textContaining('Notas'), findsWidgets);
  });

  testWidgets('settings only shows controls that are currently functional', (
    WidgetTester tester,
  ) async {
    final controller = TodoWorkspace.createForTest();

    _configureLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: SettingsPage(controller: controller)),
      ),
    );
    await tester.pump();

    // Todas las secciones de Ajustes arrancan plegadas.
    expect(find.text('Enviar prueba'), findsNothing);
    for (final titulo in [
      'Regla del día',
      'Notificaciones',
      'Ropa',
      'Copias de seguridad',
    ]) {
      await tester.ensureVisible(find.text(titulo));
      await tester.tap(find.text(titulo));
      await tester.pump();
    }

    expect(find.text('Regla del día'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Enviar prueba'), findsOneWidget);
    expect(find.text('Probar alarma importante'), findsOneWidget);
    expect(find.text('Ropa'), findsOneWidget);
    expect(find.text('Secciones y pestañas'), findsOneWidget);
    expect(find.text('Copias de seguridad'), findsOneWidget);
    expect(find.text('Crear copia ahora'), findsOneWidget);
    expect(find.text('Abrir carpeta'), findsOneWidget);
    expect(find.text('Consejos y atajos'), findsOneWidget);

    expect(find.text('Cuenta y nube'), findsNothing);
    expect(find.text('Calendario e integraciones'), findsNothing);
    expect(find.text('Horas de enfoque (no molestar)'), findsNothing);
    expect(find.text('Apariencia'), findsNothing);
    expect(find.text('Rutinas y comportamiento'), findsNothing);

    tester
        .widget<DropdownButtonFormField<int>>(
          find.descendant(
            of: find.byKey(const ValueKey('settings-day-end-hour')),
            matching: find.byType(DropdownButtonFormField<int>),
          ),
        )
        .onChanged!(4);
    await tester.pump();
    expect(controller.daySettings.dayEndsAtHour, 4);

    await tester.tap(find.byType(Switch).last);
    await tester.pump();
    expect(controller.wardrobeDisplaySettings.showUsageCount, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('la alarma importante muestra las tres decisiones',
      (WidgetTester tester) async {
    final controller = TodoWorkspace.createForTest();
    await controller.showImportantAlarmTest();
    _configureLargeSurface(tester);
    await _ignoreRenderOverflow(() async {
      await _pumpShell(tester, controller);
      await tester.pump();
    });

    expect(find.text('Prueba de alarma importante'), findsOneWidget);
    expect(find.byKey(const ValueKey('important-alarm-stop')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('important-alarm-snooze')), findsOneWidget);
    expect(find.byKey(const ValueKey('important-alarm-open-task')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('important-alarm-snooze')));
    await tester.pump();
    expect(find.text('Prueba de alarma importante'), findsNothing);
  });

  test('un snapshot antiguo ignora el campo visual retirado', () {
    final legacyJson = AppStateSnapshot(
      tasks: const [],
      categories: const [],
      projects: const [],
      notes: const [],
      daySettings: const DaySettings(),
      notificationSettings: const DeviceNotificationSettings(),
      calendarSettings: const CalendarIntegrationSettings(),
      section: AppSection.settings,
      todaySort: TodaySort.manual,
      schemaVersion: 7,
    ).toJson()
      ..['visualMode'] = 'phantom';

    final decoded = AppStateSnapshot.fromJson(legacyJson);

    expect(decoded.toJson(), isNot(contains('visualMode')));
  });

  test('legacy automatic notifications are disabled until configured', () {
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(
          notificationsEnabled: true,
          dayStartReminderEnabled: true,
          dayEndReminderEnabled: true,
        ),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.settings,
        todaySort: TodaySort.manual,
        schemaVersion: 3,
      ),
    );

    expect(controller.notificationSettings.notificationsEnabled, isFalse);
    expect(controller.notificationSettings.dayStartReminderEnabled, isFalse);
    expect(controller.notificationSettings.dayEndReminderEnabled, isFalse);
  });

  test(
      'las notas convertidas antiguas se recuperan y las nuevas no desaparecen',
      () {
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: [
          QuickNote(
            id: 'nota-recuperada',
            content: 'Idea importante\nCon más detalles',
            createdAt: DateTime(2026, 9, 6),
            status: NoteStatus.converted,
          ),
        ],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.inbox,
        todaySort: TodaySort.manual,
        schemaVersion: 4,
      ),
    );

    expect(controller.inboxNotes().single.id, 'nota-recuperada');
    controller.convertNoteToTask('nota-recuperada');
    expect(controller.inboxNotes().single.id, 'nota-recuperada');
    expect(controller.tasks.single.title, 'Idea importante');
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

  testWidgets('el editor de notas ofrece formato, emoji, categorías y fijado',
      (WidgetTester tester) async {
    final controller = TodoWorkspace.createForTest(
      snapshot: _snapshotForSection(AppSection.inbox),
    );
    _configureLargeSurface(tester);
    await _pumpShell(tester, controller);

    await tester.tap(find.text('Nueva nota'));
    await tester.pumpAndSettle();

    expect(find.text('Título de la nota'), findsOneWidget);
    expect(find.byTooltip('Elegir emoji'), findsOneWidget);
    expect(find.byTooltip('Fijar nota'), findsOneWidget);
    expect(find.byTooltip('Negrita'), findsOneWidget);
    expect(find.byTooltip('Cursiva'), findsOneWidget);
    expect(find.byTooltip('Estilo de texto'), findsOneWidget);
    expect(find.byTooltip('Lista de tareas'), findsOneWidget);
    expect(find.text('Añadir categoría'), findsOneWidget);
    expect(find.text('Añadir fecha'), findsNothing);
    expect(find.text('Guardar nota'), findsOneWidget);
  });

  testWidgets('el editor de notas permite escribir y guardar contenido',
      (WidgetTester tester) async {
    final controller = TodoWorkspace.createForTest(
      snapshot: _snapshotForSection(AppSection.inbox),
    );
    _configureLargeSurface(tester);
    await _pumpShell(tester, controller);

    await tester.tap(find.text('Nueva nota'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Título de la nota'),
      'Nota de prueba',
    );

    final editor = find.byKey(const ValueKey('editorContenidoNota'));
    expect(editor, findsOneWidget);
    await tester.tapAt(tester.getTopLeft(editor) + const Offset(40, 30));
    await tester.pump();
    tester.testTextInput.enterText('Contenido escrito desde el editor.');
    await tester.pump();

    await tester.tap(find.text('Guardar nota'));
    await tester.pumpAndSettle();

    expect(controller.notes, hasLength(1));
    expect(
      controller.notes.single.content,
      'Nota de prueba\nContenido escrito desde el editor.',
    );
  });

  testWidgets(
      'una plantilla de reunión crea una nota editable con su estructura',
      (tester) async {
    final controller = TodoWorkspace.createForTest();
    controller.setSection(AppSection.inbox);
    _configureLargeSurface(tester);
    await _pumpShell(tester, controller);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva nota'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Usar plantilla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reunión'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Título de la nota'),
        'Reunión del proyecto');
    await tester.tap(find.text('Guardar nota'));
    await tester.pumpAndSettle();
    expect(
        controller.notes.single.content, startsWith('Reunión del proyecto\n'));
    expect(controller.notes.single.content, contains('Participantes'));
    expect(controller.notes.single.content, contains('Próximos pasos'));
    expect(controller.notes.single.emoji, '📝');
  });

  testWidgets('Notas filtra por categoría y cambia de vista',
      (WidgetTester tester) async {
    const category = CategoryModel(
      id: 'producto',
      name: 'Producto',
      colorValue: 0xFF6D815A,
      icon: Icons.sell_outlined,
    );
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [category],
        projects: const [],
        notes: [
          QuickNote(
            id: 'idea-producto',
            content: 'Ideas para la app\nMejorar el editor de notas.',
            createdAt: DateTime(2026, 9, 6, 11, 20),
            categoryIds: const ['producto'],
          ),
          QuickNote(
            id: 'nota-personal',
            content: 'Lista de objetivos\nPreparar la semana.',
            createdAt: DateTime(2026, 9, 6, 10),
          ),
        ],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.inbox,
        todaySort: TodaySort.manual,
      ),
    );
    _configureLargeSurface(tester);
    await _pumpShell(tester, controller);
    await tester.pumpAndSettle();

    expect(find.textContaining('Las grandes ideas empiezan'), findsOneWidget);
    expect(find.byTooltip('Vista de lista'), findsOneWidget);
    expect(find.byTooltip('Vista de cuadrícula'), findsOneWidget);
    expect(find.text('Ideas para la app'), findsWidgets);
    expect(find.text('Lista de objetivos'), findsWidgets);

    await tester.tap(find.byTooltip('Filtrar por categoría'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Producto').last);
    await tester.pumpAndSettle();

    expect(find.text('Ideas para la app'), findsWidgets);
    expect(find.text('Lista de objetivos'), findsNothing);

    await tester.tap(find.byTooltip('Vista de cuadrícula'));
    await tester.pumpAndSettle();
    expect(find.text('Ideas para la app'), findsWidgets);
  });

  testWidgets('las notas separan título y contenido y ofrecen clic derecho',
      (WidgetTester tester) async {
    const title = 'Idea para revisar más adelante';
    const body = 'Este es el contenido completo de la nota.';
    const content = '$title\n$body';
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: [
          QuickNote(
            id: 'nota-contextual',
            content: content,
            createdAt: DateTime(2026, 9, 6),
          ),
        ],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.inbox,
        todaySort: TodaySort.manual,
      ),
    );
    _configureLargeSurface(tester);
    await _pumpShell(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text(content), findsNothing);
    final directEditor = tester.widget<AppFlowyEditor>(
      find.byKey(const ValueKey('contenidoNotaDirecto')),
    );
    expect(directEditor.editable, isTrue);
    await directEditor.editorState.insertText(
      body.length,
      ' Texto añadido.',
      path: const [0],
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      controller.noteById('nota-contextual')?.content,
      '$title\n$body Texto añadido.',
    );
    final note = find.text(title).first;

    await tester.tap(note, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Fijar nota'), findsOneWidget);
    expect(find.text('Editar nota'), findsWidgets);
    expect(find.text('Crear una tarea'), findsOneWidget);
    expect(find.text('Crear un proyecto'), findsOneWidget);
    expect(find.text('Crear un evento'), findsOneWidget);
    expect(find.text('Archivar'), findsWidgets);
    expect(find.text('Eliminar'), findsWidgets);

    await tester.tap(find.text('Fijar nota'));
    await tester.pumpAndSettle();
    expect(controller.noteById('nota-contextual')?.isPinned, isTrue);
    expect(find.text('Fijadas'), findsOneWidget);
  });

  testWidgets('editar una nota usa el panel derecho sin abrir un modal',
      (WidgetTester tester) async {
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: [
          QuickNote(
            id: 'nota-edicion-en-panel',
            content: 'Idea inicial\nContenido que debe conservarse.',
            createdAt: DateTime(2026, 9, 15),
          ),
        ],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.inbox,
        todaySort: TodaySort.manual,
      ),
    );
    _configureLargeSurface(tester);
    await _pumpShell(tester, controller);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Editar nota').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tituloNotaEnPanel')), findsOneWidget);
    expect(find.byKey(const ValueKey('contenidoNotaEnPanel')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('tituloNotaEnPanel')),
      'Idea editada',
    );
    await tester.tap(find.byKey(const ValueKey('guardarEdicionNota')));
    await tester.pumpAndSettle();

    expect(
      controller.noteById('nota-edicion-en-panel')?.content,
      'Idea editada\nContenido que debe conservarse.',
    );
    expect(find.byKey(const ValueKey('tituloNotaEnPanel')), findsNothing);
    expect(find.text('Idea editada'), findsWidgets);
  });

  for (final entry in <AppSection, String>{
    AppSection.today: 'Hoy',
    AppSection.projects: 'Proyectos',
    AppSection.inbox: 'Notas',
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

  testWidgets(
      'clic derecho en una portada muestra un solo menú con el elemento primero',
      (WidgetTester tester) async {
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryItems: [
          LibraryItem(
            id: 'juego-menu',
            type: LibraryItemType.game,
            title: 'Control',
            status: LibraryItemStatus.completed,
            createdAt: DateTime(2026, 7, 20),
            updatedAt: DateTime(2026, 7, 22),
          ),
        ],
        libraryStatusView: LibraryItemStatus.completed,
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
      await tester.tap(find.byTooltip('Vista de portadas'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.byKey(const ValueKey('library-cover-card-juego-menu')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    });

    final opcionValoracion = find.text('Cambiar/añadir valoración');
    final editar = find.text('Editar');
    final anadir = find.text('Añadir juego');
    expect(opcionValoracion, findsOneWidget);
    expect(editar, findsOneWidget);
    expect(find.text('Borrar'), findsOneWidget);
    expect(anadir, findsOneWidget);
    expect(
      tester.getTopLeft(opcionValoracion).dy,
      lessThan(tester.getTopLeft(anadir).dy),
    );

    await tester.tap(opcionValoracion);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final notas = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.focusNode?.hasFocus == true,
      ),
    );
    expect(notas.keyboardType,
        const TextInputType.numberWithOptions(decimal: true));
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
    expect(find.text('Todo'), findsOneWidget);
    expect(find.text('Control'), findsWidgets);

    expect(find.byTooltip('Vista de portadas'), findsOneWidget);
    await tester.tap(find.byTooltip('Vista de portadas'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('library-cover-card-in-progress-game')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('library-cover-type-in-progress-game')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Vista por columnas'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('library-cover-card-in-progress-game')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('library-cover-type-in-progress-game')),
      findsNothing,
    );

    final allLibrarySearch = find.byType(TextField).first;
    await tester.enterText(allLibrarySearch, 'sin coincidencias');
    await tester.pump(const Duration(milliseconds: 300));
    // El panel lateral conserva el resumen global aunque la cuadrícula no
    // tenga coincidencias para la búsqueda actual.
    expect(find.text('Control'), findsOneWidget);
    await tester.enterText(allLibrarySearch, 'control');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Control'), findsWidgets);
    await tester.enterText(allLibrarySearch, '');
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Pendientes'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.libraryStatusView, LibraryItemStatus.pending);

    await tester.tap(find.text('Todo'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.libraryStatusView, LibraryItemStatus.pending);
    expect(find.text('Control'), findsWidgets);
    expect(find.text('En curso'), findsWidgets);

    await tester.tap(find.text('Añadir a Biblioteca'));
    await tester.pump();
    expect(find.text('Estado'), findsOneWidget);
    expect(find.text('Pendiente'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Biblioteca abre en Todo y modo portadas por defecto', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryItems: [
          LibraryItem(
            id: 'default-library-completed',
            type: LibraryItemType.book,
            title: 'Libro terminado',
            status: LibraryItemStatus.completed,
            completedDate: now,
            createdAt: now,
            updatedAt: now,
          ),
          LibraryItem(
            id: 'default-library-pending',
            type: LibraryItemType.book,
            title: 'Libro pendiente',
            status: LibraryItemStatus.pending,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
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

    expect(find.text('Todo'), findsOneWidget);
    expect(find.byTooltip('Vista de portadas'), findsOneWidget);
    expect(
      find.byKey(
          const ValueKey('library-cover-card-default-library-completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('library-cover-card-default-library-pending')),
      findsOneWidget,
    );
  });

  testWidgets('library restores and updates its internal tab', (
    WidgetTester tester,
  ) async {
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryAreaView: LibraryAreaView.goals,
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
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

    expect(find.text('Añadir propósito'), findsOneWidget);
    await tester.tap(find.text('Biblioteca').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.libraryAreaView, LibraryAreaView.library);
    expect(find.text('Añadir a Biblioteca'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library remembers the type selected in each area', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryItems: [
          LibraryItem(
            id: 'library-game',
            type: LibraryItemType.game,
            title: 'Juego de biblioteca',
            status: LibraryItemStatus.completed,
            completedDate: now,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        libraryGoals: [
          LibraryGoal(
            id: 'book-goal',
            type: LibraryItemType.book,
            title: 'Libro de propósito',
            targetYear: now.year,
            createdAt: now,
            updatedAt: now,
          ),
          LibraryGoal(
            id: 'game-goal',
            type: LibraryItemType.game,
            title: 'Juego de propósito',
            targetYear: now.year,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
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
      await tester.tap(find.text('Propósitos'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Libros').first);
      await tester.pump(const Duration(milliseconds: 300));
    });

    expect(find.text('Libro de propósito'), findsOneWidget);
    expect(find.text('Juego de propósito'), findsNothing);

    await tester.tap(find.text('Biblioteca').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Juegos').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Juego de biblioteca'), findsWidgets);
    final completedLibraryCard = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('library-cover-card-library-game')),
    );
    final completedLibraryDecoration =
        completedLibraryCard.foregroundDecoration! as BoxDecoration;
    expect(completedLibraryDecoration.border, isNotNull);

    await tester.tap(find.text('Propósitos'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Libro de propósito'), findsOneWidget);
    expect(find.text('Juego de propósito'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library editor exposes rating and notes for completed items', (
    WidgetTester tester,
  ) async {
    final controller = TodoWorkspace.createForTest(
      snapshot: _snapshotForSection(AppSection.library),
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
      await tester.tap(find.text('Añadir a Biblioteca'));
      await tester.pump();
    });

    expect(find.text('Valoración opcional'), findsOneWidget);
    expect(find.text('Notas opcionales'), findsOneWidget);
    expect(find.text('Saga / colección'), findsOneWidget);
    expect(find.text('Número de entrega'), findsOneWidget);
    expect(find.text('Mostrar etiquetas'), findsOneWidget);
    expect(find.text('Añadir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Biblioteca muestra colecciones aunque tengan una sola entrega', (
    WidgetTester tester,
  ) async {
    final date = DateTime(2026, 9, 6);
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryItems: [
          LibraryItem(
            id: 'carl-1',
            type: LibraryItemType.book,
            title: 'Carl el mazmorrero',
            status: LibraryItemStatus.pending,
            collectionName: 'Carl el mazmorrero',
            collectionNumber: 1,
            createdAt: date,
            updatedAt: date,
          ),
          LibraryItem(
            id: 'carl-2',
            type: LibraryItemType.book,
            title: 'El juicio final de Carl',
            status: LibraryItemStatus.pending,
            collectionName: 'Carl el mazmorrero',
            collectionNumber: 2,
            createdAt: date,
            updatedAt: date,
          ),
          LibraryItem(
            id: 'unico',
            type: LibraryItemType.book,
            title: 'Entrega única',
            status: LibraryItemStatus.pending,
            collectionName: 'Otra saga',
            collectionNumber: 1,
            createdAt: date,
            updatedAt: date,
          ),
          LibraryItem(
            id: 'forzado',
            type: LibraryItemType.game,
            title: 'Prólogo jugable',
            status: LibraryItemStatus.pending,
            collectionName: 'Saga futura',
            collectionNumber: 1,
            showCollectionNumber: true,
            createdAt: date,
            updatedAt: date,
          ),
        ],
        libraryStatusView: LibraryItemStatus.pending,
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
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

    expect(find.text('Carl el mazmorrero'), findsNWidgets(4));
    expect(find.text('#1'), findsNWidgets(2));
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('Entrega única'), findsNWidgets(2));
    expect(find.text('Otra saga'), findsOneWidget);
    expect(find.text('futura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library context menu completes a pending item quickly', (
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
            id: 'quick-complete-item',
            type: LibraryItemType.movieSeries,
            title: 'Serie terminada',
            status: LibraryItemStatus.pending,
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        ],
        libraryStatusView: LibraryItemStatus.pending,
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
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
      await tester.tap(
        find.text('Serie terminada').first,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
    });

    expect(find.text('Marcar como completado'), findsOneWidget);
    await tester.tap(find.text('Marcar como completado'));
    await tester.pump();
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
    expect(controller.libraryItems.single.completedDate, isNotNull);
    expect(find.text('Deshacer'), findsOneWidget);

    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.libraryItems.single.status, LibraryItemStatus.pending);
    expect(tester.takeException(), isNull);
  });

  testWidgets('purpose editor shows fields for the selected content type', (
    WidgetTester tester,
  ) async {
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot(
        tasks: const [],
        categories: const [],
        projects: const [],
        notes: const [],
        libraryAreaView: LibraryAreaView.goals,
        daySettings: const DaySettings(),
        notificationSettings: const DeviceNotificationSettings(),
        calendarSettings: const CalendarIntegrationSettings(),
        section: AppSection.library,
        todaySort: TodaySort.manual,
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
      await tester.tap(find.text('Añadir propósito'));
      await tester.pump();
      await tester.tap(find.text('Película / Serie / Anime'));
      await tester.pump();
    });

    expect(find.text('Año de estreno'), findsOneWidget);
    expect(find.text('Director / Creador'), findsOneWidget);
    expect(find.text('País de origen'), findsOneWidget);
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
    expect(find.text('Juego pendiente'), findsNWidgets(2));

    await tester.tap(find.text('En curso').first);
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.libraryStatusView, LibraryItemStatus.inProgress);
    expect(find.text('Juego en curso'), findsNWidgets(2));
    expect(find.text('Libro en curso'), findsOneWidget);
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
            status: LibraryGoalStatus.completed,
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
    await tester.tap(find.text('Juegos').first);
    await tester.pump();

    final completedCardFinder =
        find.byKey(const ValueKey('library-goal-card-goal-prey'));
    final completedCard = tester.widget<AnimatedContainer>(completedCardFinder);
    final completedDecoration =
        completedCard.foregroundDecoration! as BoxDecoration;
    expect(completedDecoration.border, isNotNull);

    tester
        .widget<InkWell>(
          find
              .ancestor(
                of: completedCardFinder,
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!();
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
    expect(find.text('Notas'), findsWidgets);
    expect(find.text('Calendario'), findsWidgets);
    expect(find.text('Proyectos'), findsWidgets);
    expect(find.text('Más'), findsOneWidget);

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();

    expect(find.text('Ajustes'), findsWidgets);
    expect(find.text('Completadas'), findsWidgets);
  });

  test('el controlador importa JSON y restablece el estado inicial', () async {
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
    expect(controller.categories.where((item) => item.name == 'Plantas'),
        hasLength(1));
    expect(controller.plants, isEmpty);
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
      notes: [
        QuickNote(
          id: 'rich-note',
          content: 'Idea\n**Texto importante**',
          createdAt: DateTime(2026, 9, 6),
          emoji: '💡',
          colorValue: 0xFFBFD8B8,
          isPinned: true,
          updatedAt: DateTime(2026, 9, 6, 12),
          categoryIds: const ['producto', 'ideas'],
        ),
      ],
      daySettings: const DaySettings(dayEndsAtHour: 4),
      notificationSettings: const DeviceNotificationSettings(
        defaultMinutesBeforeTask: 20,
      ),
      calendarSettings: const CalendarIntegrationSettings(
        selectedCalendarId: 'primary',
      ),
      section: AppSection.calendar,
      todaySort: TodaySort.priority,
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
          'updatedAt',
          'schemaVersion',
          'lastModifiedBy',
        ]));
    expect(decoded.tasks.single.title, 'JSON task');
    expect(decoded.section, AppSection.calendar);
    expect(decoded.todaySort, TodaySort.priority);
    expect(json, isNot(contains('visualMode')));
    expect(decoded.lastModifiedBy, 'test@example.com');
    expect(decoded.notes.single.emoji, '💡');
    expect(decoded.notes.single.colorValue, 0xFFBFD8B8);
    expect(decoded.notes.single.isPinned, isTrue);
    expect(decoded.notes.single.effectiveUpdatedAt.hour, 12);
    expect(decoded.notes.single.categoryIds, ['producto', 'ideas']);
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
      reminderRules: const <ReminderRule>[
        ReminderRule(enabled: true, minutesBefore: 15),
      ],
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
      recurringTask.reminderRules.any((rule) => rule.enabled),
      isTrue,
    );
  });

  test('controller accumulates reminders and removes only the selected one',
      () {
    final controller = TodoWorkspace.createForTest();
    final task = controller.createTask(
      title: 'Fisio',
      scheduledAt: DateTime(2026, 9, 14, 18, 55),
    );
    const exact = ReminderRule(enabled: true, minutesBefore: 0);
    const fiveMinutes = ReminderRule(enabled: true, minutesBefore: 5);

    controller.setTaskReminder(task.id, exact);
    controller.setTaskReminder(task.id, fiveMinutes);
    controller.setTaskReminder(task.id, fiveMinutes);

    expect(
      controller
          .taskById(task.id)!
          .reminderRules
          .map((rule) => rule.minutesBefore),
      <int>[0, 5],
    );

    controller.clearTaskReminder(task.id, reminder: fiveMinutes);

    expect(
      controller
          .taskById(task.id)!
          .reminderRules
          .map((rule) => rule.minutesBefore),
      <int>[0],
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
