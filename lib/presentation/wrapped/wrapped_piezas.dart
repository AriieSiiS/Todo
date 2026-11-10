import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lienzo lógico de cada diapositiva; se exporta a 1080 × 1920.
const anchoLienzo = 360.0;
const altoLienzo = 640.0;

// ---------------------------------------------------------------- tipografía

/// Tipografías del Wrapped. En las pruebas se sustituyen por fuentes locales.
class TipografiaWrapped {
  static bool usarFuentesLocales = false;

  static TextStyle titular(
      {double size = 40,
      FontWeight weight = FontWeight.w800,
      Color color = Colors.white,
      double height = .95,
      double spacing = -1.2}) {
    if (usarFuentesLocales) {
      return TextStyle(
          fontFamily: 'Titular',
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          letterSpacing: spacing);
    }
    return GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: spacing);
  }

  static TextStyle serif(
      {double size = 20,
      FontWeight weight = FontWeight.w500,
      Color color = Colors.white,
      FontStyle style = FontStyle.italic,
      double height = 1.25}) {
    if (usarFuentesLocales) {
      return TextStyle(
          fontFamily: 'Serif',
          fontSize: size,
          fontWeight: weight,
          color: color,
          fontStyle: style,
          height: height);
    }
    return GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontStyle: style,
        height: height);
  }

  static TextStyle texto(
      {double size = 14,
      FontWeight weight = FontWeight.w500,
      Color color = Colors.white,
      double height = 1.3,
      double spacing = 0}) {
    if (usarFuentesLocales) {
      return TextStyle(
          fontFamily: 'Texto',
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: height,
          letterSpacing: spacing);
    }
    return GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: spacing);
  }

  static TextStyle etiqueta({Color color = Colors.white70, double size = 11}) =>
      texto(size: size, weight: FontWeight.w800, color: color, spacing: 2.6);

  /// Espera a que estén cargadas antes de reproducir o exportar.
  static Future<void> precargar() async {
    if (usarFuentesLocales) return;
    titular();
    titular(weight: FontWeight.w600);
    serif();
    serif(style: FontStyle.normal, weight: FontWeight.w600);
    texto();
    texto(weight: FontWeight.w800);
    texto(weight: FontWeight.w700);
    try {
      await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}

// ---------------------------------------------------------------- animación

/// Avance suavizado de [t] entre [desde] y [hasta] (0 → 1).
double tramo(double t, double desde, double hasta,
    [Curve curva = Curves.easeOutCubic]) {
  if (hasta <= desde) return t >= hasta ? 1 : 0;
  final x = ((t - desde) / (hasta - desde)).clamp(0.0, 1.0);
  return curva.transform(x);
}

/// Aparece con fundido, desplazamiento y un leve desenfoque.
class Aparece extends StatelessWidget {
  const Aparece({
    required this.t,
    required this.desde,
    required this.child,
    this.duracion = .16,
    this.dy = 26,
    this.dx = 0,
    this.escala = 1,
    super.key,
  });
  final double t, desde, duracion, dy, dx, escala;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = tramo(t, desde, desde + duracion);
    if (v <= 0) return Opacity(opacity: 0, child: child);
    final s = escala == 1 ? 1.0 : escala + (1 - escala) * v;
    return Opacity(
      opacity: v,
      child: Transform.translate(
        offset: Offset(dx * (1 - v), dy * (1 - v)),
        child: s == 1 ? child : Transform.scale(scale: s, child: child),
      ),
    );
  }
}

/// Texto que se revela palabra a palabra.
class TextoRevelado extends StatelessWidget {
  const TextoRevelado(this.texto,
      {required this.t,
      required this.desde,
      required this.estilo,
      this.paso = .025,
      this.alineacion = TextAlign.center,
      super.key});
  final String texto;
  final double t, desde, paso;
  final TextStyle estilo;
  final TextAlign alineacion;

  @override
  Widget build(BuildContext context) {
    final palabras = texto.split(' ');
    return Wrap(
      alignment: switch (alineacion) {
        TextAlign.center => WrapAlignment.center,
        TextAlign.right || TextAlign.end => WrapAlignment.end,
        _ => WrapAlignment.start,
      },
      children: [
        for (var i = 0; i < palabras.length; i++)
          Aparece(
            t: t,
            desde: desde + i * paso,
            duracion: .12,
            dy: 14,
            child: Text('${palabras[i]}${i < palabras.length - 1 ? ' ' : ''}',
                style: estilo),
          ),
      ],
    );
  }
}

