part of 'wrapped_diapositivas.dart';

/// Diapositivas del Wrapped de series y películas, en orden.
const diapositivasDePantalla = <String, String>{
  'inicio': 'Portada',
  'terminados': 'Títulos vistos',
  'pantalla': 'Horas frente a la pantalla',
  'extremos': 'La más larga y la más corta',
  'maraton': 'Tu maratón',
  'semana': 'Tu día de sofá',
  'meses': 'Mes a mes',
  'creador': 'Detrás de la cámara',
  'paises': 'Vuelta al mundo',
  'sagas': 'Sagas',
  'generos': 'Géneros',
  'estrenos': 'Estrenos del año',
  'epocas': 'Viaje en el tiempo',
  'curiosidades': 'Datos curiosos',
  'notas': 'Tus notas',
  'propositos': 'Propósitos',
  'destacado': 'Lo mejor del año',
  'perfil': 'Perfil',
  'lo-que-viene': 'Lo que viene',
  'resumen': 'Resumen final',
};

List<DiapositivaWrapped> _diapositivasPantalla(ResumenPantalla r) {
  final d = _Lista(r, diapositivasDePantalla);
  if (!r.hayDatos) {
    d.anadir('inicio', Paleta.noche, (c, t) => _SinDatos(r: r, t: t));
    return d.lista;
  }
  d
    ..comunes('inicio')
    ..comunes('terminados');
  if (r.minutosTotales > 0) {
    d.anadir('pantalla', Paleta.noche, (c, t) => _HorasPantalla(r: r, t: t));
  }
  if (r.masLarga != null && r.masCorta != null && r.masLarga != r.masCorta) {
    d.anadir('extremos', d.paleta(r.masLarga),
        (c, t) => _ExtremosPantalla(r: r, t: t));
  }
  if (r.terminadosDiaRecord.length >= 2) {
    d.anadir('maraton', d.paleta(r.terminadosDiaRecord.first),
        (c, t) => _Maraton(r: r, t: t));
  }
  if (r.terminados.length >= 5) {
    d.anadir('semana', d.paleta(), (c, t) => _DiaDeSofa(r: r, t: t));
  }
  d
    ..comunes('meses')
    ..comunes('creador');
  if (r.paises.length >= 2) {
    d.anadir('paises', Paleta.oceano, (c, t) => _Paises(r: r, t: t));
  }
  d
    ..comunes('sagas')
    ..comunes('generos');
  if (r.estrenos.length >= 2) {
    d.anadir(
        'estrenos', d.paleta(r.estrenos.last), (c, t) => _Estrenos(r: r, t: t));
  }
  d
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

// ============================================================ horas

class _HorasPantalla extends StatelessWidget {
  const _HorasPantalla({required this.r, required this.t});
  final ResumenPantalla r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final horas = (r.minutosTotales / 60).round();
    final dias = r.minutosTotales / 1440;
    final fraccionPelis =
        r.minutosTotales == 0 ? 0.0 : r.minutosPeliculas / r.minutosTotales;
    Widget barra(String titulo, int minutos, int cuantas, String unidad,
            Color color, double desde) =>
        Aparece(
          t: t,
          desde: desde,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            child: Row(children: [
              Container(
                width: 10,
                height: 44,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo.toUpperCase(),
                          style: TipografiaWrapped.etiqueta(size: 9.5)),
                      const SizedBox(height: 2),
                      Text('$cuantas $unidad',
                          style: TipografiaWrapped.titular(size: 24)),
                    ]),
              ),
              Text(duracionLarga(minutos * 60).split(' ').take(2).join(' '),
                  style: TipografiaWrapped.titular(size: 22)),
            ]),
          ),
        );
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Frente a la pantalla'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(
            child: _cifra(t, .04, horas,
                size: 132,
                formato: (v) => '${r.hayEstimaciones ? '≈' : ''}${v.round()}')),
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
            'Son ${decimal(dias)} días enteros de sofá'
            '${r.episodios > 0 ? ' y ${r.episodios} episodios' : ''}.',
            style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
      ),
      const SizedBox(height: 22),
      Aparece(
        t: t,
        desde: .3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 16,
            child: Row(children: [
              Expanded(
                flex: math.max(1, (fraccionPelis * 1000).round()),
                child: Container(color: const Color(0xFFFFD166)),
              ),
              Expanded(
                flex: math.max(1, ((1 - fraccionPelis) * 1000).round()),
                child: Container(color: const Color(0xFF06D6A0)),
              ),
            ]),
          ),
        ),
      ),
      const Spacer(),
      barra(
          'Películas',
          r.minutosPeliculas,
          r.peliculas.length,
          r.peliculas.length == 1 ? 'película' : 'películas',
          const Color(0xFFFFD166),
          .36),
      const SizedBox(height: 10),
      barra(
          'Series',
          r.minutosSeries,
          r.series.length,
          r.series.length == 1 ? 'serie' : 'series',
          const Color(0xFF06D6A0),
          .44),
      if (r.hayEstimaciones) ...[
        const SizedBox(height: 10),
        Aparece(
          t: t,
          desde: .52,
          child: Text(
              'Calculado con la duración de cada ficha; donde falta, estimado.',
              style:
                  TipografiaWrapped.texto(size: 10.5, color: Colors.white54)),
        ),
      ],
    ]);
  }
}

