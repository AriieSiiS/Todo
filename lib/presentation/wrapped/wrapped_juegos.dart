part of 'wrapped_diapositivas.dart';

/// Diapositivas del Wrapped de videojuegos, en orden.
const diapositivasDeJuegos = <String, String>{
  'inicio': 'Portada',
  'terminados': 'Juegos completados',
  'logros': 'Logros del año',
  'calendario': 'Calendario de logros',
  'dia-record': 'Tu día de vicio',
  'reloj': 'Cuándo juegas',
  'raro': 'Tu logro más raro',
  'top-logros': 'Los que más logros te dieron',
  'cien': 'Al 100 %',
  'horas': 'Horas en Steam',
  'meses': 'Mes a mes',
  'creador': 'El estudio de tu año',
  'sagas': 'Sagas',
  'generos': 'Géneros',
  'epocas': 'Viaje en el tiempo',
  'curiosidades': 'Datos curiosos',
  'notas': 'Tus notas',
  'propositos': 'Propósitos',
  'destacado': 'Juego del año',
  'perfil': 'Perfil',
  'lo-que-viene': 'Lo que viene',
  'resumen': 'Resumen final',
};

List<DiapositivaWrapped> _diapositivasJuegos(ResumenJuegos r) {
  final d = _Lista(r, diapositivasDeJuegos);
  if (!r.hayDatos) {
    d.anadir('inicio', Paleta.noche, (c, t) => _SinDatos(r: r, t: t));
    return d.lista;
  }
  d
    ..comunes('inicio')
    ..comunes('terminados');
  if (r.hayLogros) {
    d.anadir('logros', Paleta.oro, (c, t) => _Logros(r: r, t: t));
    d.anadir('calendario', d.paleta(), (c, t) => _CalendarioLogros(r: r, t: t),
        duracion: 1.15);
    if (r.diaRecordLogros != null) {
      d.anadir('dia-record', d.paleta(r.juegoDiaRecord),
          (c, t) => _DiaDeVicio(r: r, t: t));
    }
    d.anadir('reloj', Paleta.noche, (c, t) => _RelojJuegos(r: r, t: t));
    if (r.logroMasRaro != null) {
      d.anadir('raro', Paleta.orquidea, (c, t) => _LogroRaro(r: r, t: t));
    }
    if (r.porLogros.length >= 2) {
      d.anadir('top-logros', d.paleta(r.porLogros.first.juego),
          (c, t) => _TopLogros(r: r, t: t),
          duracion: 1.15);
    }
  }
  if (r.completados.isNotEmpty) {
    d.anadir('cien', Paleta.oro, (c, t) => _Cien(r: r, t: t));
  }
  if (r.porHoras.length >= 2) {
    d.anadir('horas', d.paleta(r.porHoras.first.juego),
        (c, t) => _HorasSteam(r: r, t: t),
        duracion: 1.1);
  }
  d
    ..comunes('meses')
    ..comunes('creador')
    ..comunes('sagas')
    ..comunes('generos')
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

/// Icono de un logro de Steam guardado en disco.
class _IconoLogro extends StatelessWidget {
  const _IconoLogro({required this.ruta, required this.tamano});
  final String? ruta;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final proveedor = proveedorPortada(ruta, ancho: 256);
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tamano * .18),
        color: Colors.white12,
        boxShadow: const [
          BoxShadow(
              color: Color(0x88000000), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: proveedor == null
          ? Icon(Icons.emoji_events_rounded,
              color: Colors.white70, size: tamano * .5)
          : Image(image: proveedor, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}

// ============================================================ logros

class _Logros extends StatelessWidget {
  const _Logros({required this.r, required this.t});
  final ResumenJuegos r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final iconos = [
      for (final l in r.logrosDelAno.reversed)
        if (l.icono != null) l.icono
    ].take(24).toList();
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Este año desbloqueaste'),
      _cifra(t, .04, r.logrosDelAno.length, size: 120),
      Aparece(
        t: t,
        desde: .2,
        child: Text('logros', style: TipografiaWrapped.titular(size: 36)),
      ),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .24,
        child: Text(
            'en ${r.porLogros.length} ${r.porLogros.length == 1 ? 'juego' : 'juegos'}. '
            'Uno cada ${decimal(365 / math.max(1, r.logrosDelAno.length))} días de media.',
            style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
      ),
      const SizedBox(height: 18),
      Expanded(
        child: LayoutBuilder(builder: (context, caja) {
          const columnas = 6;
          final lado = (caja.maxWidth - (columnas - 1) * 8) / columnas;
          final filas =
              math.max(1, ((caja.maxHeight + 8) / (lado + 8)).floor());
          final mostrados = iconos.take(filas * columnas).toList();
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < mostrados.length; i++)
              Aparece(
                t: t,
                desde: .28 + i * (.3 / math.max(1, mostrados.length)),
                escala: .4,
                dy: 0,
                duracion: .1,
                child: _IconoLogro(ruta: mostrados[i], tamano: lado),
              ),
          ]);
        }),
      ),
    ]);
  }
}

