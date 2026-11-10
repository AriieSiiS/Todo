import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'wrapped_piezas.dart';
import 'wrapped_reproductor.dart';

/// Dibuja las diapositivas fuera de la pantalla, sin esperar al refresco del
/// monitor: cada fotograma se construye, se pinta y se rasteriza en cuanto se
/// pide. Así el vídeo y las imágenes se generan mucho más rápido y sin tocar
/// lo que se ve en el reproductor.
class LienzoFueraDePantalla {
  LienzoFueraDePantalla({
    required ui.FlutterView vista,
    required this.diapositivas,
    this.pixelRatio = 1080 / anchoLienzo,
  }) {
    _limite = RenderRepaintBoundary();
    _vistaRender = RenderView(
      view: vista,
      configuration: ViewConfiguration(
        logicalConstraints:
            BoxConstraints.tight(const Size(anchoLienzo, altoLienzo)),
        devicePixelRatio: pixelRatio,
      ),
      child: RenderPositionedBox(alignment: Alignment.topLeft, child: _limite),
    );
    _pipeline.rootNode = _vistaRender;
    _vistaRender.prepareInitialFrame();
    _raiz = RenderObjectToWidgetAdapter<RenderBox>(
      container: _limite,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(anchoLienzo, altoLienzo)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            type: MaterialType.transparency,
            child: SizedBox(
              width: anchoLienzo,
              height: altoLienzo,
              child: ValueListenableBuilder<(int, double)>(
                valueListenable: _estado,
                builder: (context, v, _) {
                  final slide = diapositivas[v.$1];
                  return Stack(fit: StackFit.expand, children: [
                    FondoVivo(paleta: slide.paleta, t: v.$2, semilla: v.$1 + 3),
                    slide.construir(context, v.$2),
                  ]);
                },
              ),
            ),
          ),
        ),
      ),
    ).attachToRenderTree(_build);
  }

  final List<DiapositivaWrapped> diapositivas;
  final double pixelRatio;
  final _estado = ValueNotifier<(int, double)>((0, 0));
  final _pipeline = PipelineOwner();
  final _build = BuildOwner(focusManager: FocusManager());
  late final RenderRepaintBoundary _limite;
  late final RenderView _vistaRender;
  late final RenderObjectToWidgetElement<RenderBox> _raiz;

  /// Prepara el fotograma [t] de la diapositiva [indice] y devuelve su imagen.
  ///
  /// El dibujo se fija al llamar, así que se puede pedir el siguiente
  /// fotograma antes de que termine la rasterización del anterior.
  Future<ui.Image> capturar(int indice, double t) {
    _estado.value = (indice, t);
    _build
      ..buildScope(_raiz)
      ..finalizeTree();
    _pipeline
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    return _limite.toImage(pixelRatio: pixelRatio);
  }

  void dispose() {
    RenderObjectToWidgetAdapter<RenderBox>(container: _limite)
        .attachToRenderTree(_build, _raiz);
    _build.finalizeTree();
    _estado.dispose();
  }
}
