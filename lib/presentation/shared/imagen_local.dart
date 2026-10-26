import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Imagen de archivo local decodificada al tamaño que ocupa en pantalla.
///
/// Las portadas y fotos originales pueden ser mucho mayores que su hueco; sin
/// reducirlas, cada una ocupa en memoria su tamaño completo. Aquí el ancho
/// decodificado sale del hueco disponible por la densidad de píxeles, redondeado
/// a múltiplos de 128 para no volver a decodificar por cambios mínimos. En la
/// ficha de detalle el hueco es mayor y, por tanto, también la decodificación.
/// Con un hueco sin límite (por ejemplo, un visor con zoom) se usa `escala`
/// sobre el tamaño de la ventana.
class ImagenLocal extends StatelessWidget {
  const ImagenLocal(
    this.ruta, {
    super.key,
    this.fit = BoxFit.cover,
    this.gaplessPlayback = false,
    this.errorBuilder,
    this.escala = 1,
  });

  final String ruta;
  final BoxFit fit;
  final bool gaplessPlayback;
  final ImageErrorWidgetBuilder? errorBuilder;
  final double escala;

  static const int _paso = 128;
  static const int _maximo = 2560;

  @override
  Widget build(BuildContext context) {
    final pixeles = MediaQuery.devicePixelRatioOf(context);
    final ventana = MediaQuery.sizeOf(context);
    return LayoutBuilder(
      builder: (context, restricciones) {
        final ancho = restricciones.hasBoundedWidth
            ? restricciones.maxWidth
            : ventana.width;
        final alto = restricciones.hasBoundedHeight
            ? restricciones.maxHeight
            : ventana.height;
        // El lado mayor del hueco manda: así la imagen nunca se ve borrosa.
        // Con `cover` una imagen apaisada en un hueco vertical se amplía más.
        final margen = fit == BoxFit.cover ? 1.5 : 1;
        final lado = math.max(ancho, alto) * pixeles * escala * margen;
        final decodificado =
            ((lado / _paso).ceil() * _paso).clamp(_paso, _maximo).toInt();
        return Image.file(
          File(ruta),
          fit: fit,
          gaplessPlayback: gaplessPlayback,
          cacheWidth: decodificado,
          errorBuilder: errorBuilder,
        );
      },
    );
  }
}
