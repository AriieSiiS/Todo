import 'package:flutter/widgets.dart';

/// Amplía toda la interfaz en pantalla completa, al estilo de una vista de
/// salón: la app se maqueta como en una pantalla algo más pequeña y se dibuja
/// a escala, de modo que textos, tarjetas e iconos crecen sin perder nitidez.
///
/// Fuera de pantalla completa devuelve la interfaz tal cual. El subárbol
/// conserva su estado al cambiar de modo gracias a una clave global.
class InterfazAmpliada extends StatefulWidget {
  const InterfazAmpliada({
    super.key,
    required this.activa,
    required this.child,
  });

  final bool activa;
  final Widget child;

  /// Escala según el alto disponible: unos 1,1 en 1080p y 1,25 en 1440p.
  static double escalaPara(Size tamano) =>
      (tamano.height / 1150).clamp(1.1, 1.3).toDouble();

  @override
  State<InterfazAmpliada> createState() => _InterfazAmpliadaState();
}

class _InterfazAmpliadaState extends State<InterfazAmpliada> {
  final GlobalKey _claveContenido = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final contenido = KeyedSubtree(key: _claveContenido, child: widget.child);
    if (!widget.activa) return contenido;
    final media = MediaQuery.of(context);
    final escala = InterfazAmpliada.escalaPara(media.size);
    final tamano = media.size / escala;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: tamano,
        child: MediaQuery(
          data: media.copyWith(
            size: tamano,
            devicePixelRatio: media.devicePixelRatio * escala,
            padding: media.padding / escala,
            viewPadding: media.viewPadding / escala,
            viewInsets: media.viewInsets / escala,
          ),
          child: contenido,
        ),
      ),
    );
  }
}
