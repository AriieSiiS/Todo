import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        MaterialApp(theme: buildTodoTheme(), home: Scaffold(body: page)));
    await tester.pump();
  }

  testWidgets(
      'Biblioteca permite ampliar recientes y años y volver a resumirlos',
      (tester) async {
    final year = DateTime.now().year;
    final controller = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson({
      'libraryItems': [
        for (var i = 0; i < 5; i++)
          LibraryItem(
            id: 'libro-$i',
            type: LibraryItemType.book,
            title: 'Libro $i',
            completedDate: DateTime(year - i, 1, 1),
            createdAt: DateTime(year - i, 1, 1),
            updatedAt: DateTime(year - i, 1, 1),
          ).toJson()
      ],
    }));
    addTearDown(controller.dispose);
    await pumpPage(tester, LibraryPage(controller: controller));
    // El título también aparece en la portada de la cuadrícula principal, así
    // que se compara cuántas veces se muestra en lugar de exigir su ausencia.
    final apariciones = find.text('Libro 4').evaluate().length;
    await tester.tap(find.text('Ver todos los recientes'));
    await tester.pump();
    expect(find.text('Libro 4'), findsNWidgets(apariciones + 1));
    await tester.tap(find.text('Ver menos recientes'));
    await tester.pump();
    expect(find.text('Libro 4'), findsNWidgets(apariciones));
    expect(find.text('${year - 4}'), findsNothing);
    await tester.tap(find.text('Ver todos los años'));
    await tester.pump();
    expect(find.text('${year - 4}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Proyectos abre todas las próximas tareas, incluidas las que no caben en el resumen',
      (tester) async {
    final controller = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson({
      'projects': [
        const ProjectModel(
                id: 'proyecto',
                name: 'Proyecto',
                description: '',
                colorValue: 0xFF00AA00,
                icon: Icons.home)
            .toJson()
      ],
      'tasks': [
        for (var i = 0; i < 6; i++)
          TaskModel(
                  id: 'tarea-$i',
                  title: 'Pendiente $i',
                  projectIds: const ['proyecto'],
                  scheduledAt: DateTime(2030, 1, i + 1))
              .toJson()
      ],
    }));
    addTearDown(controller.dispose);
    await pumpPage(tester, ProjectsPage(controller: controller));
    await tester.tap(find.byKey(const ValueKey('project-upcoming-all')));
    await tester.pumpAndSettle();
    expect(find.text('Todas las próximas tareas'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('Pendiente 5')),
        findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Agenda amplía los vencimientos más allá de los seis iniciales',
      (tester) async {
    final now = DateTime.now();
    final controller = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson({
      'tasks': [
        for (var i = 0; i < 8; i++)
          TaskModel(
                  id: 'agenda-$i',
                  title: 'Agenda $i',
                  // Mañana, para que no dependa de la hora a la que se ejecuta.
                  scheduledAt:
                      DateTime(now.year, now.month, now.day + 1, 12, i))
              .toJson()
      ],
    }));
    addTearDown(controller.dispose);
    await pumpPage(tester, CalendarPage(controller: controller));
    await tester.tap(find.text('Agenda').first);
    await tester.pump();
    final link = find.text('Ver todos los próximos vencimientos (8)');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump();
    expect(find.text('Ver menos'), findsOneWidget);
    expect(find.text('Agenda 7'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