// ============================================================ calendario

class _CalendarioLogros extends StatelessWidget {
  const _CalendarioLogros({required this.r, required this.t});
  final ResumenJuegos r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final inicio = r.inicioRacha, fin = r.finRacha;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Tu racha de logros'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: _cifra(t, .04, r.rachaLogros, size: 112)),
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
                  child: Text(r.rachaLogros == 1 ? 'día' : 'días seguidos',
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
              r.rachaLogros == 1
                  ? '${r.logrosPorDia.length} días del año con algún logro.'
                  : 'Del ${fechaLarga(inicio)} al ${fechaLarga(fin)}, sin un día sin logro. '
                      '${r.logrosPorDia.length} días con logros en total.',
              style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
        ),
      const SizedBox(height: 16),
      Expanded(
        child: LayoutBuilder(
          builder: (context, caja) => CustomPaint(
            size: caja.biggest,
            painter: _PintorCalendario(
                r.logrosPorDia, r.year, r.inicioRacha, r.finRacha, t),
          ),
        ),
      ),
    ]);
  }
}

// ============================================================ día de vicio

class _DiaDeVicio extends StatelessWidget {
  const _DiaDeVicio({required this.r, required this.t});
  final ResumenJuegos r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final juego = r.juegoDiaRecord!;
    return _Marco(r: r, alineacion: CrossAxisAlignment.center, children: [
      _etiqueta(t, 0, 'Tu día de vicio'),
      const SizedBox(height: 10),
      _titular(
          t, .05, capitalizar(fechaLarga(r.diaRecordLogros!, conDia: true)),
          size: 30, align: TextAlign.center),
      const SizedBox(height: 18),
      Expanded(
        child: Center(
          child: Transform.rotate(
            angle: .05 - .015 * _deriva(t),
            child: Aparece(
              t: t,
              desde: .2,
              escala: .7,
              dy: 0,
              child: _portada(juego, 168, radio: 8),
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
          valor: r.logrosDiaRecord,
          formato: (v) => '${v.round()} logros',
          estilo: TipografiaWrapped.titular(size: 60),
        ),
      ),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .44,
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'en un solo día con '),
            TextSpan(
                text: '«${juego.title}»',
                style: TipografiaWrapped.serif(size: 15, color: Colors.white)),
          ]),
          textAlign: TextAlign.center,
          style: TipografiaWrapped.texto(size: 14, color: Colors.white70),
        ),
      ),
    ]);
  }
}

// ============================================================ reloj

class _RelojJuegos extends StatelessWidget {
  const _RelojJuegos({required this.r, required this.t});
  final ResumenJuegos r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final momento = _momento(r.logrosPorHora);
    var punta = 0;
    for (var h = 1; h < 24; h++) {
      if (r.logrosPorHora[h] > r.logrosPorHora[punta]) punta = h;
    }
    var dia = 0;
    for (var d = 1; d < 7; d++) {
      if (r.logrosPorDiaSemana[d] > r.logrosPorDiaSemana[dia]) dia = d;
    }
    return _Marco(r: r, alineacion: CrossAxisAlignment.center, children: [
      _etiqueta(t, 0, 'Cuándo juegas'),
      const SizedBox(height: 8),
      Expanded(
        child: Stack(alignment: Alignment.center, children: [
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(painter: _PintorReloj(r.logrosPorHora, t)),
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
              Text('tu hora de más logros',
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
            '${momento.detalle}, y tu día con más logros es el ${diasSemana[dia]}.',
            textAlign: TextAlign.center,
            style: TipografiaWrapped.texto(size: 14, color: Colors.white70)),
      ),
    ]);
  }
}

// ============================================================ logro raro

class _LogroRaro extends StatelessWidget {
  const _LogroRaro({required this.r, required this.t});
  final ResumenJuegos r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final l = r.logroMasRaro!;
    final pct = l.porcentajeGlobal ?? 0;
    return _Marco(r: r, alineacion: CrossAxisAlignment.center, children: [
      _etiqueta(t, 0, 'Tu logro más raro'),
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
            scale: (.5 + .5 * tramo(t, .1, .4, Curves.easeOutBack)) *
                (1 + .04 * t),
            child: Opacity(
              opacity: tramo(t, .08, .2),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFFFD166).withValues(alpha: .55),
                        blurRadius: 60,
                        spreadRadius: 6),
                  ],
                ),
                child: _IconoLogro(ruta: l.icono, tamano: 150),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Aparece(
        t: t,
        desde: .4,
        child: Text(l.nombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TipografiaWrapped.titular(size: 30)),
      ),
      if (l.descripcion.isNotEmpty)
        Aparece(
          t: t,
          desde: .45,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.descripcion,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style:
                    TipografiaWrapped.serif(size: 16, color: Colors.white70)),
          ),
        ),
      const SizedBox(height: 14),
      Aparece(
        t: t,
        desde: .52,
        child: Insignia('Solo el ${decimal(pct)} % de los jugadores lo tiene',
            relleno: true, color: const Color(0xFFFFD166)),
      ),
      const SizedBox(height: 8),
      Aparece(
        t: t,
        desde: .58,
        child: Text('${l.juego.title} · ${fechaLarga(l.cuando)}',
            textAlign: TextAlign.center,
            style: TipografiaWrapped.texto(size: 12, color: Colors.white60)),
      ),
    ]);
  }
}

