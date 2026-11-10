import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shared/book_reading_panel.dart';
import 'package:todo/presentation/shared/library_quotes_dialog.dart';
import 'package:todo/presentation/shell/app_shell.dart';

void main() {
  late TodoWorkspace controller;
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final now = DateTime(2026, 10, 24);
    controller = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson({
      'libraryItems': [
        LibraryItem(
            id: 'libro-prueba',
            type: LibraryItemType.book,
            title: 'Libro de prueba',
            author: 'Autora de prueba',
            pages: '1088',
            collectionName: 'Saga de prueba',
            status: LibraryItemStatus.inProgress,
            rating: 4.5,
            createdAt: now,
            updatedAt: now,
            reading: LibraryReading(
                progress: .01,
                observedAt: 1792843200,
                page: '20',
                totalPages: 1955,
                pageUnit: 'screen',
                position: '/p[20]',
                documents: [
                  'libro'
                ],
                cursors: {},
                quotes: [
                  {
                    'id': 'cita',
                    'text': 'Una frase que merece ser recordada.',
                    'note': 'Recordar esta idea.',
                    'page': '9',
                    'chapter': 'Introducción',
                    'anchor': '/posicion-tecnica',
                    'created_at': '2026-10-24 15:08:22'
                  }
                ])).toJson()
      ]
    }));
  });
  tearDown(() => controller.dispose());

  Future<void> openLibrary(WidgetTester tester,
      {Size size = const Size(1440, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: LibraryPage(controller: controller))));
    await tester.pumpAndSettle();
  }

  for (final caso in [
    (LibraryItemType.book, null, 'Libro pendiente'),
    (LibraryItemType.game, null, 'Juego pendiente'),
    (LibraryItemType.movieSeries, LibraryMediaType.series, 'Serie pendiente'),
    (LibraryItemType.movieSeries, LibraryMediaType.movie, 'Película pendiente'),
  ]) {
    for (final columnas in [false, true]) {
      testWidgets(
          'inicio rápido de ${caso.$3} en ${columnas ? 'columnas' : 'portadas'}',
          (tester) async {
        final item = controller.createLibraryItem(
          type: caso.$1,
          mediaType: caso.$2,
          title: caso.$3,
          status: LibraryItemStatus.pending,
        );
        controller.setLibraryTypeView(columnas ? null : caso.$1);
        await openLibrary(tester);
        await tester.tap(find.text('Todo'));
        await tester.pumpAndSettle();
        if (columnas) {
          await tester.tap(find.byTooltip('Vista por columnas'));
          await tester.pumpAndSettle();
        }
        final target = columnas
            ? find.text(item.title).first
            : find.byKey(ValueKey('library-cover-card-${item.id}'));
        await tester.tapAt(tester.getCenter(target),
            buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        final pelicula = caso.$2 == LibraryMediaType.movie;
        if (pelicula) {
          expect(find.text('Marcar como en curso'), findsNothing);
          await tester.tap(find.text('Marcar como completado'));
        } else {
          expect(find.text('Marcar como completado'), findsNothing);
          await tester.tap(find.text('Marcar como en curso'));
        }
        await tester.pumpAndSettle();
        final updated =
            controller.libraryItems.firstWhere((i) => i.id == item.id);
        expect(
            updated.status,
            pelicula
                ? LibraryItemStatus.completed
                : LibraryItemStatus.inProgress);
        if (!pelicula) {
          expect(updated.completedDate, isNull);
          expect(find.byType(AlertDialog), findsNothing);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('un libro pendiente también se inicia desde Recientes',
      (tester) async {
    final item = controller.createLibraryItem(
      type: LibraryItemType.book,
      title: 'Libro reciente pendiente',
      status: LibraryItemStatus.pending,
    );
    await openLibrary(tester);
    await tester.tapAt(tester.getCenter(find.text(item.title).last),
        buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Marcar como completado'), findsNothing);
    await tester.tap(find.text('Marcar como en curso'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.firstWhere((i) => i.id == item.id).status,
        LibraryItemStatus.inProgress);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'completar oculta el porcentaje en Recientes y deshacer recupera el avance',
      (tester) async {
    final original = controller.libraryItems.single;
    controller.updateLibraryItem(
        original.copyWith(
            reading: LibraryReading.fromJson({
          ...original.reading!.toJson(),
          'progress': .98,
        })),
        replaceReading: true);
    await openLibrary(tester);
    final card = find.byKey(const ValueKey('library-cover-card-libro-prueba'));
    await tester.tapAt(tester.getCenter(card), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar como completado'));
    await tester.pumpAndSettle();
    await openLibrary(tester);
    expect(find.textContaining('100 % ·'), findsNothing);
    await tester.tapAt(tester.getCenter(card));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    await openLibrary(tester);
    expect(find.textContaining('98 % ·'), findsOneWidget);
    expect(controller.libraryItems.single.reading!.quotes,
        original.reading!.quotes);
  });

  testWidgets('el aviso de completar caduca y permite deshacer antes',
      (tester) async {
    await openLibrary(tester);
    final card = find.byKey(const ValueKey('library-cover-card-libro-prueba'));
    Future<void> completar() async {
      await tester.tapAt(tester.getCenter(card),
          buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar como completado'));
      await tester.pumpAndSettle();
    }

    await completar();
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
    expect(find.text('Deshacer'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Deshacer'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.status, LibraryItemStatus.inProgress);
    expect(find.byType(SnackBar), findsNothing);

    await completar();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(controller.libraryItems.single.status, LibraryItemStatus.completed);
  });

  testWidgets('los avisos de progreso se sustituyen y caducan sin reaparecer',
      (tester) async {
    final serie = controller.createLibraryItem(
      type: LibraryItemType.movieSeries,
      title: 'Serie de avisos',
      mediaType: LibraryMediaType.series,
      status: LibraryItemStatus.inProgress,
      progressCurrent: 1,
      progressTotal: 12,
    );
    await openLibrary(tester);
    final card = find.byKey(ValueKey('library-cover-card-${serie.id}'));
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(tester.getCenter(card),
          buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar episodio visto'));
      await tester.pumpAndSettle();
      await openLibrary(tester);
    }
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
        controller.libraryItems
            .firstWhere((i) => i.id == serie.id)
            .progressCurrent,
        4);
    expect(
        find.descendant(
            of: find.byType(SnackBar),
            matching: find.textContaining('4 / 12 episodios')),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('borrar una cita pide confirmación y actualiza la pestaña',
      (tester) async {
    await openLibrary(tester);
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Citas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Borrar cita'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.reading!.quotes, hasLength(1));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.reading!.quotes, hasLength(1));
    await tester.tap(find.byTooltip('Borrar cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.reading!.quotes, isEmpty);
    expect(find.text('Todavía no hay citas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'un libro en curso muestra la franja de progreso en vez de la insignia',
      (tester) async {
    await openLibrary(tester);
    final card = find.byKey(const ValueKey('library-cover-card-libro-prueba'));
    final strip =
        find.byKey(const ValueKey('library-cover-progress-libro-prueba'));
    expect(strip, findsOneWidget);
    expect(find.descendant(of: card, matching: find.byType(BookReadingBadge)),
        findsNothing);
    expect(
        find.descendant(of: strip, matching: find.text('20 / 1955 pantallas')),
        findsOneWidget);
    expect(
        find.descendant(of: strip, matching: find.text('1 %')), findsOneWidget);
    // Sin círculo de porcentaje ni botón ⋯: el tipo va arriba a la izquierda.
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    expect(find.byKey(const ValueKey('library-cover-type-libro-prueba')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('una serie pendiente muestra la franja al marcar un episodio',
      (tester) async {
    final serie = controller.createLibraryItem(
      type: LibraryItemType.movieSeries,
      title: 'Serie pendiente',
      mediaType: LibraryMediaType.series,
      status: LibraryItemStatus.pending,
      progressTotal: 12,
    );
    await openLibrary(tester);
    await tester.tap(find.text('Todo'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(ValueKey('library-cover-card-${serie.id}')), findsOneWidget);
    final franja = find.byKey(ValueKey('library-cover-progress-${serie.id}'));
    expect(franja, findsNothing);
    controller.marcarUnidadDeProgreso(serie.id);
    await tester.pump(const Duration(seconds: 2));
    // La página de prueba no escucha al controlador: se vuelve a pintar.
    await openLibrary(tester);
    expect(franja, findsOneWidget);
    expect(find.descendant(of: franja, matching: find.text('1 / 12 episodios')),
        findsOneWidget);
    expect(controller.libraryItems.firstWhere((i) => i.id == serie.id).status,
        LibraryItemStatus.pending);
    expect(tester.takeException(), isNull);
  });
  testWidgets('una serie en curso muestra su franja y se marca desde el menú',
      (tester) async {
    final now = DateTime(2026, 10, 24);
    controller.createLibraryItem(
      type: LibraryItemType.movieSeries,
      title: 'Serie de prueba',
      mediaType: LibraryMediaType.series,
      status: LibraryItemStatus.inProgress,
      progressSeason: 1,
      progressCurrent: 3,
      progressTotal: 9,
    );
    expect(now.year, 2026);
    await openLibrary(tester);
    final id = controller.libraryItems
        .firstWhere((item) => item.title == 'Serie de prueba')
        .id;
    final strip = find.byKey(ValueKey('library-cover-progress-$id'));
    expect(strip, findsOneWidget);
    expect(
        find.descendant(of: strip, matching: find.text('T1 · 3 / 9 episodios')),
        findsOneWidget);
    await tester.tapAt(
        tester.getCenter(find.byKey(ValueKey('library-cover-card-$id'))),
        buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marcar episodio visto'));
    await tester.pumpAndSettle();
    expect(
        controller.libraryItems
            .firstWhere((item) => item.id == id)
            .progressCurrent,
        4);
    expect(find.text('Marcado: T1 · 4 / 9 episodios'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    // La pulsación larga abre el mismo menú que el clic derecho.
    await tester.longPress(find.byKey(ValueKey('library-cover-card-$id')));
    await tester.pumpAndSettle();
    expect(find.text('Marcar episodio visto'), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(
        controller.libraryItems
            .firstWhere((item) => item.id == id)
            .progressCurrent,
        3);
    expect(tester.takeException(), isNull);
  });
  testWidgets('el resumen anual de lectura solo se ofrece en Libros',
      (tester) async {
    controller.setLibraryTypeView(LibraryItemType.game);
    await openLibrary(tester);
    expect(find.byTooltip('Estadísticas de lectura'), findsNothing);
    expect(find.byTooltip('Citas de todos los libros'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets(
      'las citas completas caben en una ventana estrecha en modo oscuro',
      (tester) async {
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final text =
        List.filled(30, 'Un pasaje largo que quiero conservar.').join(' ');
    final book = controller.libraryItems.single;
    final reading = LibraryReading(
      progress: 0,
      observedAt: 1,
      page: '',
      position: '',
      documents: [],
      cursors: {},
      quotes: [
        {'id': 'larga', 'text': text, 'note': 'También la nota completa.'}
      ],
    );
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
          body: LibraryQuotesDialog(
        books: [book.copyWith(reading: reading)],
      )),
    ));
    await tester.pumpAndSettle();
    final quote = tester.widget<SelectableText>(find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == text));
    expect(quote.maxLines, isNull);
    expect(quote.data, text);
    await tester.ensureVisible(find.text('Nota: También la nota completa.'));
    await tester.pumpAndSettle();
    expect(find.text('Nota: También la nota completa.').hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('la colección sin citas muestra un estado vacío', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LibraryQuotesDialog(books: const [])),
    ));
    expect(find.text('Todavía no hay citas en tus libros'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'las citas globales permiten editar y borrar en el libro correcto',
      (tester) async {
    final original = controller.libraryItems.single;
    final other = controller.createLibraryItem(
      type: LibraryItemType.book,
      title: 'Otro libro',
    );
    controller.updateLibraryItem(other.copyWith(reading: original.reading));
    controller.setLibraryTypeView(LibraryItemType.book);
    await openLibrary(tester);
    await tester.tap(find.byTooltip('Citas de todos los libros'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar citas, libros o autores'),
      'Libro de prueba',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar cita'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('book-quote-text-editor')),
        'Cita corregida desde la colección.');
    await tester.enterText(find.widgetWithText(TextField, 'Nota personal'),
        'Mi interpretación personal.');
    await tester.tap(find.text('Guardar cita'));
    await tester.pumpAndSettle();
    final edited =
        controller.libraryItems.firstWhere((b) => b.id == original.id);
    expect(edited.reading!.quotes.single['text'],
        'Cita corregida desde la colección.');
    expect(edited.reading!.quotes.single['anchor'], '/posicion-tecnica');
    expect(edited.reading!.progress, original.reading!.progress);
    final note = tester.widget<SelectableText>(find.byWidgetPredicate(
      (w) =>
          w is SelectableText && w.data == 'Nota: Mi interpretación personal.',
    ));
    expect(note.style?.fontStyle, FontStyle.italic);
    await tester.tap(find.byTooltip('Borrar cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Cita corregida desde la colección.'), findsOneWidget);
    await tester.tap(find.byTooltip('Borrar cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
    await tester.pumpAndSettle();
    final saved =
        controller.libraryItems.firstWhere((b) => b.id == original.id);
    expect(saved.reading!.quotes, isEmpty);
    expect(saved.reading!.deletedQuoteIds, contains('cita'));
    expect(
        controller.libraryItems
            .firstWhere((b) => b.id == other.id)
            .reading!
            .toJson(),
        original.reading!.toJson());
    expect(find.text('No hay citas que coincidan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'las citas globales reúnen todos los libros sin filtrar por estado',
      (tester) async {
    final terminado = controller.createLibraryItem(
      type: LibraryItemType.book,
      title: 'Libro terminado',
      author: 'Otra autora',
      completedDate: DateTime(2025, 3, 2),
    );
    controller.updateLibraryItem(terminado.copyWith(
      reading: LibraryReading(
        progress: 1,
        observedAt: 1,
        page: '80',
        position: '',
        documents: [],
        cursors: {},
        quotes: [
          {
            'id': 'otra',
            'text': 'También recuerdo lo que ya terminé.',
            'note': 'Una reflexión especial',
            'page': '30'
          }
        ],
      ),
    ));
    final pendiente = controller.createLibraryItem(
      type: LibraryItemType.book,
      title: 'Libro pendiente',
      status: LibraryItemStatus.pending,
    );
    final lectura = LibraryReading(
      progress: 0,
      observedAt: 1,
      page: '',
      position: '',
      documents: [],
      cursors: {},
      quotes: [
        {'id': 'pendiente', 'text': 'Un pasaje por descubrir.'}
      ],
    );
    controller.updateLibraryItem(pendiente.copyWith(reading: lectura));
    final juego = controller.createLibraryItem(
      type: LibraryItemType.game,
      title: 'Juego con datos ajenos',
    );
    controller.updateLibraryItem(juego.copyWith(reading: lectura));
    controller.setLibraryTypeView(LibraryItemType.book);
    controller.setLibraryStatusView(LibraryItemStatus.pending);
    await openLibrary(tester);
    await tester.tap(find.byTooltip('Citas de todos los libros'));
    await tester.pumpAndSettle();
    expect(find.text('Citas de tus libros'), findsOneWidget);
    expect(find.text('Una frase que merece ser recordada.'), findsOneWidget);
    expect(find.text('También recuerdo lo que ya terminé.'), findsOneWidget);
    expect(find.text('Un pasaje por descubrir.'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(LibraryQuotesDialog),
            matching: find.text('Juego con datos ajenos')),
        findsNothing);
    expect(find.text('Autora de prueba'), findsOneWidget);
    expect(find.textContaining('/posicion-tecnica'), findsNothing);

    final search =
        find.widgetWithText(TextField, 'Buscar citas, libros o autores');
    await tester.enterText(search, 'REFLEXION');
    await tester.pumpAndSettle();
    expect(find.text('También recuerdo lo que ya terminé.'), findsOneWidget);
    expect(find.text('Una frase que merece ser recordada.'), findsNothing);
    await tester.enterText(search, 'no existe');
    await tester.pumpAndSettle();
    expect(find.text('No hay citas que coincidan'), findsOneWidget);
    await tester.enterText(search, '');
    controller.updateBookQuote('libro-prueba', 'cita',
        text: 'La misma cita actualizada desde su libro.',
        note: 'Nota nueva',
        page: '9',
        chapter: 'Introducción');
    await tester.pumpAndSettle();
    expect(
        find.text('La misma cita actualizada desde su libro.'), findsOneWidget);
    expect(find.text('Una frase que merece ser recordada.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cerrar citas'));
    await tester.pumpAndSettle();
    expect(find.text('Citas de tus libros'), findsNothing);
  });
  testWidgets(
      'la tercera pestaña respeta la cabecera y el resumen anual es accesible',
      (tester) async {
    controller.setLibraryTypeView(LibraryItemType.book);
    await openLibrary(tester);
    expect(find.byTooltip('Estadísticas de lectura'), findsOneWidget);
    await tester.tap(find.byTooltip('Estadísticas de lectura'));
    await tester.pumpAndSettle();
    expect(find.text('Tu año de lectura'), findsOneWidget);
    expect(find.text('Libros terminados'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'El resumen anual debe caber sin desbordamientos');
    await tester.tap(find.byTooltip('Cerrar estadísticas'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, 'Estadísticas'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'Las tres pestañas deben caber en la cabecera');
    final informationHeader =
        tester.getTopLeft(find.text('Libro de prueba').last);
    await tester.tap(find.widgetWithText(Tab, 'Estadísticas'));
    await tester.pumpAndSettle();
    expect(find.text('Tiempo leído'), findsOneWidget);
    expect(find.text('Tu próxima lectura empieza aquí'), findsNothing);
    expect(tester.getTopLeft(find.text('Libro de prueba').last),
        informationHeader);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'las citas tienen pestaña propia y no muestran fechas ni posiciones técnicas',
      (tester) async {
    await openLibrary(tester);
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, 'Citas'), findsOneWidget);
    expect(find.textContaining('Pantalla 20 de 1955'), findsOneWidget);
    expect(find.text('Progreso'), findsOneWidget);
    expect(find.text('Información'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(SingleChildScrollView)),
        findsNothing);
    expect(find.text('Una frase que merece ser recordada.'), findsNothing);
    await tester.tap(find.widgetWithText(Tab, 'Citas'));
    await tester.pumpAndSettle();
    expect(find.text('1 cita guardada'), findsNothing);
    expect(
        find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(SingleChildScrollView)),
        findsNothing);
    expect(find.text('Una frase que merece ser recordada.'), findsOneWidget);
    expect(find.text('Página 9'), findsOneWidget);
    expect(find.text('Introducción'), findsOneWidget);
    expect(find.textContaining('Recordar esta idea.'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(Dialog), matching: find.textContaining('2026')),
        findsNothing);
    expect(find.text('/posicion-tecnica'), findsNothing);
    expect(find.text('Ver posición en el libro'), findsNothing);
    await tester.tap(find.widgetWithText(Tab, 'Información'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pantalla 20 de 1955'), findsOneWidget);
    expect(find.text('Una frase que merece ser recordada.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('los datos de la ficha se ordenan en una sola columna sin scroll',
      (tester) async {
    await openLibrary(tester);
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();

    final author = tester.getTopLeft(find.text('Autor'));
    final status = tester.getTopLeft(find.text('Estado'));
    final collection = tester.getTopLeft(find.text('Saga / colección'));
    expect(status.dx, closeTo(author.dx, 1));
    expect(collection.dx, closeTo(author.dx, 1));
    expect(author.dy, lessThan(status.dy));
    expect(status.dy, lessThan(collection.dy));
    expect(
        find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(SingleChildScrollView)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'las pestañas comparten cabecera y la portada contiene el progreso',
      (tester) async {
    await openLibrary(tester);
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();
    final dialog = find.byType(Dialog);
    final tabs = find.descendant(of: dialog, matching: find.byType(TabBar));
    final title =
        find.descendant(of: dialog, matching: find.text('Libro de prueba'));
    final cover = find.byKey(const ValueKey('library-item-detail-cover'));
    final badge =
        find.descendant(of: cover, matching: find.byType(BookReadingBadge));
    expect(find.descendant(of: dialog, matching: find.text('Libro')),
        findsNothing);
    expect(tester.getRect(tabs).center.dy,
        lessThan(tester.getRect(title).bottom + 20));
    expect(badge, findsOneWidget);
    final coverRect = tester.getRect(cover);
    final badgeRect = tester.getRect(badge);
    expect(coverRect.contains(badgeRect.topLeft), isTrue);
    expect(coverRect.contains(badgeRect.bottomRight), isTrue);
    expect(badgeRect.left, greaterThan(coverRect.center.dx));
    expect(
        find.descendant(of: badge, matching: find.text('1%')), findsOneWidget);
    expect(find.textContaining('Pantalla 20 de 1955'), findsOneWidget);
    expect(find.textContaining('Pantalla 20 de 1955'), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(badge));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Pantalla 20 de 1955'), findsWidgets);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Editar en Información ajusta la página y recalcula el porcentaje',
      (tester) async {
    await openLibrary(tester);
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Editar'));
    await tester.pumpAndSettle();
    final page = find.byKey(const ValueKey('library-current-page-editor'));
    expect(page, findsOneWidget);
    await tester.ensureVisible(page);
    await tester.enterText(page, '27');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(controller.libraryItems.single.reading!.page, '27');
    expect(controller.libraryItems.single.reading!.totalPages, 1088);
    expect(controller.libraryItems.single.reading!.percent, 2);
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Página 27 de 1088'), findsOneWidget);
  });

  testWidgets('cada cita visible edita su propio texto sin perder el vínculo',
      (tester) async {
    final item = controller.libraryItems.single;
    final reading = item.reading!.toJson();
    reading['quotes'] = [
      ...item.reading!.quotes,
      {
        'id': 'segunda-cita',
        'text': 'Otra frase que merece ser recordada.',
        'page': '20',
        'anchor': '/segunda-posicion',
      },
    ];
    controller.updateLibraryItem(
      item.copyWith(reading: LibraryReading.fromJson(reading)),
      replaceReading: true,
    );
    await openLibrary(tester);
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Citas'));
    await tester.pumpAndSettle();
    expect(find.text('Una frase que merece ser recordada.'), findsOneWidget);
    expect(find.text('Otra frase que merece ser recordada.'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar cita').last);
    await tester.pumpAndSettle();
    expect(find.text('Editar cita'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('book-quote-text-editor')),
        'Una frase corregida.');
    await tester.enterText(
        find.byKey(const ValueKey('book-quote-page-editor')), '27');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cita'));
    await tester.pumpAndSettle();
    final quotes = controller.libraryItems.single.reading!.quotes;
    expect(quotes.first['text'], 'Una frase que merece ser recordada.');
    final quote = quotes.last;
    expect(quote['text'], 'Una frase corregida.');
    expect(quote['page'], '27');
    expect(quote['anchor'], '/segunda-posicion');
    expect(find.text('Una frase corregida.'), findsOneWidget);
  });

  testWidgets('la ficha cabe sin scroll en una ventana de altura reducida',
      (tester) async {
    await openLibrary(tester, size: const Size(1297, 739));
    await tester.tapAt(tester.getCenter(
        find.byKey(const ValueKey('library-cover-card-libro-prueba'))));
    await tester.pumpAndSettle();
    expect(find.text('Información'), findsOneWidget);
    expect(find.textContaining('Pantalla 20 de 1955'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(SingleChildScrollView)),
        findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(Tab, 'Citas'));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(SingleChildScrollView)),
        findsNothing);
    expect(tester.takeException(), isNull);
  });
}
