import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'wrapped_piezas.dart';
import 'wrapped_render.dart';
import 'wrapped_reproductor.dart';

/// Fotogramas por segundo del vídeo exportado.
const fpsVideoWrapped = 30;

/// Una generación de vídeo en marcha (o ya terminada).
class TrabajoVideo {
  TrabajoVideo._(this.firma, this.archivo);

  final String firma;

  /// Vídeo en la caché, listo cuando [resultado] termina.
  final File archivo;
  final progreso = ValueNotifier<double>(0);

  /// Con prisa se rasteriza a toda velocidad; sin ella cede tiempo a la
  /// interfaz para no entorpecer la reproducción.
  bool prisa = false;
  bool _cancelado = false;
  late final Future<File?> resultado;

  bool get terminado => progreso.value >= 1;
}

/// Genera el vídeo del Wrapped en segundo plano y lo guarda en caché, para
/// que «Descargar el vídeo» solo tenga que copiarlo.
///
/// La caché vive en `Documents/Todo/wrapped/videos` y cada vídeo lleva al lado
/// la firma de lo que contiene (datos, ajustes y música). Si nada ha cambiado,
/// se reutiliza; si algo cambia, se genera otro.
class VideosWrapped {
  static TrabajoVideo? _actual;

  static Directory carpetaCache() {
    final inicio = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final s = Platform.pathSeparator;
    return Directory('$inicio${s}Documents${s}Todo${s}wrapped${s}videos');
  }

  /// Firma estable de un vídeo a partir de sus ingredientes.
  static String firmaDe(Object ingredientes) {
    final texto = jsonEncode(ingredientes);
    // FNV-1a de 64 bits: suficiente para distinguir versiones.
    var h = 0xcbf29ce484222325;
    for (final c in utf8.encode(texto)) {
      h ^= c;
      h = h * 0x100000001b3;
    }
    return h.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }

  /// Devuelve el trabajo de ese vídeo: el que ya existe, el que está en
  /// marcha o uno nuevo.
  static TrabajoVideo preparar({
    required String clave,
    required String firma,
    required List<DiapositivaWrapped> diapositivas,
    required List<Duration> duraciones,
    required Iterable<String?> portadas,
    String? rutaMusica,
    ui.FlutterView? vista,
    bool prisa = false,
  }) {
    final actual = _actual;
    if (actual != null && actual.firma == firma && !actual._cancelado) {
      if (prisa) actual.prisa = true;
      return actual;
    }
    actual?._cancelado = true;
    final carpeta = carpetaCache();
    final archivo =
        File('${carpeta.path}${Platform.pathSeparator}$clave-$firma.mp4');
    final trabajo = TrabajoVideo._(firma, archivo)..prisa = prisa;
    _actual = trabajo;
    if (archivo.existsSync() && archivo.lengthSync() > 0) {
      trabajo.progreso.value = 1;
      trabajo.resultado = Future.value(archivo);
      return trabajo;
    }
    trabajo.resultado = _generar(
      trabajo,
      clave: clave,
      diapositivas: diapositivas,
      duraciones: duraciones,
      portadas: portadas,
      rutaMusica: rutaMusica,
      vista: vista ??
          WidgetsBinding.instance.platformDispatcher.implicitView ??
          WidgetsBinding.instance.platformDispatcher.views.first,
    ).catchError((Object _) => null).whenComplete(() {
      if (identical(_actual, trabajo) && !trabajo.terminado) _actual = null;
    });
    return trabajo;
  }