/// Número que cuenta hacia arriba.
class Contador extends StatelessWidget {
  const Contador({
    required this.t,
    required this.desde,
    required this.valor,
    required this.estilo,
    this.duracion = .3,
    this.formato,
    super.key,
  });
  final double t, desde, duracion;
  final num valor;
  final TextStyle estilo;
  final String Function(num)? formato;

  @override
  Widget build(BuildContext context) {
    final v = tramo(t, desde, desde + duracion, Curves.easeOutExpo);
    final actual = valor is int ? (valor * v).round() : valor * v;
    return Opacity(
      opacity: tramo(t, desde, desde + .05),
      child: Text(formato?.call(actual) ?? miles(actual.round()),
          style: estilo, maxLines: 1),
    );
  }
}

// ---------------------------------------------------------------- formatos

String miles(int n) {
  final negativo = n < 0;
  final s = n.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return '${negativo ? '-' : ''}$out';
}

String duracionLarga(int segundos) {
  final minutos = (segundos / 60).round();
  if (minutos < 60) return '$minutos min';
  final h = minutos ~/ 60;
  final m = minutos % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String decimal(double valor, [int digitos = 1]) {
  final redondo = valor.roundToDouble();
  if ((valor - redondo).abs() < .05) return redondo.toInt().toString();
  return valor.toStringAsFixed(digitos).replaceAll('.', ',');
}

const mesesLargos = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre'
];
const diasSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo'
];

String fechaLarga(DateTime d, {bool conDia = false}) =>
    '${conDia ? '${diasSemana[d.weekday - 1]} ' : ''}${d.day} de ${mesesLargos[d.month - 1]}';

String capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ---------------------------------------------------------------- portadas

/// Imagen de una portada guardada como ruta local, recurso o URL.
ImageProvider? proveedorPortada(String? fuente, {int ancho = 700}) {
  final valor = fuente?.trim();
  if (valor == null || valor.isEmpty) return null;
  ImageProvider base;
  if (valor.startsWith('assets/')) {
    base = AssetImage(valor);
  } else if (RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(valor) ||
      valor.startsWith(r'\\') ||
      valor.startsWith('/')) {
    final archivo = File(valor);
    if (!archivo.existsSync()) return null;
    base = FileImage(archivo);
  } else if (valor.startsWith('http')) {
    base = NetworkImage(valor);
  } else {
    return null;
  }
  return ResizeImage(base, width: ancho, allowUpscaling: false);
}

/// Portada con sombra, brillo y una alternativa tipográfica si no hay imagen.
class Portada extends StatelessWidget {
  const Portada({
    required this.fuente,
    required this.titulo,
    this.ancho,
    this.alto,
    this.radio = 6,
    this.sombra = true,
    this.autor,
    super.key,
  });
  final String? fuente;
  final String titulo;
  final String? autor;
  final double? ancho, alto;
  final double radio;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final proveedor = proveedorPortada(fuente);
    Widget alternativa() => _PortadaTipografica(titulo: titulo, autor: autor);
    final imagen = proveedor == null
        ? alternativa()
        : Image(
            image: proveedor,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => alternativa(),
          );
    final cuerpo = Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        boxShadow: sombra
            ? const [
                BoxShadow(
                    color: Color(0x99000000),
                    blurRadius: 24,
                    offset: Offset(0, 12)),
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 2)),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radio),
        child: Stack(fit: StackFit.expand, children: [
          imagen,
          // Lomo y reflejo sutiles, como un libro de verdad.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0, .035, .07, .5, 1],
                colors: [
                  Color(0x40000000),
                  Color(0x22FFFFFF),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0x14FFFFFF),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
    return cuerpo;
  }
}

class _PortadaTipografica extends StatelessWidget {
  const _PortadaTipografica({required this.titulo, this.autor});
  final String titulo;
  final String? autor;

  @override
  Widget build(BuildContext context) {
    final semilla = titulo.codeUnits.fold<int>(7, (s, c) => s * 31 + c);
    final tono = (semilla % 360).toDouble();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, tono, .45, .32).toColor(),
            HSLColor.fromAHSL(1, (tono + 40) % 360, .5, .16).toColor(),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 120,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titulo,
                      maxLines: 5,
                      style: TipografiaWrapped.serif(
                          size: 18, style: FontStyle.normal)),
                  if (autor != null) ...[
                    const SizedBox(height: 6),
                    Text(autor!,
                        style: TipografiaWrapped.texto(
                            size: 9, color: Colors.white70)),
                  ],
                ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- colores

