import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shared/book_reading_panel.dart';
import 'package:todo/presentation/shared/book_statistics_panel.dart';

void main() {
  LibraryItem book(LibraryReading reading, {String? pages}) => LibraryItem(
      id: 'libro',
      type: LibraryItemType.book,
      title: 'Libro de prueba',
      status: LibraryItemStatus.inProgress,
      reading: reading,
      pages: pages,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026));
  testWidgets('un pendiente sin historial muestra páginas leídas',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 1000,
                height: 500,
                child: BookStatisticsPanel(reading: null)))));
    expect(find.text('Páginas leídas'), findsOneWidget);
    expect(find.text('Pantallas leídas'), findsNothing);
  });
  testWidgets('el mapa fijo usa páginas leídas y ritmo por página',
      (tester) async {
    final reading = LibraryReading.fromJson({
      'progress': .1,
      'observedAt': 100,
      'page': '10',
      'totalPages': 100,
      'pageUnit': 'estimated_page',
      'position': '/p[10]',
      'documents': <String>[],
      'cursors': <String, int>{},
      'quotes': <Map<String, dynamic>>[],
      'statistics': {
        'origen:1': {
          'observedAt': 100,
          'pageUnit': 'estimated_page',
          'periods': [
            {'start': 3600, 'seconds': 120, 'pages': 2}
          ]
        }
      }
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 1000,
                height: 500,
                child: BookStatisticsPanel(reading: reading)))));
    expect(find.text('Páginas leídas'), findsOneWidget);
    expect(find.text('60 s / página'), findsOneWidget);
    expect(find.text('Pantallas leídas'), findsNothing);
  });
  LibraryReading reading(String unit) => LibraryReading.fromJson({
        'progress': 140 / 1087,
        'observedAt': 100,
        'page': '140',
        'totalPages': 1087,
        'pageUnit': unit,
        'position': '/body/p[140]',
        'documents': <String>[],
        'cursors': <String, int>{},
        'quotes': <Map<String, dynamic>>[],
      });

  testWidgets('una pantalla no se divide entre las páginas editoriales',
      (tester) async {
    final value = reading('screen');
    await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: BookReadingBadge(item: book(value, pages: '600')))));
    expect(find.text('13%'), findsOneWidget);
    expect(tester.widget<Tooltip>(find.byType(Tooltip)).message,
        '13% leído\nPantalla 140 de 1087');
    expect(bookPageTotal('600', value), 1087);
    expect(bookPageTotal(null, value, manual: true), isNull,
        reason:
            'Una edición sin total conocido no puede usar pantallas como páginas');
    expect(value.toJson()['pageUnit'], 'screen');
  });

  testWidgets(
      'un PDF conserva páginas y los registros antiguos no las inventan',
      (tester) async {
    for (final entry
        in {'page': 'Página', 'unknown': 'Posición en KOReader'}.entries) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: BookReadingBadge(item: book(reading(entry.key))))));
      expect(tester.widget<Tooltip>(find.byType(Tooltip)).message,
          '13% leído\n${entry.value} 140 de 1087');
    }
  });

  testWidgets('el recuento y el ritmo de EPUB se muestran en pantallas',
      (tester) async {
    final data = reading('screen').toJson();
    data['statistics'] = {
      'origen:1': {
        'observedAt': 100,
        'pageUnit': 'screen',
        'periods': [
          {'start': 3600, 'seconds': 120, 'pages': 2}
        ]
      }
    };
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 1000,
                height: 500,
                child: BookStatisticsPanel(
                    reading: LibraryReading.fromJson(data))))));
    expect(find.text('Pantallas leídas'), findsOneWidget);
    expect(find.text('60 s / pantalla'), findsOneWidget);
    expect(find.text('Páginas leídas'), findsNothing);
  });
  testWidgets('el resumen anual no usa pantallas para el libro más largo',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final data = reading('screen').toJson();
    data['statistics'] = {
      'origen:1': {
        'observedAt': 100,
        'pageUnit': 'screen',
        'periods': [
          {
            'start': (now.millisecondsSinceEpoch ~/ 3600000) * 3600,
            'seconds': 120,
            'pages': 2
          }
        ]
      }
    };
    final book = LibraryItem(
        id: 'libro',
        title: 'Libro de prueba',
        type: LibraryItemType.book,
        createdAt: now,
        updatedAt: now,
        status: LibraryItemStatus.completed,
        completedDate: now,
        reading: LibraryReading.fromJson(data));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AnnualReadingStatisticsDialog(books: [book]))));
    expect(find.text('Pantallas leídas'), findsOneWidget);
    await tester.tap(find.text('Récords y hábitos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1087 páginas'), findsNothing);
    expect(find.text('60 s / pantalla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
