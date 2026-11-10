import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/wrapped/resumen_libros.dart';
import '../../domain/models.dart';
import 'wrapped_piezas.dart';
import 'wrapped_reproductor.dart';

/// Identificadores y nombres de las diapositivas del Wrapped de libros, en
/// orden. Sirven para `ocultar` en los ajustes y en `docs/WRAPPED.md`.
const diapositivasDeLibros = <String, String>{
  'inicio': 'Portada',
  'terminados': 'Libros terminados',
  'paginas': 'Páginas',
  'kindle': 'Tiempo en el Kindle',
  'calendario': 'Calendario y racha',
  'dia-record': 'Tu día más lector',
  'reloj': 'Cuándo lees',
  'meses': 'Mes a mes',
  'top': 'Los que más tiempo te llevaron',
  'autor': 'Autor del año',
  'sagas': 'Sagas',
  'generos': 'Géneros',
  'epocas': 'Viaje en el tiempo',
  'curiosidades': 'Datos curiosos',
  'notas': 'Tus notas',
  'propositos': 'Propósitos',
  'cita': 'Cita del año',
  'libro-del-ano': 'Libro del año',
  'perfil': 'Perfil lector',
  'lo-que-viene': 'Lo que viene',
  'resumen': 'Resumen final',
};

/// Construye las diapositivas a partir del resumen ya calculado.
List<DiapositivaWrapped> diapositivasLibros(ResumenLibros r) {
  final ocultas = r.ajustes.ocultar.toSet();
  final nombrePaleta = r.ajustes.paleta?.toLowerCase().trim();
  final fija = Paleta.porNombre[nombrePaleta];
  var ciclo = fija == null ? 0 : Paleta.ciclo.indexOf(fija).clamp(0, 99);

  Paleta paleta([LibraryItem? destacado, String? fuente]) {
    if (fija == null && nombrePaleta != 'ciclo') {
      final color = ColoresPortada.deCache(destacado?.coverUrl ?? fuente);
      if (color != null) {
        ciclo++;
        return Paleta.desde(color);
      }
    }
    return Paleta.ciclo[ciclo++ % Paleta.ciclo.length];
  }

  final lista = <DiapositivaWrapped>[];
  void anadir(String id, Paleta p, Widget Function(BuildContext, double) f,
      {double duracion = 1}) {
    if (ocultas.contains(id)) return;
    lista.add(DiapositivaWrapped(
        id: id,
        nombre: diapositivasDeLibros[id] ?? id,
        paleta: p,
        construir: f,
        duracion: duracion));
  }

  if (!r.hayDatos) {
    anadir('inicio', Paleta.noche, (c, t) => _SinDatos(r: r, t: t));
    return lista;
  }

  anadir('inicio', paleta(r.portada), (c, t) => _Inicio(r: r, t: t),
      duracion: .9);
  if (r.terminados.isNotEmpty) {
    anadir('terminados', paleta(r.terminados.last),
        (c, t) => _Terminados(r: r, t: t));
  }
  if (r.paginas > 0) {
    anadir('paginas', paleta(), (c, t) => _Paginas(r: r, t: t));
  }
  if (r.hayKindle) {
    anadir('kindle', paleta(r.porTiempo.first.libro),
        (c, t) => _Kindle(r: r, t: t));
    anadir('calendario', paleta(), (c, t) => _Calendario(r: r, t: t),
        duracion: 1.15);
    if (r.diaRecord != null) {
      anadir('dia-record', paleta(r.libroDiaRecord),
          (c, t) => _DiaRecord(r: r, t: t));
    }
    anadir('reloj', Paleta.noche, (c, t) => _Reloj(r: r, t: t));
  }
  if (r.terminados.length >= 3) {
    anadir('meses', paleta(), (c, t) => _Meses(r: r, t: t), duracion: 1.1);
  }
  if (r.porTiempo.where((e) => e.segundos >= 900).length >= 2) {
    anadir('top', paleta(r.porTiempo.first.libro), (c, t) => _Top(r: r, t: t),
        duracion: 1.15);
  }
  if (r.autores.isNotEmpty && r.autores.first.libros.length >= 2) {
    anadir('autor', paleta(r.autores.first.libros.last),
        (c, t) => _Autor(r: r, t: t));
  }
  if (r.sagas.isNotEmpty) {
    anadir('sagas', paleta(r.sagas.first.leidos.last),
        (c, t) => _Sagas(r: r, t: t),
        duracion: 1.15);
  }
  if (r.generos.length >= 2) {
    anadir('generos', paleta(), (c, t) => _Generos(r: r, t: t));
  }
  if (r.anoMasAntiguo != null &&
      r.anoMasReciente != null &&
      r.anoMasReciente! - r.anoMasAntiguo! >= 10) {
    anadir('epocas', paleta(r.libroMasAntiguo), (c, t) => _Epocas(r: r, t: t));
  }
  if (_curiosidades(r).length >= 2) {
    anadir('curiosidades', paleta(), (c, t) => _Curiosidades(r: r, t: t),
        duracion: 1.1);
  }
  if (r.terminados.where((l) => l.rating != null).length >= 3) {
    anadir('notas', Paleta.oro, (c, t) => _Notas(r: r, t: t));
  }
  if (r.propositos > 0) {
    anadir('propositos', paleta(), (c, t) => _Propositos(r: r, t: t));
  }
  if (r.citaDestacada != null) {
    anadir('cita', paleta(r.citaDestacada!.libro), (c, t) => _Cita(r: r, t: t),
        duracion: 1.15);
  }
  if (r.libroDelAno != null) {
    anadir('libro-del-ano', paleta(r.libroDelAno),
        (c, t) => _LibroDelAno(r: r, t: t),
        duracion: 1.15);
  }
  anadir('perfil', paleta(), (c, t) => _Perfil(r: r, t: t));
  if (_hayFuturo(r)) {
    anadir('lo-que-viene', Paleta.aurora, (c, t) => _LoQueViene(r: r, t: t),
        duracion: 1.1);
  }
  anadir('resumen', paleta(r.portada), (c, t) => _Resumen(r: r, t: t),
      duracion: 1.4);
  return lista;
}

/// Portadas que conviene precargar antes de reproducir.
Iterable<String?> portadasDeLibros(ResumenLibros r) => {
      for (final l in r.terminados) l.coverUrl,
      for (final e in r.porTiempo) e.libro.coverUrl,
      for (final s in r.sagas) ...[
        s.enCurso?.coverUrl,
        s.siguiente?.portada,
      ],
      for (final l in r.enCurso) l.coverUrl,
      for (final p in r.listaPropositos) p.portada,
      r.portada?.coverUrl,
    };

// ============================================================ estructura común

class _Marco extends StatelessWidget {
  const _Marco({
    required this.r,
    required this.children,
    this.alineacion = CrossAxisAlignment.start,
    this.marca = true,
  });
  final ResumenLibros r;
  final List<Widget> children;
  final CrossAxisAlignment alineacion;
  final bool marca;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(28, 44, 28, 22),
        child: Column(crossAxisAlignment: alineacion, children: [
          ...children,
          if (marca) ...[
            const SizedBox(height: 10),
            _MarcaAgua(year: r.year),
          ],
        ]),
      );
}

class _MarcaAgua extends StatelessWidget {
  const _MarcaAgua({required this.year});
  final int year;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0x88FFFFFF)]),
          ),
          child: const Icon(Icons.auto_stories_rounded,
              size: 10, color: Colors.black87),
        ),
        const SizedBox(width: 7),
        Text('TODO · WRAPPED $year',
            style:
                TipografiaWrapped.etiqueta(color: Colors.white54, size: 8.5)),
        const Spacer(),
        Text('Libros',
            style:
                TipografiaWrapped.etiqueta(color: Colors.white38, size: 8.5)),
      ]);
}

Widget _etiqueta(double t, double desde, String texto, {Color? color}) =>
    Aparece(
      t: t,
      desde: desde,
      child: Text(texto.toUpperCase(),
          style: TipografiaWrapped.etiqueta(color: color ?? Colors.white70)),
    );

Widget _titular(double t, double desde, String texto,
        {double size = 34, TextAlign align = TextAlign.left}) =>
    TextoRevelado(texto,
        t: t,
        desde: desde,
        alineacion: align,
        estilo: TipografiaWrapped.titular(size: size, height: 1.0));