/// Color más vivo y representativo de cada portada, calculado una vez.
class ColoresPortada {
  static final Map<String, Color?> _cache = {};

  static Color? deCache(String? fuente) =>
      fuente == null ? null : _cache[fuente];

  static Future<void> precargar(Iterable<String?> fuentes) async {
    await Future.wait([
      for (final f in fuentes.whereType<String>().toSet())
        if (!_cache.containsKey(f)) _calcular(f),
    ]);
  }

  static Future<void> _calcular(String fuente) async {
    final proveedor = proveedorPortada(fuente, ancho: 40);
    if (proveedor == null) {
      _cache[fuente] = null;
      return;
    }
    try {
      final completer = Completer<ui.Image>();
      final stream = proveedor.resolve(ImageConfiguration.empty);
      late final ImageStreamListener escucha;
      escucha = ImageStreamListener((info, _) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(escucha);
      }, onError: (e, _) {
        if (!completer.isCompleted) completer.completeError(e);
        stream.removeListener(escucha);
      });
      stream.addListener(escucha);
      final imagen = await completer.future.timeout(const Duration(seconds: 6));
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (datos == null) {
        _cache[fuente] = null;
        return;
      }
      // Se agrupan los píxeles por tono y se elige el grupo con más peso,
      // premiando la saturación para huir de grises.
      final pesos = List<double>.filled(24, 0);
      final sumas = List.generate(24, (_) => [0.0, 0.0, 0.0]);
      for (var i = 0; i + 3 < datos.lengthInBytes; i += 4) {
        final r = datos.getUint8(i) / 255;
        final g = datos.getUint8(i + 1) / 255;
        final b = datos.getUint8(i + 2) / 255;
        final hsl = HSLColor.fromColor(Color.fromARGB(
            255, (r * 255).round(), (g * 255).round(), (b * 255).round()));
        if (hsl.lightness < .12 || hsl.lightness > .9) continue;
        final peso = math.pow(hsl.saturation, 1.6) *
            (1 - (hsl.lightness - .5).abs() * 1.4);
        if (peso <= 0) continue;
        final cubo = (hsl.hue / 15).floor() % 24;
        pesos[cubo] += peso;
        sumas[cubo][0] += r * peso;
        sumas[cubo][1] += g * peso;
        sumas[cubo][2] += b * peso;
      }
      var mejor = 0;
      for (var i = 1; i < 24; i++) {
        if (pesos[i] > pesos[mejor]) mejor = i;
      }
      if (pesos[mejor] < .4) {
        _cache[fuente] = null;
        return;
      }
      final p = pesos[mejor];
      final color = Color.fromARGB(
          255,
          (sumas[mejor][0] / p * 255).round().clamp(0, 255),
          (sumas[mejor][1] / p * 255).round().clamp(0, 255),
          (sumas[mejor][2] / p * 255).round().clamp(0, 255));
      // Se asegura un color con presencia sobre fondo oscuro.
      final hsl = HSLColor.fromColor(color);
      _cache[fuente] = hsl
          .withSaturation(math.max(hsl.saturation, .55))
          .withLightness(hsl.lightness.clamp(.42, .6))
          .toColor();
    } catch (_) {
      _cache[fuente] = null;
    }
  }
}

/// Paleta de una diapositiva: dos colores de fondo y un acento.
class Paleta {
  const Paleta(this.a, this.b, this.acento);
  final Color a, b, acento;

  static const aurora =
      Paleta(Color(0xFF6D28D9), Color(0xFF0EA5E9), Color(0xFFA7F3D0));
  static const atardecer =
      Paleta(Color(0xFFE11D48), Color(0xFFF59E0B), Color(0xFFFFE4B5));
  static const bosque =
      Paleta(Color(0xFF047857), Color(0xFF84CC16), Color(0xFFD9F99D));
  static const oceano =
      Paleta(Color(0xFF1D4ED8), Color(0xFF06B6D4), Color(0xFFBAE6FD));
  static const brasa =
      Paleta(Color(0xFFB91C1C), Color(0xFF7C2D12), Color(0xFFFDBA74));
  static const orquidea =
      Paleta(Color(0xFFC026D3), Color(0xFF4F46E5), Color(0xFFF5D0FE));
  static const oro =
      Paleta(Color(0xFFB45309), Color(0xFFEAB308), Color(0xFFFEF08A));
  static const noche =
      Paleta(Color(0xFF1E1B4B), Color(0xFF7C3AED), Color(0xFFC4B5FD));

