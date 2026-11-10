part of 'wrapped_diapositivas.dart';

/// Diapositivas del Wrapped general de Biblioteca, en orden.
const diapositivasDeGeneral = <String, String>{
  'inicio': 'Portada',
  'terminados': 'Obras terminadas',
  'reparto': 'Libros, pantalla y mando',
  'horas': 'Horas de historias',
  'mejores': 'Lo mejor de cada tipo',
  'meses': 'Mes a mes',
  'dias': 'Tus días clave',
  'universo': 'Tu universo del año',
  'generos': 'Géneros',
  'creador': 'El nombre de tu año',
  'sagas': 'Sagas',
  'epocas': 'Viaje en el tiempo',
  'curiosidades': 'Datos curiosos',
  'notas': 'Tus notas',
  'propositos': 'Propósitos',
  'destacado': 'Lo mejor del año',
  'perfil': 'Perfil',
  'lo-que-viene': 'Lo que viene',
  'resumen': 'Resumen final',
};

List<DiapositivaWrapped> _diapositivasGeneral(ResumenGeneral r) {
  final d = _Lista(r, diapositivasDeGeneral);
  if (!r.hayDatos) {
    d.anadir('inicio', Paleta.noche, (c, t) => _SinDatos(r: r, t: t));
    return d.lista;
  }
  d
    ..comunes('inicio')
    ..comunes('terminados');
  if (r.terminados.isNotEmpty) {
    d.anadir('reparto', Paleta.aurora, (c, t) => _Reparto(r: r, t: t),
        duracion: 1.1);
  }
  if (r.minutosHistorias > 0 || r.juegos.hayLogros) {
    d.anadir('horas', Paleta.noche, (c, t) => _HorasHistorias(r: r, t: t));
  }
  if (_mejores(r).length >= 2) {
    d.anadir('mejores', d.paleta(r.destacado), (c, t) => _Mejores(r: r, t: t),
        duracion: 1.15);
  }
  d.comunes('meses');
  if (r.diaMasAnadidos != null || r.diaMasTerminados != null) {
    d.anadir('dias', d.paleta(), (c, t) => _DiasClave(r: r, t: t));
  }
  if (r.universos.isNotEmpty) {
    d.anadir('universo', d.paleta(r.universos.first.obras.first),
        (c, t) => _Universo(r: r, t: t));
  }
  d
    ..comunes('generos')
    ..comunes('creador')
    ..comunes('sagas')
    ..comunes('epocas')
    ..comunes('curiosidades')
    ..comunes('notas')
    ..comunes('propositos')
    ..comunes('destacado')
    ..comunes('perfil')
    ..comunes('lo-que-viene')
    ..comunes('resumen');
  return d.lista;
}

const _colorTipo = {
  LibraryItemType.book: Color(0xFFFF8FAB),
  LibraryItemType.movieSeries: Color(0xFFFFD166),
  LibraryItemType.game: Color(0xFF06D6A0),
};

const _iconoTipo = {
  LibraryItemType.book: Icons.auto_stories_rounded,
  LibraryItemType.movieSeries: Icons.movie_rounded,
  LibraryItemType.game: Icons.sports_esports_rounded,
};

// ============================================================ reparto

class _Reparto extends StatelessWidget {
  const _Reparto({required this.r, required this.t});
  final ResumenGeneral r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final filas = [
      (LibraryItemType.book, 'libros', r.libros.terminados),
      (LibraryItemType.movieSeries, 'series y pelis', r.pantalla.terminados),
      (LibraryItemType.game, 'juegos', r.juegos.terminados),
    ].where((f) => f.$3.isNotEmpty).toList();
    final total = r.terminados.length;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Libros, pantalla y mando'),
      const SizedBox(height: 6),
      _titular(t, .03, 'Así se repartió tu año', size: 32),
      const SizedBox(height: 14),
      Aparece(
        t: t,
        desde: .1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(children: [
              for (final f in filas)
                Expanded(
                  flex: math.max(1, (f.$3.length / total * 1000).round()),
                  child: Container(color: _colorTipo[f.$1]),
                ),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < filas.length; i++)
        Expanded(
          child: Aparece(
            t: t,
            desde: .16 + i * .1,
            dx: 40,
            dy: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(_iconoTipo[filas[i].$1],
                    color: _colorTipo[filas[i].$1], size: 26),
                const SizedBox(width: 10),
                SizedBox(
                  width: 92,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Contador(
                              t: t,
                              desde: .2 + i * .1,
                              valor: filas[i].$3.length,
                              estilo: TipografiaWrapped.titular(size: 46)),
                        ),
                        Text(filas[i].$2,
                            style: TipografiaWrapped.texto(
                                size: 12,
                                color: Colors.white70,
                                weight: FontWeight.w700)),
                      ]),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, caja) {
                    final alto = caja.maxHeight;
                    final ancho = alto / 1.5;
                    final obras = filas[i].$3.reversed.toList();
                    final caben = math.max(1,
                        ((caja.maxWidth - ancho) / (ancho * .45)).floor() + 1);
                    final mostradas = obras.take(caben).toList();
                    return Stack(children: [
                      for (var j = mostradas.length - 1; j >= 0; j--)
                        Positioned(
                          left: j * ancho * .45,
                          top: 0,
                          child: Opacity(
                            opacity: tramo(t, .24 + i * .1 + j * .02,
                                .36 + i * .1 + j * .02),
                            child: Portada(
                                fuente: mostradas[j].coverUrl,
                                titulo: mostradas[j].title,
                                ancho: ancho,
                                alto: alto,
                                radio: 4),
                          ),
                        ),
                    ]);
                  }),
                ),
              ]),
            ),
          ),
        ),
    ]);
  }
}