Widget _cifra(double t, double desde, num valor,
        {double size = 120,
        String Function(num)? formato,
        Color color = Colors.white}) =>
    FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Contador(
        t: t,
        desde: desde,
        valor: valor,
        formato: formato,
        estilo: TipografiaWrapped.titular(
            size: size, color: color, height: .9, spacing: -size * .045),
      ),
    );

Widget _libroTitulo(LibraryItem l,
        {double size = 15, int lineas = 2, TextAlign align = TextAlign.left}) =>
    Text(l.title,
        maxLines: lineas,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: TipografiaWrapped.serif(
            size: size, style: FontStyle.normal, weight: FontWeight.w600));

Widget _portada(LibraryItem l, double ancho, {double radio = 6}) => Portada(
    fuente: l.coverUrl,
    titulo: l.title,
    autor: l.author,
    ancho: ancho,
    alto: ancho * 1.5,
    radio: radio);

/// Leve vaivén continuo para que nada quede del todo quieto.
double _deriva(double t, [double fase = 0]) =>
    math.sin(t * math.pi * 1.4 + fase);

// ============================================================ 1. portada

class _Inicio extends StatelessWidget {
  const _Inicio({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final principal = r.portada!;
    final otras = [
      ...r.terminados.reversed,
      ...r.porTiempo.map((e) => e.libro),
    ].where((l) => l.id != principal.id).toSet().take(4).toList();
    final nombre = r.ajustes.nombre;
    final titulo = r.ajustes.titulo ?? 'Tu año en libros';
    final zoom = 1 + .05 * t;
    return _Marco(r: r, marca: false, children: [
      _etiqueta(t, 0, 'Todo · Wrapped'),
      const SizedBox(height: 6),
      Expanded(
        child: SizedBox(
          width: double.infinity,
          child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < otras.length; i++)
                  Transform.translate(
                    offset: Offset(
                        (i.isEven ? -1 : 1) *
                            (92 + 26.0 * (i ~/ 2)) *
                            tramo(t, .12 + i * .04, .5 + i * .04),
                        18.0 + 10 * (i ~/ 2) + 4 * _deriva(t, i.toDouble())),
                    child: Transform.rotate(
                      angle: (i.isEven ? -1 : 1) *
                          (.14 + .08 * (i ~/ 2)) *
                          tramo(t, .12 + i * .04, .5 + i * .04),
                      child: Opacity(
                        opacity: .85 * tramo(t, .1 + i * .04, .3 + i * .04),
                        child: _portada(otras[i], 120 - 12.0 * (i ~/ 2)),
                      ),
                    ),
                  ),
                Transform.scale(
                  scale: zoom *
                      (.82 + .18 * tramo(t, .05, .35, Curves.easeOutBack)),
                  child: Opacity(
                    opacity: tramo(t, .03, .18),
                    child: _portada(principal, 176, radio: 8),
                  ),
                ),
              ]),
        ),
      ),
      const SizedBox(height: 18),
      if (nombre != null) ...[
        Aparece(
            t: t,
            desde: .32,
            child: Text('$nombre,',
                style:
                    TipografiaWrapped.serif(size: 22, color: Colors.white70))),
        const SizedBox(height: 2),
      ],
      Aparece(
        t: t,
        desde: .36,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('${r.year}',
              style: TipografiaWrapped.titular(
                  size: 116, height: .86, spacing: -6)),
        ),
      ),
      const SizedBox(height: 6),
      _titular(t, .46, titulo, size: 30),
      const SizedBox(height: 12),
      _MarcaAgua(year: r.year),
    ]);
  }
}

// ============================================================ 2. terminados

class _Terminados extends StatelessWidget {
  const _Terminados({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final n = r.terminados.length;
    final dif = n - r.terminadosAnterior;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Este año terminaste'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: _cifra(t, .04, n, size: 132)),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Aparece(
                  t: t,
                  desde: .2,
                  child: Text(n == 1 ? 'libro' : 'libros',
                      style: TipografiaWrapped.titular(size: 34))),
            ),
          ),
        ),
      ]),
      Aparece(
        t: t,
        desde: .26,
        child: Insignia(r.terminadosAnterior == 0
            ? 'Tu primer año en Todo'
            : (dif == 0
                ? 'Igual que en ${r.year - 1}'
                : '${dif > 0 ? '+' : ''}$dif respecto a ${r.year - 1}')),
      ),
      const SizedBox(height: 16),
      Expanded(
          child:
              _Muro(libros: r.terminados.reversed.toList(), t: t, desde: .3)),
    ]);
  }
}

/// Mosaico de portadas que ocupa todo el hueco y entra en cascada.
class _Muro extends StatelessWidget {
  const _Muro({required this.libros, required this.t, this.desde = .3});
  final List<LibraryItem> libros;
  final double t, desde;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, caja) {
        if (libros.isEmpty) return const SizedBox.shrink();
        const hueco = 6.0;
        var columnas = 1;
        var ancho = caja.maxWidth;
        for (var c = 1; c <= 8; c++) {
          final w = (caja.maxWidth - hueco * (c - 1)) / c;
          final filas = (libros.length / c).ceil();
          columnas = c;
          ancho = w;
          if (filas * (w * 1.5 + hueco) - hueco <= caja.maxHeight) break;
        }
        final caben = math.max(
                1, ((caja.maxHeight + hueco) / (ancho * 1.5 + hueco)).floor()) *
            columnas;
        final mostrados = libros.take(caben).toList();
        return Wrap(
          spacing: hueco,
          runSpacing: hueco,
          children: [
            for (var i = 0; i < mostrados.length; i++)
              Aparece(
                t: t,
                desde: math.min(.7, desde + i * (.3 / mostrados.length)),
                duracion: .14,
                dy: 40,
                escala: .8,
                child: _portada(mostrados[i], ancho, radio: 4),
              ),
          ],
        );
      });
}

// ============================================================ 3. páginas

class _Paginas extends StatelessWidget {
  const _Paginas({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final con = r.paginasPorLibro.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final largo = con.first;
    final corto = con.length > 1 ? con.last : null;
    // Unos 0,05 mm por página: lo que medirían apiladas.
    final cm = r.paginas / 200;
    final media = (r.paginas / con.length).round();
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Pasaste'),
      _cifra(t, .04, r.paginas, size: 104),
      Aparece(
          t: t,
          desde: .18,
          child: Text('páginas', style: TipografiaWrapped.titular(size: 34))),
      const SizedBox(height: 12),
      Aparece(
        t: t,
        desde: .26,
        child: Text(
            'Apiladas medirían ${decimal(cm)} cm. De media, $media páginas por libro'
            '${r.paginasAnterior > 0 ? ', y ${miles((r.paginas - r.paginasAnterior).abs())} ${r.paginas >= r.paginasAnterior ? 'más' : 'menos'} que en ${r.year - 1}' : ''}.',
            style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
      ),
      const Spacer(),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child: _Extremo(
                t: t,
                desde: .38,
                etiqueta: 'El más largo',
                libro: largo.key,
                paginas: largo.value,
                ancho: 128)),
        const SizedBox(width: 14),
        if (corto != null)
          Expanded(
              child: _Extremo(
                  t: t,
                  desde: .48,
                  etiqueta: 'El más corto',
                  libro: corto.key,
                  paginas: corto.value,
                  ancho: 88)),
      ]),
      const Spacer(),
    ]);
  }
}

class _Extremo extends StatelessWidget {
  const _Extremo(
      {required this.t,
      required this.desde,
      required this.etiqueta,
      required this.libro,
      required this.paginas,
      required this.ancho,
      this.detalle});
  final double t, desde, ancho;
  final String etiqueta;
  final String? detalle;
  final LibraryItem libro;
  final int paginas;

  @override
  Widget build(BuildContext context) => Aparece(
        t: t,
        desde: desde,
        dy: 40,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(etiqueta.toUpperCase(),
              style: TipografiaWrapped.etiqueta(size: 9.5)),
          const SizedBox(height: 8),
          _portada(libro, ancho),
          const SizedBox(height: 10),
          _libroTitulo(libro, size: 13),
          Text(detalle ?? '${miles(paginas)} páginas',
              style: TipografiaWrapped.texto(
                  size: 12, color: Colors.white70, weight: FontWeight.w700)),
        ]),
      );
}

// ============================================================ 4. Kindle

