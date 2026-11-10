part of 'wrapped_diapositivas.dart';

// ============================================================ estructura común

class _Marco extends StatelessWidget {
  const _Marco({
    required this.r,
    required this.children,
    this.alineacion = CrossAxisAlignment.start,
    this.marca = true,
  });
  final ResumenObras r;
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
            _MarcaAgua(year: r.year, k: r.k),
          ],
        ]),
      );
}

class _MarcaAgua extends StatelessWidget {
  const _MarcaAgua({required this.year, required this.k});
  final int year;
  final _Rotulos k;

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
          child: Icon(k.icono, size: 10, color: Colors.black87),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text('TODO · WRAPPED $year',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style:
                  TipografiaWrapped.etiqueta(color: Colors.white54, size: 8.5)),
        ),
        Text(k.seccion,
            maxLines: 1,
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
  final ResumenObras r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final principal = r.portada!;
    final otras =
        _destacables(r).where((l) => l.id != principal.id).take(4).toList();
    final nombre = r.ajustes.nombre;
    final titulo = r.ajustes.titulo ?? r.k.tituloInicio;
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
      _MarcaAgua(year: r.year, k: r.k),
    ]);
  }
}

// ============================================================ 2. terminados

class _Terminados extends StatelessWidget {
  const _Terminados({required this.r, required this.t});
  final ResumenObras r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final n = r.terminados.length;
    final dif = n - r.terminadosAnterior;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, r.k.terminaste),
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
                  child: Text(n == 1 ? r.k.uno : r.k.varios,
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

// ============================================================ 8. mes a mes

class _Meses extends StatelessWidget {
  const _Meses({required this.r, required this.t});
  final ResumenObras r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final porMes = List.generate(12, (_) => <LibraryItem>[]);
    for (final l in r.terminados) {
      porMes[l.completedDate!.month - 1].add(l);
    }
    var mejor = 0;
    for (var m = 1; m < 12; m++) {
      final actual = porMes[m].length * 1e9 + _pesoMes(r, m);
      final previo = porMes[mejor].length * 1e9 + _pesoMes(r, mejor);
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
        child: Text(_detalleMes(r, mejor, porMes[mejor].length),
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

// ============================================================ 10. autor

class _Autor extends StatelessWidget {
  const _Autor({required this.r, required this.t});
  final ResumenObras r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final autor = r.creadores.first;
    final libros = autor.obras.reversed.take(6).toList();
    final otros =
        r.creadores.skip(1).where((a) => a.obras.length > 1).take(3).toList();
    final nuevos = r.creadores.where((a) => a.nuevo).length;
    return _Marco(r: r, children: [
      _etiqueta(t, 0, r.k.creador),
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
        child: Text('${autor.obras.length} ${r.k.varios} este año',
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
              'También: ${otros.map((a) => '${a.nombre} (${a.obras.length})').join(' · ')}',
              style:
                  TipografiaWrapped.texto(size: 12.5, color: Colors.white70)),
        ),
      const SizedBox(height: 6),
      Aparece(
        t: t,
        desde: .6,
        child: Insignia(
            '${r.creadores.length} ${r.creadores.length == 1 ? r.k.firma : r.k.firmas} en total'
            '${nuevos > 0 && nuevos < r.creadores.length ? ' · $nuevos ${nuevos == 1 ? r.k.nueva : r.k.nuevas}' : ''}'),
      ),
    ]);
  }
}

// ============================================================ 11. sagas

/// Entrega que aún no ha salido: tiene fecha prevista o sale más adelante.
bool _esEstreno(SiguienteEntrega s, int year) =>
    s.fechaPrevista != null || (s.anoSalida ?? 0) > year;

String _textoSalida(SiguienteEntrega s, int year) {
  if (s.libro?.status == LibraryItemStatus.inProgress) {
    final p = _porcentaje(s.libro!);
    return p == null ? 'Ya estás con ella' : 'Ya vas por el $p %';
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
  final ResumenObras r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final saga = r.sagas.first;
    final otras = r.sagas.skip(1).take(3).toList();
    // Solo se anuncia lo que está por salir o lo que ya se está leyendo.
    final siguiente = saga.siguiente != null &&
            (_esEstreno(saga.siguiente!, r.year) ||
                saga.siguiente!.libro?.status == LibraryItemStatus.inProgress)
        ? saga.siguiente
        : null;
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
                    '${otras[i].leidos.length} ${otras[i].leidos.length == 1 ? r.k.uno : r.k.varios}',
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
  final ResumenObras r;
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
            'en ${generos.first.value} de tus ${r.terminados.length} ${r.k.varios}',
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
  final ResumenObras r;
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
              libro: r.obraMasAntigua!,
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
              libro: r.obraMasReciente!,
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
        child: Text('De media, tus ${r.k.varios} tienen $media años.',
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

class _Curiosidades extends StatelessWidget {
  const _Curiosidades({required this.r, required this.t});
  final ResumenObras r;
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
  final ResumenObras r;
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
            'de nota media en ${r.valorados.length} ${r.k.varios} con nota',
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
  final ResumenObras r;
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

// ============================================================ 18. libro del año

class _LibroDelAno extends StatelessWidget {
  const _LibroDelAno({required this.r, required this.t});
  final ResumenObras r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final libro = r.destacado!;
    final datos = _chipsDestacado(r, libro);
    final color = ColoresPortada.deCache(libro.coverUrl) ?? Colors.white;
    return _Marco(r: r, alineacion: CrossAxisAlignment.center, children: [
      _etiqueta(t, 0, r.k.destacado),
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

class _Perfil extends StatelessWidget {
  const _Perfil({required this.r, required this.t});
  final ResumenObras r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final perfil = _perfil(r);
    final portadas = _destacables(r).take(5).toList();
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
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, caja) {
                          final alto = math.min(150.0, caja.maxHeight - 12);
                          return Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              height: math.max(0, alto),
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
                                          alto: math.max(0, alto),
                                          radio: 4,
                                          sombra: false),
                                    ),
                                  ),
                                ],
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
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

bool _hayFuturo(ResumenObras r) =>
    r.enCurso.isNotEmpty ||
    r.pendientes > 0 ||
    r.sagas.any((s) => s.siguiente != null && _esEstreno(s.siguiente!, r.year));

class _LoQueViene extends StatelessWidget {
  const _LoQueViene({required this.r, required this.t});
  final ResumenObras r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final siguiente = r.year + 1;
    final enCurso = [...r.enCurso]
      ..sort((a, b) => (_porcentaje(b) ?? -1).compareTo(_porcentaje(a) ?? -1));
    final estrenos = [
      for (final s in r.sagas)
        if (s.siguiente != null &&
            _esEstreno(s.siguiente!, r.year) &&
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
                    if (_porcentaje(enCurso.first) case final p?) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: p / 100 * tramo(t, .2, .5),
                          color: Colors.white,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('$p % ${r.k.avance}',
                          style: TipografiaWrapped.texto(
                              size: 12,
                              color: Colors.white70,
                              weight: FontWeight.w700)),
                    ] else if (enCurso.length > 1)
                      Text('y ${enCurso.length - 1} más a medias',
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
                    r.pendientes == 1 ? r.k.esperaUno : r.k.esperanVarios,
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
  final ResumenObras r;
  final double t;

  @override
  Widget build(BuildContext context) {
    final portadas = _destacables(r);
    final datos = _datosResumen(r).take(6).toList();
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
                  child: Text(r.k.enResumen,
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
                      Flexible(
                        child: Text(datos[i].$2,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TipografiaWrapped.texto(
                                size: 10.5, color: Colors.white70)),
                      ),
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
  final ResumenObras r;
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
        _titular(t, .1, r.k.sinDatos, size: 24),
        const Spacer(),
      ]);
}
// ============================================================ piezas compartidas

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

class _PintorCalendario extends CustomPainter {
  _PintorCalendario(this.dias, this.year, this.inicio, this.fin, this.t);
  final Map<DateTime, int> dias;
  final int year;
  final DateTime? inicio, fin;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const columnas = 3, filas = 4;
    final anchoMes = size.width / columnas;
    final altoMes = size.height / filas;
    final celda = math.min((anchoMes - 10) / 7, (altoMes - 22) / 6);
    final maximo = dias.values.fold<int>(1, math.max);
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
      final primero = DateTime(year, m + 1, 1);
      final diasMes = DateTime(year, m + 2, 0).day;
      for (var d = 0; d < diasMes; d++) {
        final fecha = DateTime(year, m + 1, d + 1);
        final pos = d + primero.weekday - 1;
        final x = ox + (pos % 7) * celda;
        final y = oy + 16 + (pos ~/ 7) * celda;
        final s = dias[fecha] ?? 0;
        final enRacha =
            inicio != null && !fecha.isBefore(inicio!) && !fecha.isAfter(fin!);
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
  bool shouldRepaint(_PintorCalendario old) => old.t != t || old.dias != dias;
}