// ============================================================ top logros

class _TopLogros extends StatelessWidget {
  const _TopLogros({required this.r, required this.t});
  final ResumenJuegos r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final top = r.porLogros.take(5).toList();
    final maximo = top.first.delAno;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Los que más logros te dieron'),
      const SizedBox(height: 6),
      _titular(t, .03, 'Tu top de logros', size: 32),
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
                      fuente: top[i].juego.coverUrl,
                      titulo: top[i].juego.title,
                      radio: 4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _libroTitulo(top[i].juego, size: 14),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            value: top[i].delAno /
                                maximo *
                                tramo(t, .25 + i * .07, .6 + i * .07),
                            backgroundColor: Colors.white12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            '${top[i].delAno} este año · ${top[i].desbloqueados} de ${top[i].total} (${top[i].porcentaje.round()} %)',
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

// ============================================================ al 100 %

class _Cien extends StatelessWidget {
  const _Cien({required this.r, required this.t});
  final ResumenJuegos r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final juegos = r.completados.take(6).toList();
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Al 100 %'),
      const SizedBox(height: 6),
      _titular(
          t,
          .04,
          juegos.length == 1
              ? 'Todos los logros de un juego'
              : 'Todos los logros de ${juegos.length} juegos',
          size: 32),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .14,
        child: Text('Sin dejarte ni uno. Eso es dedicación.',
            style: TipografiaWrapped.serif(size: 17, color: Colors.white70)),
      ),
      const SizedBox(height: 18),
      Expanded(
        child: LayoutBuilder(builder: (context, caja) {
          final columnas = juegos.length <= 2 ? juegos.length : 3;
          final ancho =
              math.min(150.0, (caja.maxWidth - (columnas - 1) * 14) / columnas);
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < juegos.length; i++)
                Aparece(
                  t: t,
                  desde: .2 + i * .07,
                  escala: .7,
                  dy: 20,
                  child: SizedBox(
                    width: ancho,
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(colors: [
                            Color(0xFFFFE08A),
                            Color(0xFFB8860B),
                            Color(0xFFFFF4C2),
                          ]),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFFFD166).withValues(
                                    alpha: .4 + .2 * _deriva(t, i * 1.0)),
                                blurRadius: 24),
                          ],
                        ),
                        child: _portada(juegos[i].juego, ancho - 6, radio: 5),
                      ),
                      const SizedBox(height: 8),
                      Text(juegos[i].juego.title,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TipografiaWrapped.texto(
                              size: 12, weight: FontWeight.w800)),
                      Text(
                          '${juegos[i].total} logros · ${fechaLarga(juegos[i].completadoEn!)}',
                          textAlign: TextAlign.center,
                          style: TipografiaWrapped.texto(
                              size: 10.5, color: Colors.white60)),
                    ]),
                  ),
                ),
            ],
          );
        }),
      ),
    ]);
  }
}

// ============================================================ horas Steam

class _HorasSteam extends StatelessWidget {
  const _HorasSteam({required this.r, required this.t});
  final ResumenJuegos r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final top = r.porHoras.take(5).toList();
    final maximo = (top.first.minutos ?? 1).toDouble();
    final total = (r.minutosJugados / 60).round();
    return _Marco(r: r, children: [
      _etiqueta(t, 0, 'Horas en Steam'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(child: _cifra(t, .04, total, size: 104)),
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
                  child: Text('horas',
                      style: TipografiaWrapped.titular(size: 32))),
            ),
          ),
        ),
      ]),
      Aparece(
        t: t,
        desde: .22,
        child: Text(
            'acumuladas en los ${r.porHoras.length} juegos que tocaste este año (desde que los tienes).',
            style: TipografiaWrapped.texto(size: 13, color: Colors.white70)),
      ),
      const SizedBox(height: 18),
      for (var i = 0; i < top.length; i++)
        Expanded(
          child: Aparece(
            t: t,
            desde: .26 + i * .06,
            dx: -30,
            dy: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Portada(
                      fuente: top[i].juego.coverUrl,
                      titulo: top[i].juego.title,
                      radio: 4,
                      sombra: false),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _libroTitulo(top[i].juego, size: 13, lineas: 1),
                        const SizedBox(height: 6),
                        FractionallySizedBox(
                          widthFactor: math.max(
                              .04,
                              (top[i].minutos ?? 0) /
                                  maximo *
                                  tramo(t, .3 + i * .06, .62 + i * .06)),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: i == 0
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: .45),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ]),
                ),
                const SizedBox(width: 8),
                Text('${((top[i].minutos ?? 0) / 60).round()} h',
                    style: TipografiaWrapped.titular(size: 20)),
              ]),
            ),
          ),
        ),
      if (top.length < 5) Spacer(flex: 5 - top.length),
    ]);
  }
}