class _Kindle extends StatelessWidget {
  const _Kindle({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final horas = r.segundos ~/ 3600;
    final minutos = (r.segundos % 3600) ~/ 60;
    final media = (r.segundos / math.max(1, r.diasConLectura) / 60).round();
    final dias = r.segundos / 86400;
    final datos = <(String, String, IconData)>[
      ('${r.diasConLectura}', 'días con lectura', Icons.calendar_month_rounded),
      ('$media min', 'de media esos días', Icons.timelapse_rounded),
      if (r.paginasKindle > 0)
        (
          miles(r.paginasKindle),
          'páginas en el Kindle',
          Icons.menu_book_rounded
        ),
      if (r.paginasPorHora != null)
        ('${r.paginasPorHora}', 'páginas por hora', Icons.speed_rounded),
      if (r.paginasKindle == 0)
        (
          '${r.porTiempo.length}',
          r.porTiempo.length == 1
              ? 'libro con historial'
              : 'libros con historial',
          Icons.auto_stories_rounded
        ),
    ];
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'En el Kindle leíste'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: _cifra(t, .04, horas, size: 140)),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Aparece(
                t: t,
                desde: .2,
                child: Text(horas == 1 ? 'hora' : 'horas',
                    style: TipografiaWrapped.titular(size: 36)),
              ),
            ),
          ),
        ),
      ]),
      Aparece(
        t: t,
        desde: .24,
        child: Text(
            '${minutos > 0 ? 'y $minutos minutos. ' : ''}'
            'Son ${decimal(dias)} días enteros sin soltar el libro.',
            style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
      ),
      if (r.segundosAnterior > 0) ...[
        const SizedBox(height: 10),
        Aparece(
          t: t,
          desde: .3,
          child: Insignia(
              '${r.segundos >= r.segundosAnterior ? '+' : '−'}${duracionLarga((r.segundos - r.segundosAnterior).abs())} que en ${r.year - 1}'),
        ),
      ],
      const Spacer(),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < datos.length && i < 4; i++)
            Aparece(
              t: t,
              desde: .34 + i * .06,
              escala: .9,
              child: _Ficha(
                  valor: datos[i].$1, texto: datos[i].$2, icono: datos[i].$3),
            ),
        ],
      ),
    ]);
  }
}

class _Ficha extends StatelessWidget {
  const _Ficha({required this.valor, required this.texto, required this.icono});
  final String valor, texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icono, color: Colors.white70, size: 20),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(valor, style: TipografiaWrapped.titular(size: 30)),
              ),
              Text(texto,
                  maxLines: 2,
                  style: TipografiaWrapped.texto(
                      size: 11.5, color: Colors.white70, height: 1.15)),
            ]),
      );
}

// ============================================================ 5. calendario

class _Calendario extends StatelessWidget {
  const _Calendario({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final inicio = r.inicioRacha, fin = r.finRacha;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Tu racha más larga'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: _cifra(t, .04, r.rachaMaxima, size: 112)),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Aparece(
                  t: t,
                  desde: .16,
                  child: Text(r.rachaMaxima == 1 ? 'día' : 'días seguidos',
                      style: TipografiaWrapped.titular(size: 28))),
            ),
          ),
        ),
      ]),
      if (inicio != null && fin != null)
        Aparece(
          t: t,
          desde: .22,
          child: Text(
              r.rachaMaxima == 1
                  ? 'El ${fechaLarga(inicio)}.'
                  : 'Del ${fechaLarga(inicio)} al ${fechaLarga(fin)}, sin fallar ni un día.',
              style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
        ),
      const SizedBox(height: 16),
      Expanded(
        child: LayoutBuilder(
          builder: (context, caja) => CustomPaint(
            size: caja.biggest,
            painter: _PintorCalendario(r, t),
          ),
        ),
      ),
    ]);
  }
}

class _PintorCalendario extends CustomPainter {
  _PintorCalendario(this.r, this.t);
  final ResumenLibros r;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const columnas = 3, filas = 4;
    final anchoMes = size.width / columnas;
    final altoMes = size.height / filas;
    final celda = math.min((anchoMes - 10) / 7, (altoMes - 22) / 6);
    final maximo = r.segundosPorDia.values.fold<int>(1, math.max);
    final textos = TextPainter(textDirection: TextDirection.ltr);
    for (var m = 0; m < 12; m++) {
      final ox = (m % columnas) * anchoMes;
      final oy = (m ~/ columnas) * altoMes;
      final aparicion = tramo(t, .2 + m * .035, .42 + m * .035);
      textos.text = TextSpan(
          text: mesesLargos[m].substring(0, 3).toUpperCase(),
          style: TipografiaWrapped.etiqueta(
              size: 8.5,
              color: Colors.white.withValues(alpha: .7 * aparicion)));
      textos.layout();
      textos.paint(canvas, Offset(ox, oy));
      final primero = DateTime(r.year, m + 1, 1);
      final diasMes = DateTime(r.year, m + 2, 0).day;
      for (var d = 0; d < diasMes; d++) {
        final fecha = DateTime(r.year, m + 1, d + 1);
        final pos = d + primero.weekday - 1;
        final x = ox + (pos % 7) * celda;
        final y = oy + 16 + (pos ~/ 7) * celda;
        final s = r.segundosPorDia[fecha] ?? 0;
        final enRacha = r.inicioRacha != null &&
            !fecha.isBefore(r.inicioRacha!) &&
            !fecha.isAfter(r.finRacha!);
        final intensidad = s == 0 ? 0.0 : .35 + .65 * math.sqrt(s / maximo);
        final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(x + .8, y + .8, celda - 1.6, celda - 1.6),
            Radius.circular(celda * .28));
        final color = s == 0
            ? Colors.white.withValues(alpha: .08 * aparicion)
            : (enRacha
                ? Color.lerp(const Color(0xFFFFE08A), Colors.white, .2)!
                    .withValues(alpha: aparicion)
                : Colors.white.withValues(alpha: intensidad * aparicion));
        canvas.drawRRect(rect, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_PintorCalendario old) => old.t != t || old.r != r;
}

// ============================================================ 6. día récord

class _DiaRecord extends StatelessWidget {
  const _DiaRecord({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final libro = r.libroDiaRecord!;
    return _Marco(r: r, alineacion: CrossAxisAlignment.center, children: [
      _etiqueta(t, 0, 'Tu día más lector'),
      const SizedBox(height: 10),
      _titular(t, .05, capitalizar(fechaLarga(r.diaRecord!, conDia: true)),
          size: 30, align: TextAlign.center),
      const SizedBox(height: 18),
      Expanded(
        child: Center(
          child: Transform.rotate(
            angle: -.05 + .015 * _deriva(t),
            child: Aparece(
              t: t,
              desde: .2,
              escala: .7,
              dy: 0,
              child: _portada(libro, 168, radio: 8),
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Contador(
          t: t,
          desde: .32,
          valor: r.segundosDiaRecord,
          formato: (v) => duracionLarga(v.round()),
          estilo: TipografiaWrapped.titular(size: 60),
        ),
      ),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .44,
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'sin despegarte de '),
            TextSpan(
                text: '«${libro.title}»',
                style: TipografiaWrapped.serif(size: 15, color: Colors.white)),
          ]),
          textAlign: TextAlign.center,
          style: TipografiaWrapped.texto(size: 14, color: Colors.white70),
        ),
      ),
    ]);
  }
}

// ============================================================ 7. reloj

