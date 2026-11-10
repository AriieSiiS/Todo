part of 'wrapped_diapositivas.dart';

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
  final d = _Lista(r, diapositivasDeLibros);
  if (!r.hayDatos) {
    d.anadir('inicio', Paleta.noche, (c, t) => _SinDatos(r: r, t: t));
    return d.lista;
  }
  d
    ..comunes('inicio')
    ..comunes('terminados');
  if (r.paginasPorLibro.length >= 2) {
    d.anadir('paginas', d.paleta(), (c, t) => _Paginas(r: r, t: t));
  }
  // Las del Kindle salen con cualquier lectura registrada, por poca que sea.
  if (r.hayKindle) {
    d.anadir('kindle', d.paleta(r.porTiempo.first.libro),
        (c, t) => _Kindle(r: r, t: t));
    d.anadir('calendario', d.paleta(), (c, t) => _Calendario(r: r, t: t),
        duracion: 1.15);
    if (r.diaRecord != null) {
      d.anadir('dia-record', d.paleta(r.libroDiaRecord),
          (c, t) => _DiaRecord(r: r, t: t));
    }
    d.anadir('reloj', Paleta.noche, (c, t) => _Reloj(r: r, t: t));
  }
  d.comunes('meses');
  if (r.porTiempo.where((e) => e.segundos >= 900).length >= 2) {
    d.anadir(
        'top', d.paleta(r.porTiempo.first.libro), (c, t) => _Top(r: r, t: t),
        duracion: 1.15);
  }
  d
    ..comunes('creador', 'autor')
    ..comunes('sagas')
    ..comunes('generos')
    ..comunes('epocas')
    ..comunes('curiosidades')
    ..comunes('notas')
    ..comunes('propositos');
  if (r.citaDestacada != null) {
    d.anadir(
        'cita', d.paleta(r.citaDestacada!.libro), (c, t) => _Cita(r: r, t: t),
        duracion: 1.15);
  }
  d
    ..comunes('destacado', 'libro-del-ano')
    ..comunes('perfil')
    ..comunes('lo-que-viene')
    ..comunes('resumen');
  return d.lista;
}

/// Portadas que conviene precargar antes de reproducir.
Iterable<String?> portadasDeLibros(ResumenLibros r) => portadasDe(r);

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
            painter: _PintorCalendario(
                r.segundosPorDia, r.year, r.inicioRacha, r.finRacha, t),
          ),
        ),
      ),
    ]);
  }
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

class _Reloj extends StatelessWidget {
  const _Reloj({required this.r, required this.t});
  final ResumenLibros r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final momento = _momento(r.segundosPorHora);
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
