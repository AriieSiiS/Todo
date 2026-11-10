// Captura de los logros agrupados por juego base y expansión, con los datos
// guardados de Sombras de Mordor. No usa la red ni modifica nada. Uso:
//   flutter test test/capturas/logros_grupos_captura_test.dart --dart-define=CAPTURAS=<carpeta>
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:todo/app/todo_theme.dart';
import 'package:todo/presentation/shared/steam_panels.dart';
import 'package:todo/services/steam_service.dart';

const _salida = String.fromEnvironment('CAPTURAS');
const _carpeta = 'C:/Users/aries/Documents/Todo/steam_icons/241930';

class _ServicioFalso extends SteamService {
  _ServicioFalso()
      : result = jsonDecode(File('$_carpeta/logros.json').readAsStringSync())
            as Map<String, dynamic>;
  final Map<String, dynamic> result;

  @override
  Future<Map<String, dynamic>?> savedAchievements(String itemId) async => result;

  @override
  Future<List<Map<String, dynamic>>> games({bool refresh = false}) async => [];

  @override
  Future<int?> linkedApp(
          String itemId, String title, List<Map<String, dynamic>> games) async =>
      241930;

  @override
  Future<Map<String, dynamic>> achievements(int appId,
          {bool refresh = false}) async =>
      result;
}

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('captura', (tester) async {
    if (_salida.isEmpty) return;
    final cargador = FontLoader('Roboto');
    for (final f in ['regular', 'medium', 'bold']) {
      cargador.addFont(Future.value(File(
              'C:/src/flutter/bin/cache/artifacts/material_fonts/roboto-$f.ttf')
          .readAsBytesSync()
          .buffer
          .asByteData()));
    }
    await cargador.load();
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tema = buildTodoTheme().copyWith(
        textTheme: buildTodoTheme().textTheme.apply(fontFamily: 'Roboto'));
    final clave = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: tema,
        home: Scaffold(
            body: RepaintBoundary(
                key: clave,
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SteamGamePanel(
                        service: _ServicioFalso(),
                        itemId: 'mordor',
                        title: 'Sombras de Mordor'))))));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Juego base'));
    await tester.pump(const Duration(milliseconds: 200));
    Directory(_salida).createSync(recursive: true);
    await tester.runAsync(() async {
      final limite =
          clave.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final imagen = await limite.toImage(pixelRatio: 1);
      final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
      File('$_salida/logros_grupos.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