({String nombre, String detalle, IconData icono}) _momento(ResumenLibros r) {
  int suma(Iterable<int> horas) =>
      horas.fold(0, (s, h) => s + r.segundosPorHora[h]);
  final tramos = [
    (
      suma([5, 6, 7, 8, 9, 10, 11]),
      'Alondra lectora',
      'Lo tuyo son las mañanas',
      Icons.wb_twilight_rounded
    ),
    (
      suma([12, 13, 14, 15, 16, 17]),
      'Lectura de sobremesa',
      'Te rinden las tardes',
      Icons.wb_sunny_rounded
    ),
    (
      suma([18, 19, 20, 21, 22]),
      'Hora dorada',
      'Lees cuando cae el sol',
      Icons.nights_stay_rounded
    ),
    (
      suma([23, 0, 1, 2, 3, 4]),
      'Búho lector',
      'La noche es tuya',
      Icons.dark_mode_rounded
    ),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  return (
    nombre: tramos.first.$2,
    detalle: tramos.first.$3,
    icono: tramos.first.$4
  );
}

class _Reloj extends StatelessWidget {
  const _Reloj({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final momento = _momento(r);
    var punta = 0;
    for (var h = 1; h < 24; h++) {
      if (r.segundosPorHora[h] > r.segundosPorHora[punta]) punta = h;
    }
    var dia = 0;
    for (var d = 1; d < 7; d++) {
      if (r.segundosPorDiaSemana[d] > r.segundosPorDiaSemana[dia]) dia = d;
    }
    return _Marco(r: r, alineacion: CrossAxisAlignment.center, children: [
      _etiqueta(t, 0, 'Cuándo lees'),
      const SizedBox(height: 8),
      Expanded(
        child: Stack(alignment: Alignment.center, children: [
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(painter: _PintorReloj(r.segundosPorHora, t)),
          ),
          Aparece(
            t: t,
            desde: .45,
            escala: .6,
            dy: 0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(momento.icono, color: Colors.white, size: 30),
              const SizedBox(height: 4),
              Text('${punta.toString().padLeft(2, '0')}:00',
                  style: TipografiaWrapped.titular(size: 34)),
              Text('tu hora punta',
                  style:
                      TipografiaWrapped.texto(size: 11, color: Colors.white60)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      _titular(t, .5, momento.nombre, size: 38, align: TextAlign.center),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .6,
        child: Text(
            '${momento.detalle}, y tu día favorito es el ${diasSemana[dia]}.',
            textAlign: TextAlign.center,
            style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
      ),
    ]);
  }
}

class _PintorReloj extends CustomPainter {
  _PintorReloj(this.horas, this.t);
  final List<int> horas;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.shortestSide / 2;
    final interior = radio * .38;
    final maximo = horas.fold<int>(1, math.max);
    final giro = tramo(t, 0, .5, Curves.easeOutCubic);
    canvas.drawCircle(
        centro,
        interior - 6,
        Paint()
          ..color = Colors.white.withValues(alpha: .07 * giro)
          ..style = PaintingStyle.fill);
    for (var h = 0; h < 24; h++) {
      final angulo = -math.pi / 2 + h / 24 * math.pi * 2;
      final valor = horas[h] / maximo;
      final crece =
          tramo(t, .12 + h * .012, .45 + h * .012, Curves.easeOutBack);
      final largo = 6 + (radio - interior - 18) * valor * crece;
      final dir = Offset(math.cos(angulo), math.sin(angulo));
      final p1 = centro + dir * interior;
      final p2 = centro + dir * (interior + largo);
      canvas.drawLine(
          p1,
          p2,
          Paint()
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(
                alpha: (valor == 0 ? .15 : .45 + .55 * valor) * giro));
      if (h % 6 == 0) {
        final texto = TextPainter(
          text: TextSpan(
              text: '$h',
              style: TipografiaWrapped.texto(
                  size: 10,
                  weight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: .6 * giro))),
          textDirection: TextDirection.ltr,
        )..layout();
        final pt = centro + dir * (radio - 6);
        texto.paint(canvas, pt - Offset(texto.width / 2, texto.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_PintorReloj old) => old.t != t;
}

// ============================================================ 8. mes a mes

class _Meses extends StatelessWidget {
  const _Meses({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final porMes = List.generate(12, (_) => <LibraryItem>[]);
    for (final l in r.terminados) {
      porMes[l.completedDate!.month - 1].add(l);
    }
    var mejor = 0;
    for (var m = 1; m < 12; m++) {
      final actual = porMes[m].length * 1e9 + r.segundosPorMes[m];
      final previo = porMes[mejor].length * 1e9 + r.segundosPorMes[mejor];
      if (actual > previo) mejor = m;
    }
    final maximo = porMes.fold<int>(1, (a, b) => math.max(a, b.length));
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Tu año, mes a mes'),
      const SizedBox(height: 6),
      _titular(t, .04, '${capitalizar(mesesLargos[mejor])} fue tu mes',
          size: 34),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .14,
        child: Text(
            '${porMes[mejor].length} ${porMes[mejor].length == 1 ? 'libro terminado' : 'libros terminados'}'
            '${r.segundosPorMes[mejor] > 0 ? ' y ${duracionLarga(r.segundosPorMes[mejor])} en el Kindle' : ''}.',
            style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
      ),
      const SizedBox(height: 18),
      Expanded(
        child: LayoutBuilder(builder: (context, caja) {
          // Dos filas de seis meses: las portadas se apilan como en un estante.
          const hueco = 6.0;
          final ancho = (caja.maxWidth - 5 * hueco) / 6;
          final altoFila = (caja.maxHeight - 14) / 2;
          final alto =
              math.min(ancho * 1.5, (altoFila - 30 - maximo * 3) / maximo);
          Widget mes(int m) => SizedBox(
                width: ancho,
                height: altoFila,
                child:
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  for (var i = porMes[m].length - 1; i >= 0; i--)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Aparece(
                        t: t,
                        desde: .2 + m * .025 + i * .03,
                        dy: -50,
                        duracion: .12,
                        child: Portada(
                            fuente: porMes[m][i].coverUrl,
                            titulo: porMes[m][i].title,
                            ancho: alto / 1.5,
                            alto: alto,
                            radio: 3,
                            sombra: false),
                      ),
                    ),
                  Container(
                    height: 2,
                    margin: const EdgeInsets.only(top: 4),
                    color: m == mejor ? Colors.white : Colors.white24,
                  ),
                  const SizedBox(height: 4),
                  Text(mesesLargos[m].substring(0, 3).toUpperCase(),
                      style: TipografiaWrapped.etiqueta(
                          size: 8.5,
                          color: m == mejor ? Colors.white : Colors.white54)),
                ]),
              );
          return Column(children: [
            for (final fila in [0, 6]) ...[
              if (fila > 0) const SizedBox(height: 14),
              Row(children: [
                for (var m = fila; m < fila + 6; m++) ...[
                  if (m > fila) const SizedBox(width: hueco),
                  mes(m),
                ],
              ]),
            ],
          ]);
        }),
      ),
    ]);
  }
}

// ============================================================ 9. top

class _Top extends StatelessWidget {
  const _Top({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final top = r.porTiempo.where((e) => e.segundos >= 900).take(5).toList();
    final maximo = top.first.segundos;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Los que más horas te robaron'),
      const SizedBox(height: 6),
      _titular(t, .03, 'Tu top en el Kindle', size: 32),
      const SizedBox(height: 18),
      for (var i = 0; i < top.length; i++)
        Expanded(
          child: Aparece(
            t: t,
            desde: .12 + i * .07,
            dx: 40,
            dy: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(
                  width: 30,
                  child: Text('${i + 1}',
                      style: TipografiaWrapped.titular(
                          size: i == 0 ? 34 : 26,
                          color: i == 0 ? Colors.white : Colors.white54)),
                ),
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Portada(
                      fuente: top[i].libro.coverUrl,
                      titulo: top[i].libro.title,
                      radio: 4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _libroTitulo(top[i].libro, size: 14),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: top[i].segundos /
                                maximo *
                                tramo(t, .25 + i * .07, .6 + i * .07),
                            backgroundColor: Colors.white12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            '${duracionLarga(top[i].segundos)} · ${top[i].dias} ${top[i].dias == 1 ? 'día' : 'días'}',
                            style: TipografiaWrapped.texto(
                                size: 11,
                                color: Colors.white70,
                                weight: FontWeight.w700)),
                      ]),
                ),
              ]),
            ),
          ),
        ),
      if (top.length < 5) Spacer(flex: 5 - top.length),
    ]);
  }
}

// ============================================================ 10. autor

