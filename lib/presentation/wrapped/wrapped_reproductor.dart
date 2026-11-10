import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../application/wrapped/wrapped_modelo.dart';
import 'wrapped_piezas.dart';

/// Indica al resto de la app que suena un Wrapped (para pausar otra música).
final wrappedReproduciendo = ValueNotifier<bool>(false);

/// Una diapositiva del Wrapped. [construir] recibe el avance `t` (0 → 1).
///
/// Las entradas deben terminar hacia `t = .75`: la imagen descargada es el
/// fotograma final.
class DiapositivaWrapped {
  const DiapositivaWrapped({
    required this.id,
    required this.nombre,
    required this.paleta,
    required this.construir,
    this.duracion = 1,
  });

  /// Identificador estable, usado en `ocultar` y en el nombre de la imagen.
  final String id;

  /// Nombre legible en el panel de personalización.
  final String nombre;
  final Paleta paleta;
  final Widget Function(BuildContext context, double t) construir;

  /// Multiplicador de la duración base.
  final double duracion;
}

/// Reproductor a pantalla completa, común a todos los tipos de Wrapped.
class ReproductorWrapped extends StatefulWidget {
  const ReproductorWrapped({
    required this.tipo,
    required this.year,
    required this.diapositivas,
    this.segundosPorDiapositiva = 7,
    this.musica,
    this.vistaPrevia,
    this.onPersonalizar,
    this.indiceInicial = 0,
    this.precargar,
    super.key,
  });

  final WrappedTipo tipo;
  final int year;
  final List<DiapositivaWrapped> diapositivas;
  final int segundosPorDiapositiva;

  /// Ruta de un archivo de audio o `asset:` seguido de la ruta del recurso.
  final String? musica;

  /// Texto de aviso cuando aún no ha llegado la fecha de publicación.
  final String? vistaPrevia;
  final void Function(int indiceActual)? onPersonalizar;
  final int indiceInicial;

  /// Carga previa de imágenes antes de empezar.
  final Future<void> Function(BuildContext context)? precargar;

  @override
  State<ReproductorWrapped> createState() => _ReproductorWrappedState();
}