// ============================================================ horas

class _HorasHistorias extends StatelessWidget {
  const _HorasHistorias({required this.r, required this.t});
  final ResumenGeneral r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final horas = (r.minutosHistorias / 60).round();
    final datos = <(IconData, Color, String, String)>[
      if (r.libros.hayKindle)
        (
          Icons.auto_stories_rounded,
          _colorTipo[LibraryItemType.book]!,
          duracionLarga(r.libros.segundos),
          'leyendo en el Kindle · racha de ${r.libros.rachaMaxima} días'
        ),
      if (r.pantalla.minutosTotales > 0)
        (
          Icons.movie_rounded,
          _colorTipo[LibraryItemType.movieSeries]!,
          '${r.pantalla.hayEstimaciones ? '≈ ' : ''}${duracionLarga(r.pantalla.minutosTotales * 60)}',
          'frente a la pantalla con ${r.pantalla.terminados.length} títulos'
        ),
      if (r.juegos.hayLogros)
        (
          Icons.emoji_events_rounded,
          _colorTipo[LibraryItemType.game]!,
          '${miles(r.juegos.logrosDelAno.length)} logros',
          'desbloqueados en ${r.juegos.porLogros.length} juegos'
        ),
    ];
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Horas de historias'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: _cifra(t, .04, horas, size: 132)),
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
                  child: Text('horas',
                      style: TipografiaWrapped.titular(size: 36))),
            ),
          ),
        ),
      ]),
      Aparece(
        t: t,
        desde: .24,
        child: Text(
            'leyendo y viendo historias, ${decimal(r.minutosHistorias / 1440)} días seguidos sin parar. '
            'Y aún queda el mando.',
            style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
      ),
      const Spacer(),
      for (var i = 0; i < datos.length; i++)
        Aparece(
          t: t,
          desde: .32 + i * .08,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            child: Row(children: [
              Icon(datos[i].$1, color: datos[i].$2, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(datos[i].$3,
                            style: TipografiaWrapped.titular(size: 26)),
                      ),
                      Text(datos[i].$4,
                          style: TipografiaWrapped.texto(
                              size: 12, color: Colors.white70)),
                    ]),
              ),
            ]),
          ),
        ),
    ]);
  }
}

// ============================================================ mejores

List<(String, LibraryItem)> _mejores(ResumenGeneral r) => [
      if (r.libros.destacado != null) ('Libro', r.libros.destacado!),
      if (r.pantalla.destacado != null)
        (
          r.pantalla.destacado!.mediaType == LibraryMediaType.series
              ? 'Serie'
              : 'Película',
          r.pantalla.destacado!
        ),
      if (r.juegos.destacado != null) ('Juego', r.juegos.destacado!),
    ];