class _Autor extends StatelessWidget {
  const _Autor({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final autor = r.autores.first;
    final libros = autor.libros.reversed.take(6).toList();
    final otros =
        r.autores.skip(1).where((a) => a.libros.length > 1).take(3).toList();
    final nuevos = r.autores.where((a) => a.nuevo).length;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'La pluma de tu año'),
      const SizedBox(height: 8),
      Aparece(
        t: t,
        desde: .04,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(autor.nombre,
              style: TipografiaWrapped.titular(size: 46, spacing: -1.6)),
        ),
      ),
      Aparece(
        t: t,
        desde: .12,
        child: Text('${autor.libros.length} libros este año',
            style: TipografiaWrapped.serif(size: 20, color: Colors.white70)),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, caja) {
          final ancho =
              math.min(caja.maxWidth * .44, caja.maxHeight / 1.5 * .8);
          return Stack(alignment: Alignment.center, children: [
            const SizedBox.expand(),
            for (var i = 0; i < libros.length; i++)
              Builder(builder: (context) {
                final centro = (libros.length - 1) / 2;
                final rel = i - centro;
                final v =
                    tramo(t, .2 + i * .05, .5 + i * .05, Curves.easeOutBack);
                return Transform.translate(
                  offset: Offset(
                      rel *
                          (caja.maxWidth - ancho) /
                          math.max(1, libros.length - 1) *
                          v,
                      rel.abs() * 10.0 + 3 * _deriva(t, i * .7)),
                  child: Transform.rotate(
                    angle: rel * .07 * v,
                    child: Opacity(
                      opacity: tramo(t, .18 + i * .05, .3 + i * .05),
                      child: _portada(libros[i], ancho),
                    ),
                  ),
                );
              }),
          ]);
        }),
      ),
      if (otros.isNotEmpty)
        Aparece(
          t: t,
          desde: .55,
          child: Text(
              'También: ${otros.map((a) => '${a.nombre} (${a.libros.length})').join(' · ')}',
              style:
                  TipografiaWrapped.texto(size: 12.5, color: Colors.white70)),
        ),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .6,
        child: Insignia(
            '${r.autores.length} ${r.autores.length == 1 ? 'firma' : 'firmas'} en total'
            '${nuevos > 0 && nuevos < r.autores.length ? ' · $nuevos ${nuevos == 1 ? 'nueva' : 'nuevas'}' : ''}'),
      ),
    ]);
  }
}

// ============================================================ 11. sagas

String _textoSalida(SiguienteEntrega s, int year) {
  if (s.libro?.status == LibraryItemStatus.inProgress) {
    return 'Ya la estás leyendo: ${s.libro!.readingPercent} %';
  }
  if (s.fechaPrevista != null) {
    final fecha = s.fechaPrevista!.replaceAll(RegExp(r'\s*\(.*\)$'), '');
    return RegExp(r'^\d').hasMatch(fecha) ? 'Llega el $fecha' : 'Llega: $fecha';
  }
  if ((s.anoSalida ?? 0) > year) return 'Llega en ${s.anoSalida}';
  return s.libro == null
      ? 'Ya está a la venta'
      : 'Ya te espera en la estantería';
}

class _Sagas extends StatelessWidget {
  const _Sagas({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final saga = r.sagas.first;
    final otras = r.sagas.skip(1).take(3).toList();
    final siguiente = saga.siguiente;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'La saga que te atrapó'),
      const SizedBox(height: 6),
      _titular(t, .03, saga.nombre, size: 36),
      const SizedBox(height: 4),
      Aparece(
        t: t,
        desde: .1,
        child: Text(
            '${saga.leidos.length} ${saga.leidos.length == 1 ? 'entrega' : 'entregas'} este año',
            style: TipografiaWrapped.serif(size: 18, color: Colors.white70)),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 128,
        child: LayoutBuilder(builder: (context, caja) {
          final n = saga.leidos.length;
          const ancho = 80.0;
          final paso = n <= 1
              ? 0.0
              : math.min(ancho + 6, (caja.maxWidth - ancho) / (n - 1));
          return Stack(children: [
            for (var i = 0; i < n; i++)
              Positioned(
                left: i * paso,
                top: 0,
                child: Aparece(
                  t: t,
                  desde: .14 + i * .045,
                  dx: -30,
                  dy: 0,
                  child: _portada(saga.leidos[i], ancho, radio: 4),
                ),
              ),
            for (var i = 0; i < n; i++)
              if (saga.leidos[i].collectionNumber != null)
                Positioned(
                  left: i * paso + 5,
                  bottom: 5,
                  child: Aparece(
                    t: t,
                    desde: .2 + i * .045,
                    escala: .5,
                    dy: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black54, blurRadius: 6)
                          ]),
                      child: Text('${saga.leidos[i].collectionNumber}',
                          style: TipografiaWrapped.texto(
                              size: 11,
                              weight: FontWeight.w800,
                              color: Colors.black)),
                    ),
                  ),
                ),
          ]);
        }),
      ),
      const SizedBox(height: 16),
      if (siguiente != null)
        Aparece(
          t: t,
          desde: .42,
          escala: .92,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(children: [
              Portada(
                  fuente: siguiente.portada,
                  titulo: siguiente.titulo,
                  ancho: 58,
                  alto: 87,
                  radio: 4),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Insignia('PREPÁRATE', relleno: true),
                      const SizedBox(height: 6),
                      Text('Entrega ${siguiente.numero}',
                          style: TipografiaWrapped.texto(
                              size: 11,
                              color: Colors.white60,
                              weight: FontWeight.w700)),
                      Text(siguiente.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TipografiaWrapped.serif(
                              size: 16,
                              style: FontStyle.normal,
                              weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(_textoSalida(siguiente, r.year),
                          style: TipografiaWrapped.texto(
                              size: 12, weight: FontWeight.w800)),
                    ]),
              ),
            ]),
          ),
        ),
      const Spacer(),
      if (otras.isNotEmpty) ...[
        _etiqueta(t, .55, 'Otras sagas del año', color: Colors.white54),
        const SizedBox(height: 6),
        for (var i = 0; i < otras.length; i++)
          Aparece(
            t: t,
            desde: .58 + i * .04,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(
                  child: Text(otras[i].nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TipografiaWrapped.texto(
                          size: 14, weight: FontWeight.w700)),
                ),
                Text(
                    '${otras[i].leidos.length} ${otras[i].leidos.length == 1 ? 'libro' : 'libros'}',
                    style: TipografiaWrapped.texto(
                        size: 13, color: Colors.white70)),
              ]),
            ),
          ),
      ],
    ]);
  }
}

// ============================================================ 12. géneros

class _Generos extends StatelessWidget {
  const _Generos({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  // Huecos para hasta siete burbujas: centro relativo y radio relativo.
  static const _huecos = [
    (.42, .40, .30),
    (.80, .20, .17),
    (.80, .62, .19),
    (.20, .78, .16),
    (.14, .14, .13),
    (.55, .86, .12),
    (.88, .93, .11),
  ];

  @override
  Widget build(BuildContext context) {
    final generos = r.generos.take(_huecos.length).toList();
    final maximo = generos.first.value;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Lo que más te tiró'),
      const SizedBox(height: 6),
      _titular(t, .03, generos.first.key, size: 38),
      Aparece(
        t: t,
        desde: .12,
        child: Text(
            'en ${generos.first.value} de tus ${r.terminados.length} libros',
            style: TipografiaWrapped.serif(size: 18, color: Colors.white70)),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: LayoutBuilder(builder: (context, caja) {
          final base = math.min(caja.maxWidth, caja.maxHeight);
          return Stack(children: [
            for (var i = 0; i < generos.length; i++)
              Builder(builder: (context) {
                final hueco = _huecos[i];
                final proporcion = .6 + .4 * generos[i].value / maximo;
                final radio =
                    base * hueco.$3 * (i == 0 ? 1 : math.max(.8, proporcion));
                final v =
                    tramo(t, .18 + i * .06, .5 + i * .06, Curves.elasticOut);
                final flota = 4 * _deriva(t, i * 1.3);
                return Positioned(
                  left: caja.maxWidth * hueco.$1 - radio,
                  top: caja.maxHeight * hueco.$2 - radio + flota,
                  width: radio * 2,
                  height: radio * 2,
                  child: Transform.scale(
                    scale: v,
                    child: Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(radio * .18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == 0
                            ? Colors.white
                            : Colors.white.withValues(
                                alpha: .1 + .06 * (generos.length - i)),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: radio * 1.5,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(generos[i].key,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                style: TipografiaWrapped.texto(
                                    size: radio * .26,
                                    weight: FontWeight.w800,
                                    height: 1.05,
                                    color:
                                        i == 0 ? Colors.black : Colors.white)),
                            Text('${generos[i].value}',
                                style: TipografiaWrapped.titular(
                                    size: radio * .34,
                                    color: i == 0
                                        ? Colors.black54
                                        : Colors.white60)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ]);
        }),
      ),
    ]);
  }
}

// ============================================================ 13. épocas

class _Epocas extends StatelessWidget {
  const _Epocas({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final desde = r.anoMasAntiguo!, hasta = r.anoMasReciente!;
    final conAno = r.terminados.where((l) => (l.releaseYear ?? 0) > 0).toList();
    final media =
        (conAno.fold<int>(0, (s, l) => s + (r.year - l.releaseYear!)) /
                conAno.length)
            .round();
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Viajaste en el tiempo'),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .03,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('$desde → $hasta',
              style: TipografiaWrapped.titular(size: 54, spacing: -2)),
        ),
      ),
      Aparece(
        t: t,
        desde: .1,
        child: Text('${hasta - desde} años de historias en un solo año.',
            style: TipografiaWrapped.serif(size: 18, color: Colors.white70)),
      ),
      const Spacer(),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: _Extremo(
              t: t,
              desde: .2,
              etiqueta: 'El más antiguo',
              detalle: 'Publicado en $desde',
              libro: r.libroMasAntiguo!,
              paginas: 0,
              ancho: 104),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _Extremo(
              t: t,
              desde: .28,
              etiqueta: 'El más reciente',
              detalle: 'Publicado en $hasta',
              libro: r.libroMasReciente!,
              paginas: 0,
              ancho: 104),
        ),
      ]),
      const SizedBox(height: 22),
      SizedBox(
        height: 40,
        child: CustomPaint(
          size: const Size(double.infinity, 40),
          painter: _PintorLinea(
              [for (final l in conAno) l.releaseYear!], desde, hasta, t),
        ),
      ),
      const SizedBox(height: 12),
      Aparece(
        t: t,
        desde: .55,
        child: Text('De media, tus libros tienen $media años.',
            style: TipografiaWrapped.texto(size: 13, color: Colors.white70)),
      ),
    ]);
  }
}