class _ReproductorWrappedState extends State<ReproductorWrapped>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reloj;
  final _lienzo = GlobalKey();
  final _foco = FocusNode();
  late int _indice;
  bool _pausado = false;
  bool _listo = false;
  bool _terminado = false;

  AudioPlayer? _audio;
  bool _musicaActiva = true;
  String? _rutaMusica;

  /// Progreso de una exportación (null si no hay ninguna).
  String? _tarea;
  double _avanceTarea = 0;
  bool _cancelar = false;

  List<DiapositivaWrapped> get _slides => widget.diapositivas;

  @override
  void initState() {
    super.initState();
    _indice = widget.indiceInicial.clamp(0, _slides.length - 1);
    _reloj = AnimationController(vsync: this, duration: _duracionDe(_indice))
      ..addStatusListener((estado) {
        if (estado == AnimationStatus.completed && mounted && _tarea == null) {
          _siguiente(automatico: true);
        }
      });
    wrappedReproduciendo.value = true;
    unawaited(_preparar());
  }

  Duration _duracionDe(int i) => Duration(
      milliseconds:
          (widget.segundosPorDiapositiva * 1000 * _slides[i].duracion).round());

  Future<void> _preparar() async {
    await TipografiaWrapped.precargar();
    if (!mounted) return;
    try {
      await widget.precargar?.call(context);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _listo = true);
    _reloj.forward();
    unawaited(_iniciarMusica());
  }

  Future<void> _iniciarMusica() async {
    final fuente = widget.musica;
    if (fuente == null) {
      _musicaActiva = false;
      if (mounted) setState(() {});
      return;
    }
    try {
      _rutaMusica = await rutaDeAudio(fuente);
      if (_rutaMusica == null || !mounted) return;
      final audio = _audio = AudioPlayer();
      await audio.setFilePath(_rutaMusica!);
      await audio.setLoopMode(LoopMode.all);
      await audio.setVolume(0);
      if (!mounted) return;
      if (_musicaActiva && !_pausado) unawaited(audio.play());
      // Entrada suave.
      for (var i = 1; i <= 12 && mounted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 90));
        await audio.setVolume(.7 * i / 12);
      }
    } catch (_) {
      _musicaActiva = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _cancelar = true;
    _reloj.dispose();
    _foco.dispose();
    final audio = _audio;
    if (audio != null) {
      unawaited(() async {
        for (var i = 5; i >= 0; i--) {
          try {
            await audio.setVolume(.7 * i / 6);
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 60));
        }
        await audio.dispose();
      }());
    }
    wrappedReproduciendo.value = false;
    super.dispose();
  }

  void _ir(int nuevo) {
    if (nuevo < 0 || _tarea != null) return;
    if (nuevo >= _slides.length) {
      setState(() => _terminado = true);
      return;
    }
    setState(() {
      _indice = nuevo;
      _terminado = false;
    });
    _reloj
      ..duration = _duracionDe(nuevo)
      ..value = 0;
    if (!_pausado) _reloj.forward();
  }

  void _siguiente({bool automatico = false}) {
    if (automatico && _indice == _slides.length - 1) {
      setState(() => _terminado = true);
      return;
    }
    _ir(_indice + 1);
  }

  void _anterior() => _ir(_indice - 1);

  void _alternarPausa() {
    if (_tarea != null) return;
    if (_terminado) {
      _ir(0);
      return;
    }
    setState(() => _pausado = !_pausado);
    if (_pausado) {
      _reloj.stop();
      unawaited(_audio?.pause());
    } else {
      _reloj.forward();
      if (_musicaActiva) unawaited(_audio?.play());
    }
  }

  void _alternarMusica() {
    setState(() => _musicaActiva = !_musicaActiva);
    if (_musicaActiva && !_pausado) {
      unawaited(_audio?.play());
    } else {
      unawaited(_audio?.pause());
    }
  }

  KeyEventResult _tecla(FocusNode _, KeyEvent evento) {
    if (evento is! KeyDownEvent) return KeyEventResult.ignored;
    final k = evento.logicalKey;
    if (k == LogicalKeyboardKey.space) {
      _alternarPausa();
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _siguiente();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _anterior();
    } else if (k == LogicalKeyboardKey.keyM) {
      _alternarMusica();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // ------------------------------------------------------------ exportación

  Future<ui.Image?> _fotograma() async {
    await WidgetsBinding.instance.endOfFrame;
    final objeto = _lienzo.currentContext?.findRenderObject();
    if (objeto is! RenderRepaintBoundary) return null;
    return objeto.toImage(pixelRatio: 1080 / anchoLienzo);
  }

  Future<T?> _comoTarea<T>(String texto, Future<T> Function() trabajo) async {
    if (_tarea != null) return null;
    final estabaPausado = _pausado;
    final indice = _indice;
    _reloj.stop();
    unawaited(_audio?.pause());
    setState(() {
      _tarea = texto;
      _avanceTarea = 0;
      _cancelar = false;
    });
    try {
      return await trabajo();
    } finally {
      if (mounted) {
        setState(() {
          _tarea = null;
          _indice = indice;
          _pausado = estabaPausado;
        });
        _reloj.duration = _duracionDe(indice);
        if (!estabaPausado) {
          _reloj.forward();
          if (_musicaActiva) unawaited(_audio?.play());
        }
      }
    }
  }

  String _nombreArchivo(int i) =>
      '${(i + 1).toString().padLeft(2, '0')}-${_slides[i].id}.png';

  Future<Directory> _carpeta() async {
    final carpeta = AlmacenWrapped.carpetaDescargas(widget.tipo, widget.year);
    await carpeta.create(recursive: true);
    return carpeta;
  }

  Future<File?> _guardarImagen(int i, Directory carpeta) async {
    setState(() => _indice = i);
    _reloj.value = 1;
    await Future<void>.delayed(const Duration(milliseconds: 220));
    final imagen = await _fotograma();
    if (imagen == null) return null;
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();
    if (datos == null) return null;
    final archivo =
        File('${carpeta.path}${Platform.pathSeparator}${_nombreArchivo(i)}');
    await archivo.writeAsBytes(datos.buffer.asUint8List(), flush: true);
    return archivo;
  }

  Future<void> _descargarActual() async {
    final archivo = await _comoTarea('Guardando la imagen…', () async {
      final carpeta = await _carpeta();
      return _guardarImagen(_indice, carpeta);
    });
    if (archivo != null) {
      _avisar('Imagen guardada en ${archivo.parent.path}', archivo.parent);
    } else if (mounted && _tarea == null) {
      _avisar('No se pudo guardar la imagen.');
    }
  }

  Future<void> _descargarTodas() async {
    final carpeta = await _comoTarea('Guardando las imágenes…', () async {
      final carpeta = await _carpeta();
      for (var i = 0; i < _slides.length && !_cancelar; i++) {
        await _guardarImagen(i, carpeta);
        if (mounted) setState(() => _avanceTarea = (i + 1) / _slides.length);
      }
      return carpeta;
    });
    if (carpeta != null) {
      _avisar(
          '${_slides.length} imágenes guardadas en ${carpeta.path}', carpeta);
    }
  }

  Future<void> _exportarVideo() async {
    final ffmpeg = await buscarFfmpeg();
    if (ffmpeg == null) {
      _avisar('Para crear el vídeo hace falta ffmpeg instalado.');
      return;
    }
    const fps = 30;
    final salida = await _comoTarea('Creando el vídeo…', () async {
      final carpeta = await _carpeta();
      final ruta = '${carpeta.path}${Platform.pathSeparator}'
          'wrapped-${widget.tipo.clave}-${widget.year}.mp4';
      final total = [
        for (var i = 0; i < _slides.length; i++)
          (_duracionDe(i).inMilliseconds * fps / 1000).round()
      ];
      final fotogramas = total.fold<int>(0, (a, b) => a + b);
      final segundos = fotogramas / fps;
      final conMusica = _musicaActiva && _rutaMusica != null;
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
        '$fps',
        '-i',
        '-',
        if (conMusica) ...['-stream_loop', '-1', '-i', _rutaMusica!],
        '-c:v',
        'libx264',
        '-preset',
        'medium',
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
        ruta,
      ]);
      final errores = StringBuffer();
      unawaited(proceso.stderr
          .transform(const SystemEncoding().decoder)
          .forEach(errores.write));
      unawaited(proceso.stdout.drain<void>());
      var hechos = 0;
      try {
        for (var i = 0; i < _slides.length && !_cancelar; i++) {
          setState(() => _indice = i);
          _reloj.value = 0;
          await Future<void>.delayed(const Duration(milliseconds: 120));
          for (var f = 0; f < total[i] && !_cancelar; f++) {
            _reloj.value = f / total[i];
            final imagen = await _fotograma();
            if (imagen == null) continue;
            final datos =
                await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
            imagen.dispose();
            if (datos == null) continue;
            proceso.stdin.add(datos.buffer.asUint8List());
            await proceso.stdin.flush();
            hechos++;
            if (hechos % 6 == 0 && mounted) {
              setState(() => _avanceTarea = hechos / fotogramas);
            }
          }
        }
      } finally {
        await proceso.stdin.close();
      }
      final codigo = await proceso.exitCode;
      if (_cancelar) {
        try {
          await File(ruta).delete();
        } catch (_) {}
        return null;
      }
      if (codigo != 0) throw Exception(errores.toString());
      return File(ruta);
    }).catchError((Object _) => null);
    if (salida != null) {
      _avisar('Vídeo guardado en ${salida.path}', salida.parent);
    } else if (mounted && !_cancelar) {
      _avisar('No se pudo crear el vídeo.');
    }
  }

  void _avisar(String texto, [Directory? carpeta]) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(texto),
      persist: false,
      duration: const Duration(seconds: 6),
      action: carpeta == null
          ? null
          : SnackBarAction(
              label: 'Abrir carpeta',
              onPressed: () =>
                  unawaited(Process.run('explorer.exe', [carpeta.path])),
            ),
    ));
  }

  // ------------------------------------------------------------ interfaz

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_indice];
    return Focus(
      focusNode: _foco,
      autofocus: true,
      onKeyEvent: _tecla,
      child: Scaffold(
        backgroundColor: const Color(0xFF050508),
        body: LayoutBuilder(builder: (context, caja) {
          final altoTarjeta = (caja.maxHeight - 72).clamp(320.0, 4000.0);
          final anchoTarjeta = altoTarjeta * anchoLienzo / altoLienzo;
          return Stack(children: [
            // Fondo ambiental: la misma paleta, muy difuminada.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _reloj,
                builder: (context, _) => ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: Opacity(
                    opacity: .55,
                    child: FondoVivo(
                        paleta: slide.paleta,
                        t: _reloj.value,
                        semilla: _indice + 3),
                  ),
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: anchoTarjeta,
                height: altoTarjeta,
                child: _tarjeta(slide, anchoTarjeta),
              ),
            ),
            Positioned(
              left: (caja.maxWidth + anchoTarjeta) / 2 + 22,
              top: 0,
              bottom: 0,
              child: Center(child: _controles()),
            ),
            if (widget.vistaPrevia != null)
              Positioned(
                left: 24,
                top: 24,
                child: SizedBox(
                  width: ((caja.maxWidth - anchoTarjeta) / 2 - 48)
                      .clamp(0.0, 280.0),
                  child: _avisoVistaPrevia(widget.vistaPrevia!),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Text(
                'Espacio: pausa · ← →: moverse · M: música',
                textAlign: TextAlign.center,
                style: TipografiaWrapped.texto(size: 11, color: Colors.white38),
              ),
            ),
            if (_tarea != null) Positioned.fill(child: _panelTarea()),
          ]);
        }),
      ),
    );
  }

  Widget _avisoVistaPrevia(String texto) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.hourglass_top_rounded,
              color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style:
                    TipografiaWrapped.texto(size: 12, color: Colors.white70)),
          ),
        ]),
      );

  Widget _tarjeta(DiapositivaWrapped slide, double ancho) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ancho * .055),
      child: Stack(fit: StackFit.expand, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) =>
              d.localPosition.dx < ancho * .3 ? _anterior() : _siguiente(),
          onLongPressStart: (_) {
            if (!_pausado) _alternarPausa();
          },
          onLongPressEnd: (_) {
            if (_pausado) _alternarPausa();
          },
          child: FittedBox(
            fit: BoxFit.contain,
            child: RepaintBoundary(
              key: _lienzo,
              child: SizedBox(
                width: anchoLienzo,
                height: altoLienzo,
                child: !_listo
                    ? const ColoredBox(color: Color(0xFF07070C))
                    : AnimatedBuilder(
                        animation: _reloj,
                        builder: (context, _) => Material(
                          type: MaterialType.transparency,
                          child: Stack(fit: StackFit.expand, children: [
                            FondoVivo(
                                paleta: slide.paleta,
                                t: _reloj.value,
                                semilla: _indice + 3),
                            slide.construir(context, _reloj.value),
                          ]),
                        ),
                      ),
              ),
            ),
          ),
        ),
        // Barras de progreso, fuera de la imagen exportada.
        if (_tarea == null)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _reloj,
                builder: (context, _) => Row(children: [
                  for (var i = 0; i < _slides.length; i++)
                    Expanded(
                      child: Container(
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: i < _indice || _terminado
                              ? 1
                              : (i == _indice ? _reloj.value : 0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        if (!_listo)
          const Center(
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            ),
          ),
        if (_terminado && _tarea == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black),
                onPressed: () => _ir(0),
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Ver otra vez'),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _controles() {
    Widget boton(IconData icono, String texto, VoidCallback? accion,
            {bool activo = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Tooltip(
            message: texto,
            preferBelow: false,
            child: Material(
              color:
                  activo ? Colors.white : Colors.white.withValues(alpha: .09),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _tarea == null ? accion : null,
                child: SizedBox.square(
                  dimension: 46,
                  child: Icon(icono,
                      size: 21, color: activo ? Colors.black : Colors.white),
                ),
              ),
            ),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      boton(
          _terminado
              ? Icons.replay_rounded
              : (_pausado ? Icons.play_arrow_rounded : Icons.pause_rounded),
          _terminado ? 'Ver otra vez' : (_pausado ? 'Reanudar' : 'Pausar'),
          _alternarPausa),
      if (widget.musica != null)
        boton(
            _musicaActiva ? Icons.music_note_rounded : Icons.music_off_rounded,
            _musicaActiva ? 'Silenciar la música' : 'Poner la música',
            _alternarMusica),
      const SizedBox(height: 10),
      boton(Icons.download_rounded, 'Descargar esta imagen', _descargarActual),
      boton(Icons.collections_rounded, 'Descargar todas las imágenes',
          _descargarTodas),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Tooltip(
          message: 'Descargar el vídeo entero con música (MP4)',
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onPressed: _tarea == null ? _exportarVideo : null,
            icon: const Icon(Icons.movie_creation_rounded, size: 20),
            label: const Text('Descargar vídeo',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ),
      if (widget.onPersonalizar != null) ...[
        const SizedBox(height: 10),
        boton(Icons.tune_rounded, 'Personalizar',
            () => widget.onPersonalizar!(_indice)),
      ],
      const SizedBox(height: 10),
      boton(Icons.close_rounded, 'Cerrar',
          () => Navigator.of(context).maybePop()),
    ]);
  }

  Widget _panelTarea() => ColoredBox(
        color: const Color(0x99000000),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF16161F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_tarea!,
                  style: TipografiaWrapped.texto(
                      size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _avanceTarea == 0 ? null : _avanceTarea,
                  minHeight: 6,
                  color: Colors.white,
                  backgroundColor: Colors.white12,
                ),
              ),
              const SizedBox(height: 8),
              Text('${(_avanceTarea * 100).round()} %',
                  style:
                      TipografiaWrapped.texto(size: 12, color: Colors.white60)),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => _cancelar = true),
                child: const Text('Cancelar'),
              ),
            ]),
          ),
        ),
      );
}

