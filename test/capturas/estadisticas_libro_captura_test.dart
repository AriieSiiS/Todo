// Genera capturas del panel de estadísticas con datos ficticios.
// No toca la biblioteca real. Uso:
//   flutter test test/capturas/estadisticas_libro_captura_test.dart --dart-define=CAPTURAS=<carpeta>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shared/book_statistics_panel.dart';

const _salida = String.fromEnvironment('CAPTURAS');

LibraryReading _lecturaFicticia() {
  final ahora = DateTime.now();
  final periodos = <ReadingPeriod>[];
  var semilla = 7;
  for (var dia = 0; dia < 150; dia++) {
    semilla = (semilla * 1103515245 + 12345) & 0x7fffffff;
    if (semilla % 10 < 4) continue; // días sin lectura
    final fecha = DateTime(ahora.year, ahora.month, ahora.day - dia, 21);
    final inicio = fecha.millisecondsSinceEpoch ~/ 3600000 * 3600;
    periodos.add(ReadingPeriod(
        start: inicio,
        seconds: 600 + semilla % 2400,
        pages: 8 + semilla % 25));
  }
  return LibraryReading(
      progress: .62,
      observedAt: 100,
      page: '248',
      position: '',
      documents: [],
      cursors: {},
      quotes: [],
      statistics: {
        'historial:prueba':
            BookReadingStatistics(observedAt: 100, periods: periodos)
      });
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> capturar(WidgetTester tester, String nombre, Size tamano,
      LibraryReading? lectura) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tema = buildTodoTheme()
        .copyWith(textTheme: buildTodoTheme().textTheme.apply(fontFamily: 'Roboto'));
    final clave = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: tema,
        home: Scaffold(
            body: RepaintBoundary(
                key: clave,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
                    child: BookStatisticsPanel(reading: lectura))))));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final limite =
          clave.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final imagen = await limite.toImage(pixelRatio: 1);
      final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
      File('$_salida/$nombre.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('capturas', (tester) async {
    if (_salida.isEmpty) return;
    final cargador = FontLoader('Roboto');
    for (final f in ['regular', 'medium', 'bold']) {
      cargador.addFont(Future.value(File('C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-$f.ttf')
          .readAsBytesSync()
          .buffer
          .asByteData()));
    }
    await cargador.load();
    Directory(_salida).createSync(recursive: true);
    await capturar(tester, '${_prefijo}vacio', const Size(900, 380), null);
    await capturar(tester, '${_prefijo}datos', const Size(900, 380), _lecturaFicticia());
  });
}

const _prefijo = String.fromEnvironment('PREFIJO');