class _PintorLinea extends CustomPainter {
  _PintorLinea(this.anos, this.desde, this.hasta, this.t);
  final List<int> anos;
  final int desde, hasta;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final v = tramo(t, .3, .6);
    canvas.drawLine(
        Offset(0, y),
        Offset(size.width * v, y),
        Paint()
          ..color = Colors.white38
          ..strokeWidth = 2);
    final rango = math.max(1, hasta - desde);
    final cuenta = <int, int>{};
    for (var i = 0; i < anos.length; i++) {
      final x = (anos[i] - desde) / rango * size.width;
      final pila =
          math.min(3, cuenta.update(anos[i], (c) => c + 1, ifAbsent: () => 0));
      final aparece =
          tramo(t, .32 + x / size.width * .3, .4 + x / size.width * .3);
      canvas.drawCircle(Offset(x, y - pila * 7.0), 4 * aparece,
          Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_PintorLinea old) => old.t != t;
}

// ============================================================ 14. curiosidades

List<(String, String, IconData)> _curiosidades(ResumenLibros r) => [
      if (r.fisicos > 0 && r.digitales > 0)
        (
          '${r.fisicos} · ${r.digitales}',
          'en papel y en pantalla. ${r.fisicos >= r.digitales ? 'El papel sigue ganando' : 'La pantalla se impone'}.',
          Icons.layers_rounded
        ),
      if (r.libroMasRapido != null && r.diasLibroMasRapido <= 21)
        (
          '${r.diasLibroMasRapido} ${r.diasLibroMasRapido == 1 ? 'día' : 'días'}',
          'tardaste en devorar «${r.libroMasRapido!.title}».',
          Icons.bolt_rounded
        ),
      if (r.diaMasAnadidos != null && r.librosDiaMasAnadidos >= 3)
        (
          '${r.librosDiaMasAnadidos} libros',
          'añadiste de golpe el ${fechaLarga(r.diaMasAnadidos!)}.',
          Icons.library_add_rounded
        ),
      if (r.citas.isNotEmpty)
        (
          '${r.citas.length}',
          r.citas.length == 1
              ? 'cita subrayada en el Kindle.'
              : 'citas subrayadas en el Kindle.',
          Icons.format_quote_rounded
        ),
      if (r.enCurso.isNotEmpty && r.terminados.length < 3)
        (
          '${r.enCurso.length}',
          r.enCurso.length == 1
              ? 'libro a medias ahora mismo.'
              : 'libros a medias ahora mismo.',
          Icons.bookmark_rounded
        ),
    ];

class _Curiosidades extends StatelessWidget {
  const _Curiosidades({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final datos = _curiosidades(r).take(4).toList();
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Datos curiosos'),
      const SizedBox(height: 6),
      _titular(t, .03, 'Lo que no sabías de tu año', size: 32),
      const SizedBox(height: 16),
      for (var i = 0; i < datos.length; i++)
        Expanded(
          child: Aparece(
            t: t,
            desde: .14 + i * .08,
            dx: i.isEven ? -40 : 40,
            dy: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .14)),
              ),
              child: Row(children: [
                Icon(datos[i].$3, color: Colors.white, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(datos[i].$1,
                              style: TipografiaWrapped.titular(size: 28)),
                        ),
                        const SizedBox(height: 2),
                        Text(datos[i].$2,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TipografiaWrapped.texto(
                                size: 12, color: Colors.white70, height: 1.2)),
                      ]),
                ),
              ]),
            ),
          ),
        ),
      if (datos.length < 4) Spacer(flex: 4 - datos.length),
    ]);
  }
}

// ============================================================ 15. notas

class _Notas extends StatelessWidget {
  const _Notas({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final maximo = r.notasPorEstrella.fold<int>(1, math.max);
    final peor = r.peorValorado;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Tus notas'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(
            child: _cifra(t, .04, r.notaMedia!,
                size: 120, formato: (v) => decimal(v.toDouble()))),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Aparece(
                  t: t, desde: .18, child: Estrellas(r.notaMedia!, tamano: 22)),
            ),
          ),
        ),
      ]),
      Aparece(
        t: t,
        desde: .2,
        child: Text(
            'de nota media en ${r.terminados.where((l) => l.rating != null).length} libros valorados',
            style: TipografiaWrapped.serif(size: 17, color: Colors.white70)),
      ),
      const SizedBox(height: 22),
      for (var e = 5; e >= 1; e--)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(
                width: 34,
                child: Text('$e ★',
                    style: TipografiaWrapped.texto(
                        size: 13, weight: FontWeight.w800))),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: math.max(
                      .02,
                      r.notasPorEstrella[e - 1] /
                          maximo *
                          tramo(t, .25 + (5 - e) * .05, .55 + (5 - e) * .05)),
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                          alpha: r.notasPorEstrella[e - 1] == 0 ? .15 : .9),
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
                width: 26,
                child: Text('${r.notasPorEstrella[e - 1]}',
                    textAlign: TextAlign.right,
                    style: TipografiaWrapped.texto(
                        size: 13, color: Colors.white70))),
          ]),
        ),
      const Spacer(),
      if (peor != null)
        Aparece(
          t: t,
          desde: .55,
          child: Row(children: [
            _portada(peor, 54, radio: 4),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EL QUE NO TE CONVENCIÓ',
                        style: TipografiaWrapped.etiqueta(size: 9.5)),
                    const SizedBox(height: 4),
                    _libroTitulo(peor, size: 15),
                    const SizedBox(height: 2),
                    Estrellas(peor.rating!, tamano: 14),
                  ]),
            ),
          ]),
        ),
    ]);
  }
}

// ============================================================ 16. propósitos