/// Convierte `asset:ruta` en un archivo temporal reproducible y comprueba
/// que las rutas propias existen.
Future<String?> rutaDeAudio(String fuente) async {
  if (fuente.startsWith('asset:')) {
    final recurso = fuente.substring(6);
    final datos = await rootBundle.load(recurso);
    final nombre = recurso.split('/').last;
    final destino = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}todo-wrapped-$nombre');
    if (!destino.existsSync() || destino.lengthSync() != datos.lengthInBytes) {
      await destino.writeAsBytes(datos.buffer.asUint8List(), flush: true);
    }
    return destino.path;
  }
  return File(fuente).existsSync() ? fuente : null;
}

/// Localiza ffmpeg en el PATH o en la carpeta habitual de winget.
Future<String?> buscarFfmpeg() async {
  try {
    final r = await Process.run('where.exe', ['ffmpeg']);
    final linea = '${r.stdout}'.split(RegExp(r'[\r\n]+')).first.trim();
    if (r.exitCode == 0 && linea.isNotEmpty) return linea;
  } catch (_) {}
  final local = Platform.environment['LOCALAPPDATA'];
  if (local == null) return null;
  final paquetes = Directory('$local\\Microsoft\\WinGet\\Packages');
  if (!paquetes.existsSync()) return null;
  try {
    for (final d in paquetes.listSync().whereType<Directory>()) {
      if (!d.path.toLowerCase().contains('ffmpeg')) continue;
      for (final f in d.listSync(recursive: true).whereType<File>()) {
        if (f.path.toLowerCase().endsWith('\\bin\\ffmpeg.exe')) return f.path;
      }
    }
  } catch (_) {}
  return null;
}