  static Future<File?> _generar(
    TrabajoVideo trabajo, {
    required String clave,
    required List<DiapositivaWrapped> diapositivas,
    required List<Duration> duraciones,
    required Iterable<String?> portadas,
    required ui.FlutterView vista,
    String? rutaMusica,
  }) async {
    final ffmpeg = await buscarFfmpeg();
    if (ffmpeg == null) return null;
    await TipografiaWrapped.precargar();
    final cacheImagenes = PaintingBinding.instance.imageCache;
    final limiteAnterior = cacheImagenes.maximumSizeBytes;
    cacheImagenes.maximumSizeBytes =
        limiteAnterior < (600 << 20) ? (600 << 20) : limiteAnterior;
    // Se retienen las portadas para que ninguna se descargue de memoria
    // a mitad del vídeo y salga en blanco.
    final retenidas = await PortadasRetenidas.cargar(portadas);
    final carpeta = trabajo.archivo.parent;
    await carpeta.create(recursive: true);
    final temporal = File('${trabajo.archivo.path}.parcial.mp4');
    final total = [
      for (final d in duraciones)
        (d.inMilliseconds * fpsVideoWrapped / 1000).round()
    ];
    final fotogramas = total.fold<int>(0, (a, b) => a + b);
    final segundos = fotogramas / fpsVideoWrapped;
    final conMusica = rutaMusica != null && File(rutaMusica).existsSync();
    final proceso = await Process.start(ffmpeg, [
      '-y',
      '-loglevel',
      'error',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-s',
      '1080x1920',
      '-r',
      '$fpsVideoWrapped',
      '-i',
      '-',
      if (conMusica) ...['-stream_loop', '-1', '-i', rutaMusica],
      '-c:v',
      'libx264',
      '-preset',
      'fast',
      '-crf',
      '19',
      '-pix_fmt',
      'yuv420p',
      '-movflags',
      '+faststart',
      if (conMusica) ...[
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-af',
        'afade=t=in:d=1,afade=t=out:st=${(segundos - 2.5).toStringAsFixed(2)}:d=2.5',
        '-t',
        segundos.toStringAsFixed(2),
      ],
      temporal.path,
    ]);
    final errores = StringBuffer();
    unawaited(proceso.stderr
        .transform(const SystemEncoding().decoder)
        .forEach(errores.write));
    unawaited(proceso.stdout.drain<void>());
    final lienzo =
        LienzoFueraDePantalla(vista: vista, diapositivas: diapositivas);
    final cola = <Future<Uint8List?>>[];
    Future<Uint8List?> bytes(Future<ui.Image> imagen) async {
      final img = await imagen;
      final datos = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
      return datos?.buffer.asUint8List();
    }

    var escritos = 0;
    Future<void> escribirSiguiente() async {
      final datos = await cola.removeAt(0);
      if (datos != null) proceso.stdin.add(datos);
      escritos++;
      if (escritos % 15 == 0) {
        await proceso.stdin.flush();
        trabajo.progreso.value = (escritos / fotogramas).clamp(0, .99);
      }
    }

    var bien = false;
    try {
      for (var i = 0; i < diapositivas.length && !trabajo._cancelado; i++) {
        (await lienzo.capturar(i, 0)).dispose();
        for (var f = 0; f < total[i] && !trabajo._cancelado; f++) {
          cola.add(bytes(lienzo.capturar(i, f / total[i])));
          if (cola.length >= (trabajo.prisa ? 6 : 3)) await escribirSiguiente();
          // Sin prisa, se deja respirar a la interfaz entre fotogramas, y
          // más aún si se está viendo un Wrapped para que no dé tirones.
          if (!trabajo.prisa) {
            await Future<void>.delayed(
                Duration(milliseconds: wrappedReproduciendo.value ? 14 : 2));
          }
        }
      }
      while (cola.isNotEmpty && !trabajo._cancelado) {
        await escribirSiguiente();
      }
      bien = !trabajo._cancelado;
    } finally {
      lienzo.dispose();
      retenidas.liberar();
      cacheImagenes.maximumSizeBytes = limiteAnterior;
      try {
        await proceso.stdin.flush();
        await proceso.stdin.close();
      } catch (_) {}
    }
    final codigo = await proceso.exitCode;
    if (!bien || codigo != 0) {
      try {
        await temporal.delete();
      } catch (_) {}
      if (!bien) return null;
      throw Exception(errores.toString());
    }
    // Se quitan versiones anteriores del mismo Wrapped.
    try {
      for (final viejo in carpeta.listSync().whereType<File>()) {
        final nombre = viejo.uri.pathSegments.last;
        if (nombre.startsWith('$clave-') && viejo.path != temporal.path) {
          viejo.deleteSync();
        }
      }
    } catch (_) {}
    await temporal.rename(trabajo.archivo.path);
    trabajo.progreso.value = 1;
    return trabajo.archivo;
  }
}

/// Mantiene cargadas en memoria unas portadas mientras dure un trabajo.
class PortadasRetenidas {
  PortadasRetenidas._();
  final _escuchas = <(ImageStream, ImageStreamListener)>[];

  static Future<PortadasRetenidas> cargar(Iterable<String?> fuentes) async {
    final r = PortadasRetenidas._();
    final esperas = <Future<void>>[];
    for (final fuente in fuentes.toSet()) {
      final proveedor = proveedorPortada(fuente);
      if (proveedor == null) continue;
      final listo = Completer<void>();
      final flujo = proveedor.resolve(ImageConfiguration.empty);
      final escucha = ImageStreamListener((_, __) {
        if (!listo.isCompleted) listo.complete();
      }, onError: (_, __) {
        if (!listo.isCompleted) listo.complete();
      });
      flujo.addListener(escucha);
      r._escuchas.add((flujo, escucha));
      esperas.add(
          listo.future.timeout(const Duration(seconds: 10), onTimeout: () {}));
    }
    await Future.wait(esperas);
    return r;
  }

  void liberar() {
    for (final (flujo, escucha) in _escuchas) {
      flujo.removeListener(escucha);
    }
    _escuchas.clear();
  }
}

/// Duración de cada diapositiva con una duración base en segundos.
List<Duration> duracionesWrapped(
        List<DiapositivaWrapped> diapositivas, int segundos) =>
    [
      for (final d in diapositivas)
        Duration(milliseconds: (segundos * 1000 * d.duracion).round())
    ];

/// Firma completa de un vídeo: datos y ajustes, música, ritmo y diapositivas.
String firmaVideoWrapped(String firmaBase, String? fuenteMusica, int segundos,
        List<DiapositivaWrapped> diapositivas) =>
    VideosWrapped.firmaDe([
      firmaBase,
      fuenteMusica ?? 'sin-musica',
      segundos,
      [for (final d in diapositivas) d.id],
    ]);