class _Propositos extends StatelessWidget {
  const _Propositos({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final todos = r.propositosCumplidos == r.propositos;
    final lista = r.listaPropositos.take(12).toList();
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Tus propósitos lectores'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: _cifra(t, .04, r.propositosCumplidos, size: 120)),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 8),
              child: Aparece(
                  t: t,
                  desde: .16,
                  child: Text('de ${r.propositos}',
                      style: TipografiaWrapped.titular(
                          size: 40, color: Colors.white60))),
            ),
          ),
        ),
      ]),
      Aparece(
        t: t,
        desde: .2,
        child: Text(
            todos
                ? '¡Todos cumplidos! Lo que te propusiste, lo leíste.'
                : 'Te quedan ${r.propositos - r.propositosCumplidos} para seguir en ${r.year + 1}.',
            style: TipografiaWrapped.serif(size: 18, color: Colors.white70)),
      ),
      const SizedBox(height: 18),
      Expanded(
        child: LayoutBuilder(builder: (context, caja) {
          final columnas =
              lista.length <= 4 ? lista.length : (lista.length <= 9 ? 3 : 4);
          final ancho = (caja.maxWidth - (columnas - 1) * 8) / columnas;
          final alto = math.min(
              ancho * 1.5,
              (caja.maxHeight - 8 * ((lista.length / columnas).ceil() - 1)) /
                  (lista.length / columnas).ceil());
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < lista.length; i++)
              Aparece(
                t: t,
                desde: .26 + i * .03,
                escala: .85,
                child: Opacity(
                  opacity: lista[i].cumplido ? 1 : .38,
                  child: Stack(children: [
                    ColorFiltered(
                      colorFilter: lista[i].cumplido
                          ? const ColorFilter.mode(
                              Colors.transparent, BlendMode.dst)
                          : const ColorFilter.matrix([
                              .33, .33, .33, 0, 0, //
                              .33, .33, .33, 0, 0, //
                              .33, .33, .33, 0, 0, //
                              0, 0, 0, 1, 0,
                            ]),
                      child: Portada(
                          fuente: lista[i].portada,
                          titulo: lista[i].titulo,
                          ancho: alto / 1.5,
                          alto: alto,
                          radio: 4,
                          sombra: lista[i].cumplido),
                    ),
                    if (lista[i].cumplido)
                      const Positioned(
                        right: 4,
                        top: 4,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.check_rounded,
                              size: 14, color: Colors.black),
                        ),
                      ),
                  ]),
                ),
              ),
          ]);
        }),
      ),
    ]);
  }
}

// ============================================================ 17. cita

class _Cita extends StatelessWidget {
  const _Cita({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final cita = r.citaDestacada!;
    final largo = cita.texto.length;
    final tamano =
        largo < 90 ? 26.0 : (largo < 170 ? 22.0 : (largo < 260 ? 19.0 : 16.0));
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Una frase que te guardaste'),
      const SizedBox(height: 4),
      Aparece(
        t: t,
        desde: .04,
        child: Text('“',
            style: TipografiaWrapped.serif(
                size: 120,
                height: .9,
                style: FontStyle.normal,
                color: Colors.white38)),
      ),
      Expanded(
        child: Align(
          alignment: Alignment.topLeft,
          child: TextoRevelado(cita.texto,
              t: t,
              desde: .08,
              paso: math.min(
                  .012, .35 / math.max(1, cita.texto.split(' ').length)),
              alineacion: TextAlign.left,
              estilo: TipografiaWrapped.serif(size: tamano, height: 1.3)),
        ),
      ),
      if (cita.nota != null) ...[
        Aparece(
          t: t,
          desde: .55,
          child: Text('Tu nota: «${cita.nota}»',
              style: TipografiaWrapped.texto(size: 13, color: Colors.white70)),
        ),
        const SizedBox(height: 12),
      ],
      Aparece(
        t: t,
        desde: .5,
        child: Row(children: [
          _portada(cita.libro, 40, radio: 3),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _libroTitulo(cita.libro, size: 14, lineas: 1),
              if (cita.libro.author != null)
                Text(cita.libro.author!,
                    style: TipografiaWrapped.texto(
                        size: 12, color: Colors.white60)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Aparece(
        t: t,
        desde: .58,
        child: Text(
            r.citas.length == 1
                ? 'Fue tu única cita del año.'
                : 'Una de las ${r.citas.length} citas que guardaste este año.',
            style: TipografiaWrapped.texto(size: 12, color: Colors.white54)),
      ),
    ]);
  }
}

// ============================================================ 18. libro del año

class _LibroDelAno extends StatelessWidget {
  const _LibroDelAno({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final libro = r.libroDelAno!;
    final segundos = r.segundosDe(libro);
    final citas = r.citas.where((c) => c.libro.id == libro.id).length;
    final paginas = r.paginasPorLibro[libro];
    final datos = [
      if (segundos > 0) duracionLarga(segundos),
      if (paginas != null) '${miles(paginas)} págs.',
      if (citas > 0) '$citas ${citas == 1 ? 'cita' : 'citas'}',
    ];
    final color = ColoresPortada.deCache(libro.coverUrl) ?? Colors.white;
    return _Marco(r: r, alineacion: CrossAxisAlignment.center, children: [
      _etiqueta(t, 0, 'Y tu libro del año es…'),
      const SizedBox(height: 8),
      Expanded(
        child: Stack(alignment: Alignment.center, children: [
          const SizedBox.expand(),
          Positioned.fill(
            child: Opacity(
              opacity: tramo(t, .15, .4),
              child: CustomPaint(painter: _PintorRayos(t)),
            ),
          ),
          Transform.scale(
            scale: (.6 + .4 * tramo(t, .12, .42, Curves.easeOutBack)) *
                (1 + .03 * t),
            child: Opacity(
              opacity: tramo(t, .1, .2),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: .7),
                        blurRadius: 60,
                        spreadRadius: 4),
                  ],
                ),
                child: _portada(libro, 196, radio: 8),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Aparece(
          t: t,
          desde: .42,
          child: _libroTitulo(libro, size: 24, align: TextAlign.center)),
      if (libro.author != null)
        Aparece(
          t: t,
          desde: .46,
          child: Text(libro.author!,
              style: TipografiaWrapped.texto(size: 13, color: Colors.white70)),
        ),
      const SizedBox(height: 10),
      if (libro.rating != null)
        Aparece(t: t, desde: .5, child: Estrellas(libro.rating!, tamano: 24)),
      const SizedBox(height: 10),
      Aparece(
        t: t,
        desde: .56,
        child: Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [for (final d in datos) Insignia(d)],
        ),
      ),
    ]);
  }
}

class _PintorRayos extends CustomPainter {
  _PintorRayos(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final radio = size.longestSide;
    const rayos = 18;
    final giro = t * .5;
    final pintura = Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: .18),
        Colors.white.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: centro, radius: radio * .6));
    for (var i = 0; i < rayos; i++) {
      final a = giro + i / rayos * math.pi * 2;
      final ancho = math.pi / rayos * .5;
      final camino = Path()
        ..moveTo(centro.dx, centro.dy)
        ..lineTo(centro.dx + math.cos(a - ancho) * radio,
            centro.dy + math.sin(a - ancho) * radio)
        ..lineTo(centro.dx + math.cos(a + ancho) * radio,
            centro.dy + math.sin(a + ancho) * radio)
        ..close();
      canvas.drawPath(camino, pintura);
    }
  }

  @override
  bool shouldRepaint(_PintorRayos old) => old.t != t;
}

// ============================================================ 19. perfil

({String nombre, List<String> rasgos}) _perfil(ResumenLibros r) {
  final genero = r.generos.isEmpty ? '' : r.generos.first.key.toLowerCase();
  String nombre;
  if (RegExp(r'misterio|polic|detect|negra|crimen').hasMatch(genero)) {
    nombre = 'Detective de sillón';
  } else if (RegExp(r'litrpg|fantas|epica|épica|aventur').hasMatch(genero)) {
    nombre = 'Alma aventurera';
  } else if (RegExp(r'ciencia|sci|espacial').hasMatch(genero)) {
    nombre = 'Mente galáctica';
  } else if (RegExp(r'terror|gótic|gotic|oscur').hasMatch(genero)) {
    nombre = 'Amante del escalofrío';
  } else if (RegExp(r'romance|romántic|romantic').hasMatch(genero)) {
    nombre = 'Corazón romántico';
  } else if (RegExp(r'clásic|clasic|ruso').hasMatch(genero)) {
    nombre = 'Alma clásica';
  } else if (RegExp(r'ensayo|autoayuda|divulg').hasMatch(genero)) {
    nombre = 'Mente curiosa';
  } else {
    nombre = 'Lectura sin fondo';
  }
  final rasgos = <String>[
    if (r.sagas.isNotEmpty && r.sagas.first.leidos.length >= 2)
      'Te enganchan las sagas: ${r.sagas.first.leidos.length} de ${r.sagas.first.nombre}',
    if (r.autores.isNotEmpty && r.autores.first.libros.length >= 3)
      'Fidelidad absoluta a ${r.autores.first.nombre}',
    if (r.hayKindle)
      '${_momento(r).nombre}: ${_momento(r).detalle.toLowerCase()}',
    if (r.rachaMaxima >= 5)
      'Constancia de hierro: ${r.rachaMaxima} días seguidos',
    if ((r.anoMasReciente ?? 0) - (r.anoMasAntiguo ?? 0) >= 100)
      'Sin miedo a los clásicos de hace un siglo',
    if (r.generos.length >= 6)
      'Todoterreno: ${r.generos.length} géneros distintos',
  ];
  return (nombre: nombre, rasgos: rasgos.take(4).toList());
}

class _Perfil extends StatelessWidget {
  const _Perfil({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil(r);
    final portadas = <LibraryItem>{
      ...r.terminados.reversed,
      ...r.porTiempo.map((e) => e.libro)
    }.take(5).toList();
    return _Marco(r: r, alineacion: CrossAxisAlignment.center, children: [
      _etiqueta(t, 0, 'Tu perfil lector'),
      const SizedBox(height: 14),
      Expanded(
        child: Aparece(
          t: t,
          desde: .04,
          escala: .85,
          dy: 40,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0012)
              ..rotateY(.12 * _deriva(t))
              ..rotateX(-.05 * _deriva(t, 1.5)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: .24),
                    Colors.white.withValues(alpha: .06),
                  ],
                ),
                border: Border.all(color: Colors.white38, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 40,
                      offset: Offset(0, 20)),
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 120,
                      child: Row(children: [
                        for (var i = 0; i < portadas.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: Aparece(
                              t: t,
                              desde: .14 + i * .04,
                              child: Portada(
                                  fuente: portadas[i].coverUrl,
                                  titulo: portadas[i].title,
                                  alto: 120,
                                  radio: 4,
                                  sombra: false),
                            ),
                          ),
                        ],
                      ]),
                    ),
                    const Spacer(),
                    Text('ERES',
                        style:
                            TipografiaWrapped.etiqueta(color: Colors.white60)),
                    const SizedBox(height: 4),
                    TextoRevelado(perfil.nombre,
                        t: t,
                        desde: .24,
                        alineacion: TextAlign.left,
                        estilo:
                            TipografiaWrapped.titular(size: 40, height: .98)),
                    const SizedBox(height: 16),
                    for (var i = 0; i < perfil.rasgos.length; i++)
                      Aparece(
                        t: t,
                        desde: .36 + i * .06,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Icon(Icons.auto_awesome_rounded,
                                      size: 14, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(perfil.rasgos[i],
                                      style: TipografiaWrapped.texto(
                                          size: 13.5,
                                          weight: FontWeight.w600,
                                          height: 1.25)),
                                ),
                              ]),
                        ),
                      ),
                    const SizedBox(height: 4),
                  ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ============================================================ 20. lo que viene

