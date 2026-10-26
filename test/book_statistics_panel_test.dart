import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shared/book_statistics_panel.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  final now = DateTime.now();
  final start =
      (DateTime(now.year, 1, 2, 12).millisecondsSinceEpoch ~/ 3600000) * 3600;
  final reading = LibraryReading(
      progress: .1,
      observedAt: 100,
      page: '10',
      position: '',
      documents: [],
      cursors: {},
      quotes: [],
      statistics: {
        'historial:1': BookReadingStatistics(
            observedAt: 100,
            periods: [ReadingPeriod(start: start, seconds: 300, pages: 5)])
      });
  testWidgets(
      'las estadísticas del libro caben y muestran tiempo, actividad y ritmo',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 700,
                    height: 320,
                    child: BookStatisticsPanel(reading: reading))))));
    await tester.pumpAndSettle();
    expect(find.text('5 min'), findsNWidgets(2)); // total y media por día
    expect(find.text('60 s / página'), findsOneWidget);
    expect(find.text('Actividad de ${now.year}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'el resumen anual muestra lecturas y cambia de año sin inventar tiempos',
      (tester) async {
    tester.view.physicalSize = const Size(960, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final book = LibraryItem(
        id: 'prueba',
        title: 'Libro con estadísticas',
        type: LibraryItemType.book,
        status: LibraryItemStatus.completed,
        completedDate: DateTime(now.year - 1, 8),
        author: 'Autora',
        createdAt: now,
        updatedAt: now,
        reading: reading);
    await tester.pumpWidget(MaterialApp(
        theme: buildTodoTheme(),
        home: Scaffold(body: AnnualReadingStatisticsDialog(books: [book]))));
    await tester.pumpAndSettle();
    expect(find.text('5 min'), findsNWidgets(2));
    expect(find.text('Libro con estadísticas'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Elegir año'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${now.year - 1}').last);
    await tester.pumpAndSettle();
    expect(find.text('0 min'), findsOneWidget);
    expect(find.text('Los tiempos de tus próximas lecturas aparecerán aquí.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
