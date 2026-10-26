import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  late TodoWorkspace controller;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => controller.dispose());

  Future<void> openLibrary(WidgetTester tester,
      {double? rating,
      LibraryItemType type = LibraryItemType.book,
      bool goals = false,
      LibraryItemStatus status = LibraryItemStatus.inProgress}) async {
    final now = DateTime.now();
    controller = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson({
      'libraryItems': [
        LibraryItem(
                id: 'libro-prueba',
                type: type,
                title: 'Una lectura de prueba',
                status: status,
                rating: rating,
                createdAt: now,
                updatedAt: now)
            .toJson()
      ],
      'libraryStatusView': status.name,
      'libraryAreaView': goals ? 'goals' : 'library',
      if (goals)
        'libraryGoals': [
          LibraryGoal(
                  id: 'proposito-prueba',
                  type: type,
                  title: 'Una lectura de prueba',
                  targetYear: now.year,
                  linkedLibraryItemId: 'libro-prueba',
                  createdAt: now,
                  updatedAt: now)
              .toJson()
        ],
    }));
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: LibraryPage(controller: controller))));
    await tester.pumpAndSettle();
  }

  Future<void> menuAction(WidgetTester tester, String action) async {
    await tester.tapAt(
        tester.getCenter(
            find.byKey(const ValueKey('library-cover-card-libro-prueba'))),
        buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  Finder ratingField() => find.descendant(
      of: find.byType(AlertDialog), matching: find.byType(TextField));

  testWidgets('el selector tiene el tamaño de la fila y abre el menú debajo',
      (tester) async {
    await openLibrary(tester);
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();

    final selector =
        find.byKey(const ValueKey('library-detail-status-selector'));
    final selectorRect = tester.getRect(selector);
    expect(selectorRect.width, lessThan(160));
    final statusText =
        find.descendant(of: selector, matching: find.text('En curso'));
    expect(tester.widget<Text>(statusText).style?.fontSize, 14);

    await tester.tap(selector);
    await tester.pumpAndSettle();
    final pending = find.widgetWithText(MenuItemButton, 'Pendiente');
    final menuRect = tester.getRect(pending);
    expect((menuRect.left - selectorRect.left).abs(), lessThanOrEqualTo(20));
    expect(menuRect.top, greaterThanOrEqualTo(selectorRect.bottom - 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('el estado se cambia desde la ficha sin abrir el editor',
      (tester) async {
    await openLibrary(tester, rating: 7.5);
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();

    final selector =
        find.byKey(const ValueKey('library-detail-status-selector'));
    expect(selector, findsOneWidget);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Pendiente'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.status, LibraryItemStatus.pending);
    expect(controller.libraryItems.single.completedDate, isNull);
    expect(selector, findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);

    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Completado'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
    expect(controller.libraryItems.single.completedDate, isNotNull);
    expect(find.text('Valorar libro'), findsNothing);
    expect(selector, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completar desde la ficha ofrece valorar el libro sin nota',
      (tester) async {
    await openLibrary(tester);
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('library-detail-status-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Completado'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
    expect(find.text('Valorar libro'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-detail-status-selector')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completar un libro sin nota pide y guarda la valoración decimal',
      (tester) async {
    await openLibrary(tester);
    await menuAction(tester, 'Marcar como completado');
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
    expect(find.text('Valorar libro'), findsOneWidget);
    await tester.enterText(ratingField(), '8,5');
    await tester.tap(find.text('Guardar valoración'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.rating, 8.5);
    expect(find.text('Valorar libro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('posponer la valoración conserva el libro completado',
      (tester) async {
    await openLibrary(tester);
    await menuAction(tester, 'Marcar como completado');
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
    expect(controller.libraryItems.single.completedDate, isNotNull);
    expect(controller.libraryItems.single.rating, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final rating in [0.0, 7.5]) {
    testWidgets('un libro con nota $rating no vuelve a pedir valoración',
        (tester) async {
      await openLibrary(tester, rating: rating);
      await menuAction(tester, 'Marcar como completado');
      expect(find.text('Valorar libro'), findsNothing);
      expect(
          controller.libraryItems.single.status, LibraryItemStatus.completed);
      expect(controller.libraryItems.single.rating, rating);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el aviso se limita a los libros', (tester) async {
    await openLibrary(tester, type: LibraryItemType.movieSeries);
    await menuAction(tester, 'Marcar como completado');
    expect(find.text('Valorar libro'), findsNothing);
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la nota debe estar entre cero y diez y admite punto',
      (tester) async {
    await openLibrary(tester);
    await menuAction(tester, 'Marcar como completado');
    for (final value in ['11', '-1', 'NaN', 'texto', '']) {
      await tester.enterText(ratingField(), value);
      await tester.tap(find.text('Guardar valoración'));
      await tester.pumpAndSettle();
      expect(find.text('Introduce una nota entre 0 y 10.'), findsOneWidget);
      expect(controller.libraryItems.single.rating, isNull);
    }
    await tester.enterText(ratingField(), '7.5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.rating, 7.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completar desde la ficha también solicita una nota',
      (tester) async {
    await openLibrary(tester);
    await menuAction(tester, 'Editar');
    final status = find.byType(DropdownButtonFormField<LibraryItemStatus>);
    await tester.ensureVisible(status);
    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completado').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Valorar libro'), findsOneWidget);
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editar un libro ya completado sin nota no repite el aviso',
      (tester) async {
    await openLibrary(tester, status: LibraryItemStatus.completed);
    await menuAction(tester, 'Editar');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Valorar libro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la nota escrita en la ficha evita un segundo diálogo',
      (tester) async {
    await openLibrary(tester);
    await menuAction(tester, 'Editar');
    final status = find.byType(DropdownButtonFormField<LibraryItemStatus>);
    await tester.ensureVisible(status);
    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completado').last);
    await tester.pumpAndSettle();
    final rating = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.hintText == 'Ej. 8,5');
    await tester.ensureVisible(rating);
    await tester.enterText(rating, '9');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Valorar libro'), findsNothing);
    expect(controller.libraryItems.single.rating, 9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guardar la valoración conserva otros cambios recientes',
      (tester) async {
    await openLibrary(tester);
    await menuAction(tester, 'Marcar como completado');
    controller.updateLibraryItem(controller.libraryItems.single.copyWith(
        note: 'Una nota añadida mientras se valora el libro.',
        reading: LibraryReading(
            progress: .85,
            observedAt: 1792843200,
            page: '850',
            totalPages: 1000,
            position: '/p[850]',
            documents: const [
              'libro-prueba'
            ],
            cursors: const {},
            quotes: const [
              {
                'id': 'cita',
                'text': 'Una cita que debe conservarse.',
                'observed_at': 1792843200
              }
            ])));
    await tester.enterText(ratingField(), '8');
    await tester.tap(find.text('Guardar valoración'));
    await tester.pumpAndSettle();
    final item = controller.libraryItems.single;
    expect(item.rating, 8);
    expect(item.note, 'Una nota añadida mientras se valora el libro.');
    expect(item.reading?.progress, .85);
    expect(
        item.reading?.quotes.single['text'], 'Una cita que debe conservarse.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('completar un propósito de lectura también solicita una nota',
      (tester) async {
    await openLibrary(tester, goals: true);
    await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded));
    await tester.pumpAndSettle();
    expect(controller.libraryGoals.single.isCompleted, isTrue);
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
    expect(find.text('Valorar libro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el editor de propósitos solicita la valoración al completar',
      (tester) async {
    await openLibrary(tester, goals: true);
    await tester.tap(find.text('Una lectura de prueba').first,
        buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    final completed = find.widgetWithText(SwitchListTile, 'Completado');
    await tester.ensureVisible(completed);
    await tester.tap(completed);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(controller.libraryGoals.single.isCompleted, isTrue);
    expect(find.text('Valorar libro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
