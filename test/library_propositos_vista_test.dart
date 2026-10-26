import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  testWidgets(
      'Propósitos muestra los años como botones, sin prioridad y con vista de portadas',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final anio = DateTime.now().year;
    final ahora = DateTime(anio, 1, 5);
    LibraryGoal propositoDe(String id, int year, LibraryItemType tipo) =>
        LibraryGoal(
          id: id,
          type: tipo,
          title: 'Propósito $id',
          targetYear: year,
          isFavorite: true,
          createdAt: ahora,
          updatedAt: ahora,
        );
    final controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot.fromJson({
        'libraryGoals': [
          propositoDe('a', anio, LibraryItemType.game).toJson(),
          propositoDe('b', anio, LibraryItemType.book).toJson(),
          propositoDe('c', anio + 1, LibraryItemType.movieSeries).toJson(),
        ],
      }),
    );
    addTearDown(controller.dispose);
    controller.setLibraryAreaView(LibraryAreaView.goals);
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: LibraryPage(controller: controller))));
    await tester.pumpAndSettle();

    // Años visibles uno al lado del otro, el actual a la izquierda del siguiente.
    final actual = find.byKey(ValueKey('library-year-$anio'));
    final siguiente = find.byKey(ValueKey('library-year-${anio + 1}'));
    expect(actual, findsOneWidget);
    expect(siguiente, findsOneWidget);
    expect(tester.getTopLeft(actual).dx,
        lessThan(tester.getTopLeft(siguiente).dx));
    expect(find.byTooltip('Cambiar año'), findsNothing);
    expect(find.text('Añadir propósito'), findsOneWidget);

    // Sin la marca de prioridad.
    expect(find.byIcon(Icons.star_border_rounded), findsNothing);
    expect(find.byTooltip('Marcar como prioritario'), findsNothing);

    // Vista de portadas de todos los propósitos.
    await tester.tap(find.byTooltip('Vista de portadas'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-goals-covers-grid')),
        findsOneWidget);
    expect(find.text('Todos los propósitos'), findsOneWidget);
    await tester.tap(find.byTooltip('Vista por columnas'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('library-goals-covers-grid')), findsNothing);

    // Cambiar de año.
    await tester.tap(siguiente);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });
}
