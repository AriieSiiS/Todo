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
  const longNote =
      'Una expedición atraviesa varios territorios y descubre secretos de sus '
      'habitantes. La historia desarrolla a sus personajes mediante decisiones '
      'y encuentros que transforman sus objetivos. Esta descripción continúa '
      'con detalles sobre la exploración, las relaciones y las consecuencias '
      'de cada etapa para comprobar que un texto largo no altere la ficha.';

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final now = DateTime(2026, 10, 25);
    controller = TodoWorkspace.createForTest(
      snapshot: AppStateSnapshot.fromJson({
        'libraryItems': [
          LibraryItem(
            id: 'libro-ficha',
            type: LibraryItemType.book,
            title: 'Libro de prueba',
            collectionName: 'Saga de prueba',
            status: LibraryItemStatus.inProgress,
            note: 'Una nota breve.',
            createdAt: now,
            updatedAt: now,
          ).toJson(),
          LibraryItem(
            id: 'juego-corto',
            type: LibraryItemType.game,
            title: 'Juego breve',
            status: LibraryItemStatus.pending,
            note: 'Una nota breve.',
            createdAt: now,
            updatedAt: now,
          ).toJson(),
          LibraryItem(
            id: 'juego-largo',
            type: LibraryItemType.game,
            title: 'La Tierra Media: Sombras de Mordor',
            collectionName: 'La Tierra Media',
            collectionNumber: 1,
            showCollectionNumber: true,
            status: LibraryItemStatus.pending,
            note: longNote,
            createdAt: now,
            updatedAt: now,
          ).toJson(),
          LibraryItem(
            id: 'pelicula-ficha',
            type: LibraryItemType.movieSeries,
            mediaType: LibraryMediaType.movie,
            title: 'Película de prueba',
            status: LibraryItemStatus.pending,
            createdAt: now,
            updatedAt: now,
          ).toJson(),
          LibraryItem(
            id: 'serie-ficha',
            type: LibraryItemType.movieSeries,
            mediaType: LibraryMediaType.series,
            title: 'Serie de prueba',
            status: LibraryItemStatus.pending,
            createdAt: now,
            updatedAt: now,
          ).toJson(),
        ],
      }),
    );
  });
  tearDown(() => controller.dispose());

  Future<void> openLibrary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildTodoTheme(),
      home: Scaffold(body: LibraryPage(controller: controller)),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openItem(WidgetTester tester, String id) async {
    final card = find.byKey(ValueKey('library-cover-card-$id'));
    await tester.tapAt(tester.getCenter(card));
    await tester.pumpAndSettle();
  }

  testWidgets('la cabecera conserva su altura con saga y orden junto al título',
      (tester) async {
    await openLibrary(tester);
    double? headerHeight;
    for (final (id, title, saga) in [
      ('juego-corto', 'Juego breve', null),
      ('libro-ficha', 'Libro de prueba', 'de prueba'),
      (
        'juego-largo',
        'La Tierra Media: Sombras de Mordor',
        'La Tierra Media'
      ),
      ('pelicula-ficha', 'Película de prueba', null),
      ('serie-ficha', 'Serie de prueba', null),
    ]) {
      await openItem(tester, id);
      final dialog = find.byType(Dialog);
      final divider =
          find.descendant(of: dialog, matching: find.byType(Divider)).first;
      final height =
          tester.getTopLeft(divider).dy - tester.getTopLeft(dialog).dy;
      headerHeight ??= height;
      expect(height, closeTo(headerHeight, .1));
      if (saga != null) {
        final titleRect = tester
            .getRect(find.descendant(of: dialog, matching: find.text(title)));
        final sagaRect = tester.getRect(
            find.descendant(of: dialog, matching: find.text(saga)).first);
        expect(sagaRect.left, greaterThanOrEqualTo(titleRect.right));
        expect(sagaRect.center.dy, closeTo(titleRect.center.dy, 2));
        if (id == 'juego-largo') {
          final order =
              find.descendant(of: dialog, matching: find.text('#1')).first;
          expect(
              tester.getRect(order).center.dy, closeTo(titleRect.center.dy, 2));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('libros y juegos mantienen el mismo tamaño de ficha y acciones',
      (tester) async {
    await openLibrary(tester);
    await openItem(tester, 'libro-ficha');
    final bookHeight = tester.getSize(find.byType(Dialog)).height;
    expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('Libro')),
        findsNothing);
    expect(find.text('Información'), findsWidgets);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar'));
    await tester.pumpAndSettle();

    await openItem(tester, 'juego-corto');
    final gameHeight = tester.getSize(find.byType(Dialog)).height;
    expect(gameHeight, bookHeight);
    expect(
        tester.getSize(find.byKey(const ValueKey('library-item-detail-cover'))),
        const Size(244, 416));
    expect(
        find.descendant(of: find.byType(Dialog), matching: find.text('Juego')),
        findsNothing);
    final close = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Cerrar'));
    final next = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Siguiente'));
    expect(close.style?.backgroundColor?.resolve({}),
        next.style?.backgroundColor?.resolve({}));
    expect(tester.takeException(), isNull);

    for (final (id, label) in [
      ('pelicula-ficha', 'Película'),
      ('serie-ficha', 'Serie'),
    ]) {
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar'));
      await tester.pumpAndSettle();
      await openItem(tester, id);
      expect(tester.getSize(find.byType(Dialog)).height, bookHeight);
      // El tipo sigue siendo un dato de la ficha, pero ya no se duplica bajo
      // el título de la cabecera.
      expect(
        find.descendant(of: find.byType(Dialog), matching: find.text(label)),
        findsOneWidget,
      );
    }
  });

  testWidgets('las notas extensas se resumen y se pueden leer completas',
      (tester) async {
    await openLibrary(tester);
    await openItem(tester, 'juego-largo');
    final preview = find.byKey(const ValueKey('library-detail-note-preview'));
    expect(preview, findsOneWidget);
    final text = tester.widget<Text>(preview);
    expect(text.maxLines, 3);
    expect(text.overflow, TextOverflow.ellipsis);
    await tester.tap(find.text('Leer notas completas'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
          of: find.byType(AlertDialog), matching: find.text(longNote)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