class _Mejores extends StatelessWidget {
  const _Mejores({required this.r, required this.t});
  final ResumenGeneral r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final mejores = _mejores(r);
    return _Marco(r: r, alineacion: CrossAxisAlignment.center, children: [
      _etiqueta(t, 0, 'Lo mejor de cada mundo'),
      const SizedBox(height: 6),
      _titular(t, .03, 'Tus imprescindibles del año',
          size: 30, align: TextAlign.center),
      const SizedBox(height: 20),
      Expanded(
        child: LayoutBuilder(builder: (context, caja) {
          final ancho = math.min(
              (caja.maxWidth - (mejores.length - 1) * 12) / mejores.length,
              (caja.maxHeight - 70) / 1.5);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < mejores.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Aparece(
                  t: t,
                  desde: .14 + i * .1,
                  dy: 40,
                  escala: .85,
                  child: SizedBox(
                    width: ancho,
                    child: Column(children: [
                      Insignia(mejores[i].$1.toUpperCase(),
                          color: _colorTipo[mejores[i].$2.type]!,
                          relleno: true),
                      const SizedBox(height: 10),
                      Transform.translate(
                        offset: Offset(0, 4 * _deriva(t, i * 1.3)),
                        child: _portada(mejores[i].$2, ancho, radio: 6),
                      ),
                      const SizedBox(height: 10),
                      _libroTitulo(mejores[i].$2,
                          size: 13, lineas: 3, align: TextAlign.center),
                      if (mejores[i].$2.rating != null) ...[
                        const SizedBox(height: 4),
                        Estrellas(mejores[i].$2.rating!, tamano: 12),
                      ],
                    ]),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    ]);
  }
}

// ============================================================ días clave

class _DiasClave extends StatelessWidget {
  const _DiasClave({required this.r, required this.t});
  final ResumenGeneral r;
  final double t;

  @override
  Widget build(BuildContext context) {
    Widget tarjeta(double desde, String etiqueta, DateTime dia, String cifra,
            String texto, List<LibraryItem> obras) =>
        Aparece(
          t: t,
          desde: desde,
          dy: 40,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: .16)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(etiqueta.toUpperCase(),
                          style: TipografiaWrapped.etiqueta(size: 9.5)),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(capitalizar(fechaLarga(dia, conDia: true)),
                            style: TipografiaWrapped.titular(size: 22)),
                      ),
                      const SizedBox(height: 6),
                      Text(cifra, style: TipografiaWrapped.titular(size: 40)),
                      Text(texto,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TipografiaWrapped.texto(
                              size: 12, color: Colors.white70)),
                    ]),
              ),
              SizedBox(
                width: 96,
                height: 120,
                child: Stack(children: [
                  for (var i = math.min(3, obras.length) - 1; i >= 0; i--)
                    Positioned(
                      left: i * 14.0,
                      top: i * 6.0,
                      child: Transform.rotate(
                        angle: (i - 1) * .08,
                        child: _portada(obras[i], 62, radio: 4),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        );
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Tus días clave'),
      const SizedBox(height: 6),
      _titular(t, .03, 'Dos días que dicen mucho de ti', size: 30),
      const Spacer(),
      if (r.diaMasAnadidos != null)
        tarjeta(
          .14,
          'El día que más añadiste',
          r.diaMasAnadidos!,
          '${r.anadidosDiaRecord}',
          r.anadidosDiaRecord == 1
              ? 'obra nueva en tu Biblioteca'
              : 'obras nuevas en tu Biblioteca de golpe',
          [],
        ),
      const SizedBox(height: 14),
      if (r.diaMasTerminados != null)
        tarjeta(
            .26,
            'El día que más terminaste',
            r.diaMasTerminados!,
            '${r.terminadosDiaRecord.length}',
            r.terminadosDiaRecord.length == 1
                ? 'obra terminada'
                : 'obras terminadas el mismo día',
            r.terminadosDiaRecord),
      const Spacer(),
    ]);
  }
}

// ============================================================ universo

class _Universo extends StatelessWidget {
  const _Universo({required this.r, required this.t});
  final ResumenGeneral r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final u = r.universos.first;
    final obras = u.obras.take(6).toList();
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Tu universo del año'),
      const SizedBox(height: 6),
      _titular(t, .03, u.nombre, size: 38),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .12,
        child: Wrap(spacing: 8, children: [
          for (final tipo in u.tipos)
            Insignia(
                switch (tipo) {
                  LibraryItemType.book => 'Libros',
                  LibraryItemType.movieSeries => 'Pantalla',
                  LibraryItemType.game => 'Juegos',
                },
                color: _colorTipo[tipo]!),
        ]),
      ),
      const SizedBox(height: 10),
      Aparece(
        t: t,
        desde: .16,
        child: Text(
            'Lo leíste, lo viste o lo jugaste: no te bastó con un formato.',
            style: TipografiaWrapped.serif(size: 17, color: Colors.white70)),
      ),
      const SizedBox(height: 16),
      Expanded(child: _Muro(libros: obras, t: t, desde: .22)),
    ]);
  }
}
