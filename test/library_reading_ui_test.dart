import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shared/book_reading_panel.dart';
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
    expect(find.descendant(of: strip, matching: find.text('20 / 1088 páginas')),
        findsOneWidget);
    expect(
        find.descendant(of: strip, matching: find.text('2 %')), findsOneWidget);
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
    expect(find.byKey(ValueKey('library-cover-card-${serie.id}')), findsOneWidget);
    final franja = find.byKey(ValueKey('library-cover-progress-${serie.id}'));
    expect(franja, findsNothing);
    controller.marcarUnidadDeProgreso(serie.id);
    await tester.pump(const Duration(seconds: 2));
    // La página de prueba no escucha al controlador: se vuelve a pintar.
    await openLibrary(tester);
    expect(franja, findsOneWidget);
    expect(find.descendant(of: franja, matching: find.text('1 / 12 episodios')),
        findsOneWidget);
    expect(
        controller.libraryItems.firstWhere((i) => i.id == serie.id).status,
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
    await tester.pump(const Duration(seconds: 1));
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
    expect(find.textContaining('Página 20 de 1088'), findsOneWidget);
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
    expect(find.textContaining('Página 20 de 1088'), findsOneWidget);
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
        find.descendant(of: badge, matching: find.text('2%')), findsOneWidget);
    expect(find.textContaining('Página 20 de 1088'), findsOneWidget);
    expect(find.textContaining('Página 20 de 1088'), findsOneWidget);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(badge));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Página 20 de 1088'), findsWidgets);
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
    expect(find.textContaining('Página 20 de 1088'), findsOneWidget);
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