// ============================================================ extremos

class _ExtremosPantalla extends StatelessWidget {
  const _ExtremosPantalla({required this.r, required this.t});
  final ResumenPantalla r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final larga = r.masLarga!, corta = r.masCorta!;
    final ml = r.minutos[larga]!.minutos, mc = r.minutos[corta]!.minutos;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Palomitas para rato'),
      const SizedBox(height: 6),
      _titular(
          t, .04, 'De ${duracionLarga(mc * 60)} a ${duracionLarga(ml * 60)}',
          size: 32),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .14,
        child: Text(
            'La más larga dura ${decimal(ml / mc)} veces lo que la más corta.',
            style: TipografiaWrapped.serif(size: 17, color: Colors.white70)),
      ),
      const Spacer(),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: _Extremo(
              t: t,
              desde: .24,
              etiqueta: 'La más larga',
              libro: larga,
              paginas: 0,
              detalle: duracionLarga(ml * 60),
              ancho: 132),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _Extremo(
              t: t,
              desde: .34,
              etiqueta: 'La más corta',
              libro: corta,
              paginas: 0,
              detalle: duracionLarga(mc * 60),
              ancho: 96),
        ),
      ]),
      const Spacer(),
    ]);
  }
}

// ============================================================ maratón

class _Maraton extends StatelessWidget {
  const _Maraton({required this.r, required this.t});
  final ResumenPantalla r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final obras = r.terminadosDiaRecord.take(4).toList();
    final minutos =
        obras.fold<int>(0, (s, o) => s + (r.minutos[o]?.minutos ?? 0));
    return _Marco(r: r, alineacion: CrossAxisAlignment.center, children: [
      _etiqueta(t, 0, 'Tu maratón'),
      const SizedBox(height: 10),
      _titular(
          t, .04, capitalizar(fechaLarga(r.diaMasTerminados!, conDia: true)),
          size: 30, align: TextAlign.center),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .12,
        child: Text(
            '${r.terminadosDiaRecord.length} títulos en un día · ${duracionLarga(minutos * 60)}',
            style: TipografiaWrapped.serif(size: 17, color: Colors.white70)),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, caja) {
          final ancho =
              math.min(150.0, caja.maxWidth / (obras.length * .62 + .4));
          return Stack(alignment: Alignment.center, children: [
            const SizedBox.expand(),
            for (var i = 0; i < obras.length; i++)
              Builder(builder: (context) {
                final rel = i - (obras.length - 1) / 2;
                final v =
                    tramo(t, .2 + i * .08, .5 + i * .08, Curves.easeOutBack);
                return Transform.translate(
                  offset: Offset(rel * ancho * .62 * v,
                      rel.abs() * 14 + 3 * _deriva(t, i * 1.0)),
                  child: Transform.rotate(
                    angle: rel * .1 * v,
                    child: Opacity(
                      opacity: tramo(t, .18 + i * .08, .3 + i * .08),
                      child: _portada(obras[i], ancho),
                    ),
                  ),
                );
              }),
          ]);
        }),
      ),
      Aparece(
        t: t,
        desde: .5,
        child: Text(obras.map((o) => o.title).join(' · '),
            maxLines: 3,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TipografiaWrapped.texto(size: 13, color: Colors.white)),
      ),
    ]);
  }
}

// ============================================================ día de sofá

