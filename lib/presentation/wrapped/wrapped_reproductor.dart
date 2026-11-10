import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../../application/wrapped/wrapped_modelo.dart';
import 'wrapped_piezas.dart';
import 'wrapped_render.dart';
import 'wrapped_video.dart';

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
    this.onMusica,
    this.firmaVideo,
    this.portadas = const [],
    super.key,
  });

  final WrappedTipo tipo;
  final int year;
  final List<DiapositivaWrapped> diapositivas;
  final int segundosPorDiapositiva;

  /// Valor de `musica` de los ajustes: id de una pista, ruta propia o
  /// `ninguna`. Sin valor suena la pista por defecto.
  final String? musica;

  /// Se llama al elegir otra pista en el reproductor, para guardarla.
  final ValueChanged<String>? onMusica;

  /// Firma de los datos y ajustes (sin la música). Si llega, el vídeo se va
  /// preparando solo en segundo plano.
  final String? firmaVideo;

  /// Portadas que usa el Wrapped, para retenerlas al generar el vídeo.
  final Iterable<String?> portadas;

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
  late String? _valorMusica = widget.musica;
  int _generacionAudio = 0;

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

  late final List<Duration> _duraciones =
      duracionesWrapped(_slides, widget.segundosPorDiapositiva);
  Duration _duracionDe(int i) => _duraciones[i];

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
    final generacion = ++_generacionAudio;
    final previo = _audio;
    _audio = null;
    if (previo != null) unawaited(previo.dispose());
    final fuente = fuenteMusicaWrapped(_valorMusica, widget.tipo);
    _rutaMusica = null;
    if (fuente == null) {
      if (mounted) setState(() {});
      _prepararVideo();
      return;
    }
    try {
      final ruta = await rutaDeAudio(fuente);
      if (ruta == null || !mounted || generacion != _generacionAudio) return;
      _rutaMusica = ruta;
      _prepararVideo();
      final audio = _audio = AudioPlayer();
      await audio.setFilePath(ruta);
      await audio.setLoopMode(LoopMode.all);
      await audio.setVolume(0);
      if (!mounted || generacion != _generacionAudio) return;
      if (_musicaActiva && !_pausado && _tarea == null) {
        unawaited(audio.play());
      }
      // Entrada suave.
      for (var i = 1; i <= 12 && mounted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 90));
        if (generacion != _generacionAudio) return;
        await audio.setVolume(.7 * i / 12);
      }
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  /// Cambia de pista al momento y la guarda en los ajustes.
  void _elegirMusica(String valor) {
    setState(() {
      _valorMusica = valor;
      _musicaActiva = valor != 'ninguna';
    });
    widget.onMusica?.call(valor);
    unawaited(_iniciarMusica());
  }

  // ------------------------------------------------------------ vídeo

  String? get _firmaCompleta => widget.firmaVideo == null
      ? null
      : firmaVideoWrapped(
          widget.firmaVideo!,
          _rutaMusica == null
              ? null
              : fuenteMusicaWrapped(_valorMusica, widget.tipo),
          widget.segundosPorDiapositiva,
          _slides);

  /// Arranca (o reutiliza) la generación del vídeo en segundo plano.
  TrabajoVideo? _prepararVideo({bool prisa = false}) {
    final firma = _firmaCompleta;
    if (firma == null || !mounted) return null;
    return VideosWrapped.preparar(
      clave: '${widget.tipo.clave}-${widget.year}',
      firma: firma,
      diapositivas: _slides,
      duraciones: [for (var i = 0; i < _slides.length; i++) _duracionDe(i)],
      portadas: widget.portadas,
      rutaMusica: _rutaMusica,
      vista: View.of(context),
      prisa: prisa,
    );
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

  /// Lienzo independiente del que se ve: no espera al refresco de pantalla.
  LienzoFueraDePantalla _lienzoExportacion() =>
      LienzoFueraDePantalla(vista: View.of(context), diapositivas: _slides);

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

  Future<File?> _guardarImagen(
      LienzoFueraDePantalla lienzo, int i, Directory carpeta) async {
    // El primer dibujo pide las portadas que falten; el segundo ya las tiene.
    (await lienzo.capturar(i, 1)).dispose();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final imagen = await lienzo.capturar(i, 1);
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
      final lienzo = _lienzoExportacion();
      try {
        return await _guardarImagen(lienzo, _indice, carpeta);
      } finally {
        lienzo.dispose();
      }
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
      final lienzo = _lienzoExportacion();
      try {
        for (var i = 0; i < _slides.length && !_cancelar; i++) {
          await _guardarImagen(lienzo, i, carpeta);
          if (mounted) setState(() => _avanceTarea = (i + 1) / _slides.length);
        }
      } finally {
        lienzo.dispose();
      }
      return carpeta;
    });
    if (carpeta != null) {
      _avisar(
          '${_slides.length} imágenes guardadas en ${carpeta.path}', carpeta);
    }
  }

  Future<void> _exportarVideo() async {
    final vista = View.of(context);
    if (await buscarFfmpeg() == null) {
      _avisar('Para crear el vídeo hace falta ffmpeg instalado.');
      return;
    }
    final trabajo = _prepararVideo(prisa: true) ??
        VideosWrapped.preparar(
          clave: '${widget.tipo.clave}-${widget.year}',
          firma: VideosWrapped.firmaDe(
              [for (final d in _slides) d.id, _rutaMusica, DateTime.now().day]),
          diapositivas: _slides,
          duraciones: [for (var i = 0; i < _slides.length; i++) _duracionDe(i)],
          portadas: widget.portadas,
          rutaMusica: _rutaMusica,
          vista: vista,
          prisa: true,
        );
    Future<File?> copiar() async {
      final hecho = await trabajo.resultado;
      if (hecho == null) return null;
      final carpeta = await _carpeta();
      final destino = File('${carpeta.path}${Platform.pathSeparator}'
          'wrapped-${widget.tipo.clave}-${widget.year}.mp4');
      return hecho.copy(destino.path);
    }

    File? salida;
    if (trabajo.terminado) {
      salida = await copiar();
    } else {
      void avance() {
        if (mounted) setState(() => _avanceTarea = trabajo.progreso.value);
      }

      trabajo.progreso.addListener(avance);
      salida = await _comoTarea<File?>('Terminando el vídeo…', () async {
        final espera = Completer<File?>();
        unawaited(copiar()
            .then(espera.complete, onError: (_) => espera.complete(null)));
        // «Cancelar» solo cierra el aviso: el vídeo sigue haciéndose.
        while (!espera.isCompleted && !_cancelar) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
        return espera.isCompleted ? await espera.future : null;
      });
      trabajo.progreso.removeListener(avance);
      if (_cancelar) {
        trabajo.prisa = false;
        _avisar('El vídeo se sigue preparando en segundo plano.');
        return;
      }
    }
    if (salida != null) {
      _avisar('Vídeo guardado en ${salida.path}', salida.parent);
    } else if (mounted) {
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
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: PopupMenuButton<String>(
          tooltip: 'Música',
          color: const Color(0xFF1B1B26),
          position: PopupMenuPosition.under,
          onSelected: _elegirMusica,
          itemBuilder: (_) {
            final actual = pistaWrapped(_valorMusica)?.id ??
                ((_valorMusica ?? '').isEmpty
                    ? pistaPorDefectoDe(widget.tipo)
                    : (_valorMusica!.toLowerCase() == 'ninguna'
                        ? 'ninguna'
                        : 'propia'));
            PopupMenuItem<String> item(
                    String valor, String titulo, String? sub) =>
                PopupMenuItem(
                  value: valor,
                  child: Row(children: [
                    Icon(
                        actual == valor
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 18,
                        color: Colors.white),
                    const SizedBox(width: 10),
                    Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                          if (sub != null)
                            Text(sub,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                        ]),
                  ]),
                );
            return [
              for (final p in pistasWrapped) item(p.id, p.nombre, p.estilo),
              if (actual == 'propia') item(_valorMusica!, 'Tu música', null),
              item('ninguna', 'Sin música', null),
            ];
          },
          child: Material(
            color: Colors.white.withValues(alpha: .09),
            shape: const CircleBorder(),
            child: SizedBox.square(
              dimension: 46,
              child: Icon(
                  _rutaMusica != null && _musicaActiva
                      ? Icons.music_note_rounded
                      : Icons.music_off_rounded,
                  size: 21,
                  color: Colors.white),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      boton(Icons.download_rounded, 'Descargar esta imagen', _descargarActual),
      boton(Icons.collections_rounded, 'Descargar todas las imágenes',
          _descargarTodas),
      boton(Icons.movie_creation_outlined,
          'Descargar el vídeo entero con música', _exportarVideo),
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