bool _hayFuturo(ResumenLibros r) =>
    r.enCurso.isNotEmpty ||
    r.pendientes > 0 ||
    r.sagas.any((s) => s.siguiente != null);

class _LoQueViene extends StatelessWidget {
  const _LoQueViene({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final siguiente = r.year + 1;
    final enCurso = [...r.enCurso]
      ..sort((a, b) => b.readingPercent.compareTo(a.readingPercent));
    final estrenos = [
      for (final s in r.sagas)
        if (s.siguiente != null &&
            s.siguiente!.libro?.status != LibraryItemStatus.inProgress)
          (saga: s.nombre, entrega: s.siguiente!),
    ].take(2).toList();
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Prepárate para $siguiente'),
      const SizedBox(height: 6),
      _titular(t, .03, 'Esto no ha hecho más que empezar', size: 32),
      const SizedBox(height: 18),
      if (enCurso.isNotEmpty)
        Aparece(
          t: t,
          desde: .14,
          child: Row(children: [
            _portada(enCurso.first, 74, radio: 5),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TE LO LLEVAS A $siguiente',
                        style: TipografiaWrapped.etiqueta(size: 9.5)),
                    const SizedBox(height: 4),
                    _libroTitulo(enCurso.first, size: 16),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: enCurso.first.readingPercent /
                            100 *
                            tramo(t, .2, .5),
                        color: Colors.white,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${enCurso.first.readingPercent} % leído',
                        style: TipografiaWrapped.texto(
                            size: 12,
                            color: Colors.white70,
                            weight: FontWeight.w700)),
                  ]),
            ),
          ]),
        ),
      const SizedBox(height: 14),
      for (var i = 0; i < estrenos.length; i++)
        Aparece(
          t: t,
          desde: .28 + i * .08,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(children: [
              Portada(
                  fuente: estrenos[i].entrega.portada,
                  titulo: estrenos[i].entrega.titulo,
                  ancho: 44,
                  alto: 66,
                  radio: 3),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(estrenos[i].saga.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TipografiaWrapped.etiqueta(size: 9)),
                      Text(estrenos[i].entrega.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TipografiaWrapped.serif(
                              size: 15,
                              style: FontStyle.normal,
                              weight: FontWeight.w600)),
                      Text(_textoSalida(estrenos[i].entrega, r.year),
                          style: TipografiaWrapped.texto(
                              size: 12, weight: FontWeight.w800)),
                    ]),
              ),
            ]),
          ),
        ),
      const Spacer(),
      if (r.pendientes > 0)
        Aparece(
          t: t,
          desde: .45,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Contador(
                t: t,
                desde: .45,
                valor: r.pendientes,
                estilo: TipografiaWrapped.titular(size: 72)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                    r.pendientes == 1
                        ? 'libro te espera en la estantería'
                        : 'libros te esperan en la estantería',
                    style: TipografiaWrapped.serif(
                        size: 18, color: Colors.white70)),
              ),
            ),
          ]),
        ),
    ]);
  }
}

// ============================================================ 21. resumen

class _Resumen extends StatelessWidget {
  const _Resumen({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final portadas = <LibraryItem>{
      ...r.terminados.reversed,
      ...r.porTiempo.map((e) => e.libro)
    }.toList();
    final datos = <(String, String)>[
      if (r.terminados.isNotEmpty) ('${r.terminados.length}', 'libros'),
      if (r.paginas > 0) (miles(r.paginas), 'páginas'),
      if (r.hayKindle) ('${(r.segundos / 3600).round()} h', 'en el Kindle'),
      if (r.rachaMaxima > 1) ('${r.rachaMaxima}', 'días de racha'),
      if (r.notaMedia != null) ('${decimal(r.notaMedia!)} ★', 'nota media'),
      if (r.citas.isNotEmpty)
        ('${r.citas.length}', r.citas.length == 1 ? 'cita' : 'citas'),
      if (r.autores.isNotEmpty) ('${r.autores.length}', 'autores'),
      if (r.sagas.isNotEmpty)
        ('${r.sagas.length}', r.sagas.length == 1 ? 'saga' : 'sagas'),
    ].take(6).toList();
    final mensaje = r.ajustes.mensajeFinal ??
        'Nos vemos en ${r.year + 1}. Que sean aún más.';
    return _Marco(r: r, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Aparece(
          t: t,
          desde: 0,
          child: Text('${r.year}',
              style: TipografiaWrapped.titular(size: 62, spacing: -3)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Aparece(
                  t: t,
                  desde: .05,
                  child: Text('en libros',
                      style: TipografiaWrapped.serif(size: 22))),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Expanded(child: _Muro(libros: portadas, t: t, desde: .08)),
      const SizedBox(height: 14),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.45,
        children: [
          for (var i = 0; i < datos.length; i++)
            Aparece(
              t: t,
              desde: .4 + i * .04,
              escala: .9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(datos[i].$1,
                            style: TipografiaWrapped.titular(size: 22)),
                      ),
                      Text(datos[i].$2,
                          style: TipografiaWrapped.texto(
                              size: 10.5, color: Colors.white70)),
                    ]),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Aparece(
        t: t,
        desde: .62,
        child: Text(mensaje,
            style: TipografiaWrapped.serif(size: 16, color: Colors.white)),
      ),
    ]);
  }
}

// ============================================================ sin datos

class _SinDatos extends StatelessWidget {
  const _SinDatos({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) => _Marco(r: r, children: [
        const Spacer(),
        Aparece(
          t: t,
          desde: 0,
          child: Text('${r.year}', style: TipografiaWrapped.titular(size: 96)),
        ),
        const SizedBox(height: 12),
        _titular(t, .1,
            'Este año aún no hay libros terminados ni lectura en el Kindle.',
            size: 24),
        const Spacer(),
      ]);
}