  static const ciclo = [
    aurora,
    atardecer,
    oceano,
    orquidea,
    bosque,
    brasa,
    oro,
    noche
  ];
  static const porNombre = {
    'aurora': aurora,
    'atardecer': atardecer,
    'bosque': bosque,
    'oceano': oceano,
    'océano': oceano,
    'brasa': brasa,
    'orquidea': orquidea,
    'orquídea': orquidea,
    'oro': oro,
    'noche': noche,
  };

  /// Paleta derivada de un color de portada.
  factory Paleta.desde(Color color) {
    final hsl = HSLColor.fromColor(color);
    return Paleta(
      hsl.withLightness(.38).toColor(),
      hsl.withHue((hsl.hue + 38) % 360).withLightness(.3).toColor(),
      hsl.withLightness(.8).withSaturation(.9).toColor(),
    );
  }
}

/// Fondo vivo: manchas de color que se desplazan despacio y grano fino.
class FondoVivo extends StatelessWidget {
  const FondoVivo(
      {required this.paleta,
      required this.t,
      required this.semilla,
      super.key});
  final Paleta paleta;
  final double t;
  final int semilla;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PintorFondo(paleta, t, semilla),
      child: const SizedBox.expand(),
    );
  }
}

class _PintorFondo extends CustomPainter {
  _PintorFondo(this.paleta, this.t, this.semilla);
  final Paleta paleta;
  final double t;
  final int semilla;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF07070C));
    final r = math.Random(semilla);
    final manchas = [
      (paleta.a, .95),
      (paleta.b, .85),
      (paleta.a, .6),
      (paleta.b, .55),
    ];
    for (var i = 0; i < manchas.length; i++) {
      final fase = r.nextDouble() * math.pi * 2;
      final vx = .5 + r.nextDouble();
      final cx =
          size.width * (.5 + .42 * math.sin(fase + t * math.pi * vx + i * 1.7));
      final cy = size.height *
          (.5 + .4 * math.cos(fase * 1.3 + t * math.pi * .8 * vx + i));
      final radio = size.width * (.75 + .25 * r.nextDouble());
      canvas.drawCircle(
        Offset(cx, cy),
        radio,
        Paint()
          ..shader = RadialGradient(colors: [
            manchas[i].$1.withValues(alpha: .78 * manchas[i].$2),
            manchas[i].$1.withValues(alpha: 0),
          ]).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: radio)),
      );
    }
    // Viñeta para dar profundidad y legibilidad.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          radius: .95,
          colors: [Color(0x00000000), Color(0x8C000000)],
        ).createShader(Offset.zero & size),
    );
    // Grano fijo (no parpadea entre fotogramas).
    final grano = Paint()..color = const Color(0x0DFFFFFF);
    final g = math.Random(semilla * 7 + 1);
    for (var i = 0; i < 900; i++) {
      canvas.drawRect(
          Rect.fromLTWH(g.nextDouble() * size.width,
              g.nextDouble() * size.height, .8, .8),
          grano);
    }
  }

  @override
  bool shouldRepaint(_PintorFondo old) =>
      old.t != t || old.paleta != paleta || old.semilla != semilla;
}

/// Pequeña insignia redondeada.
class Insignia extends StatelessWidget {
  const Insignia(this.texto,
      {this.color = Colors.white, this.relleno = false, super.key});
  final String texto;
  final Color color;
  final bool relleno;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: relleno ? color : color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: color.withValues(alpha: relleno ? 1 : .35)),
        ),
        child: Text(texto,
            style: TipografiaWrapped.texto(
                size: 10.5,
                weight: FontWeight.w800,
                color: relleno ? Colors.black : color,
                spacing: .6)),
      );
}

/// Estrellas de valoración (0-5, con medias).
class Estrellas extends StatelessWidget {
  const Estrellas(this.valor,
      {this.tamano = 18, this.color = const Color(0xFFFFD166), super.key});
  final double valor;
  final double tamano;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              valor >= i
                  ? Icons.star_rounded
                  : (valor >= i - .5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded),
              size: tamano,
              color: valor >= i - .5 ? color : Colors.white30,
            ),
        ],
      );
}