class _DiaDeSofa extends StatelessWidget {
  const _DiaDeSofa({required this.r, required this.t});
  final ResumenPantalla r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final valores = r.terminadosPorDiaSemana;
    final maximo = valores.fold<int>(1, math.max);
    var mejor = 0;
    for (var i = 1; i < 7; i++) {
      if (valores[i] > valores[mejor]) mejor = i;
    }
    final finde = valores[5] + valores[6];
    final total = valores.fold<int>(0, (a, b) => a + b);
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Tu día de sofá'),
      const SizedBox(height: 6),
      _titular(t, .04,
          'Los ${diasSemana[mejor].endsWith('s') ? diasSemana[mejor] : '${diasSemana[mejor]}s'} son para ver algo',
          size: 34),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .14,
        child: Text(
            '${valores[mejor]} de tus ${r.terminados.length} títulos los terminaste en ${diasSemana[mejor]}. '
            '${finde * 2 > total ? 'El fin de semana manda.' : 'Ni siquiera esperas al fin de semana.'}',
            style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
      ),
      const SizedBox(height: 22),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child:
                  Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${valores[i]}',
                    style: TipografiaWrapped.texto(
                        size: 12,
                        weight: FontWeight.w800,
                        color: i == mejor ? Colors.white : Colors.white54)),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, caja) => Container(
                    height: math.max(
                        6,
                        220 *
                            valores[i] /
                            maximo *
                            tramo(t, .2 + i * .04, .55 + i * .04,
                                Curves.easeOutBack)),
                    decoration: BoxDecoration(
                      color: i == mejor
                          ? Colors.white
                          : Colors.white.withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(diasSemana[i].substring(0, 1).toUpperCase(),
                    style: TipografiaWrapped.texto(
                        size: 12,
                        weight: FontWeight.w800,
                        color: i == mejor ? Colors.white : Colors.white54)),
              ]),
            ),
          ],
        ]),
      ),
    ]);
  }
}

// ============================================================ países

class _Paises extends StatelessWidget {
  const _Paises({required this.r, required this.t});
  final ResumenPantalla r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final paises = r.paises.take(6).toList();
    final maximo = paises.first.value;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Vuelta al mundo'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: _cifra(t, .04, r.paises.length, size: 112)),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Aparece(
                  t: t,
                  desde: .18,
                  child: Text(r.paises.length == 1 ? 'país' : 'países',
                      style: TipografiaWrapped.titular(size: 32))),
            ),
          ),
        ),
      ]),
      Aparece(
        t: t,
        desde: .22,
        child: Text('detrás de lo que viste este año.',
            style: TipografiaWrapped.serif(size: 18, color: Colors.white70)),
      ),
      const SizedBox(height: 24),
      for (var i = 0; i < paises.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Aparece(
            t: t,
            desde: .28 + i * .06,
            dx: -30,
            dy: 0,
            child: Row(children: [
              SizedBox(
                width: 116,
                child: Text(paises[i].key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TipografiaWrapped.texto(
                        size: 14, weight: FontWeight.w800)),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: math.max(
                        .04,
                        paises[i].value /
                            maximo *
                            tramo(t, .32 + i * .06, .62 + i * .06)),
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? Colors.white
                            : Colors.white.withValues(alpha: .45),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: Text('${paises[i].value}',
                    textAlign: TextAlign.right,
                    style: TipografiaWrapped.texto(
                        size: 13,
                        color: Colors.white70,
                        weight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      const Spacer(),
    ]);
  }
}

// ============================================================ estrenos

class _Estrenos extends StatelessWidget {
  const _Estrenos({required this.r, required this.t});
  final ResumenPantalla r;
  final double t;

  @override
  Widget build(BuildContext context) {
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Recién salidos del horno'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: _cifra(t, .04, r.estrenos.length, size: 112)),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Aparece(
                  t: t,
                  desde: .18,
                  child: Text('estrenos de ${r.year}',
                      style: TipografiaWrapped.titular(size: 30))),
            ),
          ),
        ),
      ]),
      Aparece(
        t: t,
        desde: .22,
        child: Text('Lo más nuevo no se te escapa.',
            style: TipografiaWrapped.serif(size: 18, color: Colors.white70)),
      ),
      const SizedBox(height: 16),
      Expanded(
          child: _Muro(libros: r.estrenos.reversed.toList(), t: t, desde: .26)),
    ]);
  }
}
