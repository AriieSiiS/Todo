// Genera una imagen por diapositiva del Wrapped de libros con la Biblioteca
// real (solo lectura) para revisarlas a ojo. Uso:
//   flutter test test/capturas/wrapped_libros_captura_test.dart \
//     --dart-define=CAPTURAS=<carpeta> --dart-define=FUENTES=<carpeta con ttf>
// FUENTES debe tener Titular-*.ttf, Serif-*.ttf y Texto-*.ttf.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/domain/models.dart';
import 'package:todo/presentation/wrapped/wrapped_centro.dart';
import 'package:todo/presentation/wrapped/wrapped_diapositivas.dart';
import 'package:todo/presentation/wrapped/wrapped_piezas.dart';
import 'package:todo/application/wrapped/wrapped_modelo.dart';
import 'package:todo/presentation/wrapped/wrapped_reproductor.dart';
import 'package:todo/presentation/wrapped/wrapped_video.dart';

const _salida = String.fromEnvironment('CAPTURAS');
const _fuentes = String.fromEnvironment('FUENTES');
const _year = int.fromEnvironment('YEAR', defaultValue: 2026);
const _momentos = String.fromEnvironment('MOMENTOS', defaultValue: '1');
const _solo = String.fromEnvironment('SOLO');
const _tipo = String.fromEnvironment('TIPO', defaultValue: 'libros');
const _video = bool.fromEnvironment('VIDEO');

void main() {
  testWidgets('capturas del Wrapped de libros', (tester) async {
    if (_salida.isEmpty) return;
    TipografiaWrapped.usarFuentesLocales = true;
    await tester.runAsync(() async {
      for (final familia in ['Titular', 'Serif', 'Texto']) {
        final cargador = FontLoader(familia);
        for (final f in Directory(_fuentes).listSync().whereType<File>()) {
          final nombre = f.uri.pathSegments.last;
          if (nombre.startsWith('$familia-')) {
            cargador
                .addFont(Future.value(f.readAsBytesSync().buffer.asByteData()));
          }
        }
        await cargador.load();
      }
      final iconos = FontLoader('MaterialIcons')
        ..addFont(Future.value(File(
                'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf')
            .readAsBytesSync()
            .buffer
            .asByteData()));
      await iconos.load();
    });

    final inicio = Platform.environment['USERPROFILE']!;
    final estado = jsonDecode(
        File('$inicio/Documents/Todo/runtime/todo_state.json')
            .readAsStringSync()) as Map<String, dynamic>;
    final biblioteca = [
      for (final j in estado['libraryItems'] as List)
        LibraryItem.fromJson(Map<String, dynamic>.from(j as Map))
    ];
    final metas = [
      for (final j in estado['libraryGoals'] as List)
        LibraryGoal.fromJson(Map<String, dynamic>.from(j as Map))
    ];
    final w = (await tester.runAsync(() => prepararWrapped(
        tipo: WrappedTipo.desdeClave(_tipo)!,
        year: _year,
        biblioteca: biblioteca,
        propositos: metas,
        ajustes: AlmacenWrapped().leerAjustes())))!;
    final r = w.resumen;
    final slides = w.diapositivas;
    // ignore: avoid_print
    print('datos listos: ${slides.length} diapositivas: ${slides.map((d) => d.id).join(', ')}');
    // Las portadas se cargan antes, fuera del reloj falso de las pruebas.
    await tester.runAsync(() async {
      for (final fuente in portadasDe(r)) {
        final proveedor = proveedorPortada(fuente);
        if (proveedor == null) continue;
        final listo = Completer<void>();
        final flujo = proveedor.resolve(ImageConfiguration.empty);
        late final ImageStreamListener oyente;
        oyente = ImageStreamListener((_, __) {
          if (!listo.isCompleted) listo.complete();
          flujo.removeListener(oyente);
        }, onError: (_, __) {
          if (!listo.isCompleted) listo.complete();
        });
        flujo.addListener(oyente);
        await listo.future
            .timeout(const Duration(seconds: 5), onTimeout: () {});
      }
    });
    Directory(_salida).createSync(recursive: true);

    tester.view.physicalSize = const Size(anchoLienzo, altoLienzo) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    if (_video) {
      // El mismo generador que usa la app, con un segundo por diapositiva.
      await tester.runAsync(() async {
        final reloj = Stopwatch()..start();
        final musica = await rutaDeAudio(fuenteMusicaWrapped('taberna')!);
        final trabajo = VideosWrapped.preparar(
          clave: 'prueba-captura',
          firma: VideosWrapped.firmaDe([DateTime.now().toIso8601String()]),
          diapositivas: slides,
          duraciones: [for (final _ in slides) const Duration(seconds: 1)],
          portadas: portadasDe(r),
          rutaMusica: musica,
          vista: tester.view,
          prisa: true,
        );
        final archivo = await trabajo.resultado;
        expect(archivo, isNotNull);
        final copia = File('$_salida/prueba-video.mp4');
        await archivo!.copy(copia.path);
        await archivo.delete();
        // ignore: avoid_print
        print('vídeo de ${slides.length * 30} fotogramas en ${reloj.elapsed}');
      });
      return;
    }

    final momentos = _momentos.split(',').map(double.parse).toList();
    for (var i = 0; i < slides.length; i++) {
      if (_solo.isNotEmpty && !_solo.split(',').contains(slides[i].id)) {
        continue;
      }
      for (final t in momentos) {
        final clave = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Texto'),
          home: RepaintBoundary(
            key: clave,
            child: SizedBox(
              width: anchoLienzo,
              height: altoLienzo,
              child: Builder(
                builder: (context) => Material(
                  type: MaterialType.transparency,
                  child: Stack(fit: StackFit.expand, children: [
                    FondoVivo(paleta: slides[i].paleta, t: t, semilla: i + 3),
                    slides[i].construir(context, t),
                  ]),
                ),
              ),
            ),
          ),
        ));
        // Las portadas locales se decodifican fuera del reloj falso.
        await tester.runAsync(() async {
          for (final e in tester.allElements.toList()) {
            final w = e.widget;
            if (w is Image) {
              await precacheImage(w.image, e)
                  .timeout(const Duration(seconds: 5))
                  .catchError((Object _) {});
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 1500));
        });
        await tester.pump();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
        // ignore: avoid_print
        print('diapositiva $i');
        await tester.runAsync(() async {
          final limite =
              clave.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final imagen = await limite.toImage(pixelRatio: 2);
          final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);
          final sufijo = momentos.length > 1 ? '-t${(t * 100).round()}' : '';
          File('$_salida/${(i + 1).toString().padLeft(2, '0')}-${slides[i].id}$sufijo.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
    }
    expect(tester.takeException(), isNull);
  });
}
