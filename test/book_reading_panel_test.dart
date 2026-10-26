import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/domain/entities/library_reading.dart';
import 'package:todo/presentation/shared/book_reading_panel.dart';

void main() {
  testWidgets(
      'el porcentaje muestra página, total y capítulo al pasar el cursor',
      (tester) async {
    final reading = LibraryReading.fromJson({
      'progress': .01,
      'observedAt': 100,
      'page': '20',
      'totalPages': 1955,
      'chapter': 'Capítulo 7',
      'documents': <String>[],
      'cursors': <String, int>{},
      'quotes': <Map<String, dynamic>>[]
    });
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: BookReadingBadge(reading: reading))));
    expect(find.text('1%'), findsOneWidget);
    expect(tester.widget<Tooltip>(find.byType(Tooltip)).message,
        '1% leído\nPágina 20 de 1955\nCapítulo 7');
  });

  testWidgets('las citas vacías explican dónde guardar un subrayado',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body:
                SingleChildScrollView(child: BookQuotesPanel(reading: null)))));
    expect(find.text('Todavía no hay citas'), findsOneWidget);
    expect(find.textContaining('Kindle'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('citas largas, capítulos y notas caben en un panel estrecho',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reading = LibraryReading(
        progress: .14,
        observedAt: 100,
        page: '42',
        position: '',
        documents: [],
        cursors: {},
        quotes: [
          {
            'text': 'Una frase extensa para recordar. ' * 30,
            'note': 'Una nota personal. ' * 20,
            'page': '9',
            'chapter':
                'Un capítulo con un título largo que ocupa varias líneas',
            'created_at': '2026-10-24'
          },
        ]);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: BookQuotesPanel(reading: reading)))));
    expect(find.text('Página 9'), findsOneWidget);
    expect(find.textContaining('2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'muestra juntas todas las citas que caben sin navegación ni scroll',
      (tester) async {
    final reading = LibraryReading(
      progress: 0,
      observedAt: 100,
      page: '0',
      position: '',
      documents: [],
      cursors: {},
      quotes: [
        {'text': 'Primera cita', 'page': '2', 'id': 'primera'},
        {'text': 'Segunda cita', 'page': '4', 'id': 'segunda'},
      ],
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: BookQuotesPanel(reading: reading)),
    ));
    expect(find.text('Primera cita'), findsOneWidget);
    expect(find.text('Segunda cita'), findsOneWidget);
    expect(find.textContaining('citas guardadas'), findsNothing);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byTooltip('Cita siguiente'), findsNothing);
    expect(find.byTooltip('Citas siguientes'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el alto disponible determina cuántas citas caben por página',
      (tester) async {
    final reading = LibraryReading.fromJson({
      'progress': 0,
      'observedAt': 100,
      'documents': <String>[],
      'cursors': <String, int>{},
      'quotes': [
        for (var index = 0; index < 12; index++)
          {'id': 'cita-$index', 'text': 'Cita número $index', 'page': '$index'},
      ],
    });
    Future<void> showPanel(double height) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 600,
              height: height,
              child: BookQuotesPanel(reading: reading),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await showPanel(300);
    final smallCount = find.byTooltip('Copiar cita').evaluate().length;
    expect(smallCount, greaterThan(1));
    expect(smallCount, lessThan(12));
    expect(find.text('Cita número 0'), findsOneWidget);
    await tester.tap(find.byTooltip('Citas siguientes'));
    await tester.pumpAndSettle();
    expect(find.text('Cita número 0'), findsNothing);
    await tester.tap(find.byTooltip('Citas anteriores'));
    await tester.pumpAndSettle();
    expect(find.text('Cita número 0'), findsOneWidget);
    await showPanel(550);
    expect(find.byTooltip('Copiar cita').evaluate().length,
        greaterThan(smallCount));
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
