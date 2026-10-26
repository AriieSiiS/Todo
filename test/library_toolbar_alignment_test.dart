// Comprueba que la barra de Biblioteca queda alineada en todas las pestañas.
// Para guardar capturas: flutter test test/library_toolbar_alignment_test.dart --dart-define=CAPTURAS=<carpeta>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/application/state/todo_workspace.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/shell/app_shell.dart';

const _salida = String.fromEnvironment('CAPTURAS');

void main() {
  late TodoWorkspace controller;
  setUpAll(() async {
    final cargador = FontLoader('Roboto');
    for (final f in ['regular', 'medium', 'bold']) {
      cargador.addFont(Future.value(File(
              'C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-$f.ttf')
          .readAsBytesSync()
          .buffer
          .asByteData()));
    }
    await cargador.load();
    final iconos = FontLoader('MaterialIcons')
      ..addFont(Future.value(File(
              'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf')
          .readAsBytesSync()
          .buffer
          .asByteData()));
    await iconos.load();
  });
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final now = DateTime(2026, 10, 24);
    LibraryItem item(String id, LibraryItemType type) => LibraryItem(
        id: id,
        type: type,
        title: 'Título $id',
        collectionName: 'Saga $id',
        universeName: 'Universo ${type.name}',
        status: LibraryItemStatus.completed,
        createdAt: now,
        updatedAt: now);
    controller = TodoWorkspace.createForTest(
        snapshot: AppStateSnapshot.fromJson({
      'libraryItems': [
        for (final type in LibraryItemType.values)
          item('a-${type.name}', type).toJson(),
      ]
    }));
  });
  tearDown(() => controller.dispose());

  for (final ancho in [1320.0, 1365.0, 1600.0]) {
    testWidgets('los chips y los controles comparten fila a $ancho px',
        (tester) async {
      tester.view.physicalSize = Size(ancho, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final clave = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTodoTheme().copyWith(
              textTheme: buildTodoTheme().textTheme.apply(fontFamily: 'Roboto')),
          home: Scaffold(
              body: RepaintBoundary(
                  key: clave, child: LibraryPage(controller: controller)))));
      await tester.pumpAndSettle();

      final etiquetas = ['Todas', 'Juegos', 'Libros', 'Pelis y series'];
      for (final etiqueta in etiquetas) {
        await tester.tap(find.text(etiqueta).first);
        await tester.pumpAndSettle();
        final chips = [
          for (final e in etiquetas) tester.getRect(find.text(e).first),
        ];
        final fila = chips.first.center.dy;
        for (final chip in chips) {
          expect((chip.center.dy - fila).abs(), lessThan(1),
              reason: 'chips partidos en «$etiqueta» a $ancho px');
        }
        final busqueda = find.byType(TextField).first;
        final conmutador = find.byIcon(Icons.grid_view_rounded);
        final controles = [
          tester.getRect(busqueda),
          tester.getRect(find.byIcon(Icons.expand_more_rounded).last),
          if (conmutador.evaluate().isNotEmpty) tester.getRect(conmutador),
        ];
        for (final control in controles) {
          expect((control.center.dy - fila).abs(), lessThan(1),
              reason: 'controles fuera de la fila en «$etiqueta» a $ancho px');
          expect(control.left, greaterThan(chips.last.right));
        }
        // Solo importan los desbordamientos; las fuentes remotas no se cargan.
        Object? error;
        final desbordes = <String>[];
        while ((error = tester.takeException()) != null) {
          if (error is FlutterError) desbordes.add(error.toStringDeep());
        }
        expect(desbordes, isEmpty,
            reason: 'desbordamiento en «$etiqueta» a $ancho px');
        if (_salida.isNotEmpty) {
          await tester.runAsync(() async {
            final limite = clave.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
            final imagen = await limite.toImage(pixelRatio: 1);
            final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
            Directory(_salida).createSync(recursive: true);
            File('$_salida/${ancho.toInt()}_${etiqueta.replaceAll(' ', '_')}.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      }
    });
  }
}
