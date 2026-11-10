import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/wrapped/resumen_general.dart';
import '../../application/wrapped/wrapped_modelo.dart';
import '../../domain/models.dart';
import 'wrapped_piezas.dart';
import 'wrapped_reproductor.dart';

part 'wrapped_comun.dart';
part 'wrapped_libros.dart';
part 'wrapped_pantalla.dart';
part 'wrapped_juegos.dart';
part 'wrapped_general.dart';

/// Diapositivas de cualquier Wrapped a partir de su resumen ya calculado.
List<DiapositivaWrapped> diapositivasDe(ResumenObras r) => switch (r) {
      ResumenLibros l => diapositivasLibros(l),
      ResumenPantalla p => _diapositivasPantalla(p),
      ResumenJuegos j => _diapositivasJuegos(j),
      ResumenGeneral g => _diapositivasGeneral(g),
      _ => const [],
    };

/// Identificadores y nombres de las diapositivas de cada tipo, en orden.
Map<String, String> nombresDiapositivas(WrappedTipo tipo) => switch (tipo) {
      WrappedTipo.libros => diapositivasDeLibros,
      WrappedTipo.pantalla => diapositivasDePantalla,
      WrappedTipo.juegos => diapositivasDeJuegos,
      WrappedTipo.general => diapositivasDeGeneral,
    };

/// Portadas e iconos que conviene precargar antes de reproducir.
Iterable<String?> portadasDe(ResumenObras r) => {
      for (final l in r.terminados) l.coverUrl,
      for (final l in _destacables(r)) l.coverUrl,
      for (final s in r.sagas) ...[
        s.enCurso?.coverUrl,
        s.siguiente?.portada,
      ],
      for (final l in r.enCurso) l.coverUrl,
      for (final p in r.listaPropositos) p.portada,
      r.portada?.coverUrl,
      if (r is ResumenJuegos) ...[
        r.logroMasRaro?.icono,
        for (final l in r.logrosDelAno.take(40)) l.icono,
      ],
      if (r is ResumenGeneral) ...[
        ...portadasDe(r.libros),
        ...portadasDe(r.pantalla),
        ...portadasDe(r.juegos),
      ],
    };

// ============================================================ rótulos

/// Palabras que cambian según el tipo de Wrapped.
class _Rotulos {
  const _Rotulos({
    required this.seccion,
    required this.icono,
    required this.uno,
    required this.varios,
    required this.terminaste,
    required this.tituloInicio,
    required this.creador,
    required this.destacado,
    required this.esperaUno,
    required this.esperanVarios,
    required this.enResumen,
    required this.sinDatos,
    this.firma = 'firma',
    this.firmas = 'firmas',
    this.nueva = 'nueva',
    this.nuevas = 'nuevas',
    this.avance = 'leído',
  });
  final String seccion;
  final IconData icono;
  final String uno, varios;
  final String terminaste;
  final String tituloInicio;
  final String creador;
  final String destacado;
  final String esperaUno, esperanVarios;
  final String enResumen;
  final String sinDatos;
  final String firma, firmas, nueva, nuevas;
  final String avance;
}

const _rotulosLibros = _Rotulos(
  seccion: 'Libros',
  icono: Icons.auto_stories_rounded,
  uno: 'libro',
  varios: 'libros',
  terminaste: 'Este año terminaste',
  tituloInicio: 'Tu año en libros',
  creador: 'La pluma de tu año',
  destacado: 'Y tu libro del año es…',
  esperaUno: 'libro te espera en la estantería',
  esperanVarios: 'libros te esperan en la estantería',
  enResumen: 'en libros',
  sinDatos: 'Este año aún no hay libros terminados ni lectura en el Kindle.',
);

const _rotulosPantalla = _Rotulos(
  seccion: 'Series y pelis',
  icono: Icons.movie_rounded,
  uno: 'título',
  varios: 'títulos',
  terminaste: 'Este año viste',
  tituloInicio: 'Tu año en series y películas',
  creador: 'Detrás de la cámara',
  destacado: 'Y lo mejor que viste fue…',
  esperaUno: 'título te espera en tu lista',
  esperanVarios: 'títulos te esperan en tu lista',
  enResumen: 'en pantalla',
  sinDatos: 'Este año aún no hay series ni películas terminadas.',
  avance: 'visto',
);

const _rotulosJuegos = _Rotulos(
  seccion: 'Videojuegos',
  icono: Icons.sports_esports_rounded,
  uno: 'juego',
  varios: 'juegos',
  terminaste: 'Este año completaste',
  tituloInicio: 'Tu año jugando',
  creador: 'El estudio de tu año',
  destacado: 'Y tu juego del año es…',
  esperaUno: 'juego te espera en la biblioteca',
  esperanVarios: 'juegos te esperan en la biblioteca',
  enResumen: 'jugando',
  sinDatos: 'Este año aún no hay juegos completados ni logros.',
  firma: 'estudio',
  firmas: 'estudios',
  nueva: 'nuevo',
  nuevas: 'nuevos',
  avance: 'completado',
);

const _rotulosGeneral = _Rotulos(
  seccion: 'Biblioteca',
  icono: Icons.collections_bookmark_rounded,
  uno: 'obra',
  varios: 'obras',
  terminaste: 'Este año terminaste',
  tituloInicio: 'Tu año en Biblioteca',
  creador: 'El nombre de tu año',
  destacado: 'Y lo mejor de tu año fue…',
  esperaUno: 'obra te espera en Biblioteca',
  esperanVarios: 'obras te esperan en Biblioteca',
  enResumen: 'en Biblioteca',
  sinDatos: 'Este año aún no hay nada terminado en Biblioteca.',
);

extension _ConRotulos on ResumenObras {
  _Rotulos get k => switch (this) {
        ResumenLibros() => _rotulosLibros,
        ResumenPantalla() => _rotulosPantalla,
        ResumenJuegos() => _rotulosJuegos,
        _ => _rotulosGeneral,
      };
}

// ============================================================ datos por tipo

/// Obras para portadas y mosaicos: las terminadas y, según el tipo, las que
/// tuvieron horas de Kindle o logros sin terminarse.
List<LibraryItem> _destacables(ResumenObras r) {
  final lista = switch (r) {
    ResumenLibros l => [
        ...l.terminados.reversed,
        ...l.porTiempo.map((e) => e.libro)
      ],
    ResumenJuegos j => [
        ...j.terminados.reversed,
        ...j.porLogros.map((e) => e.juego)
      ],
    ResumenGeneral g => _intercalar([
        _destacables(g.libros),
        _destacables(g.pantalla),
        _destacables(g.juegos),
      ]),
    _ => r.terminados.reversed.toList(),
  };
  final vistos = <String>{};
  return [
    for (final o in lista)
      if (vistos.add(o.id)) o
  ];
}

List<LibraryItem> _intercalar(List<List<LibraryItem>> listas) {
  final salida = <LibraryItem>[];
  final maximo = listas.fold<int>(0, (m, l) => math.max(m, l.length));
  for (var i = 0; i < maximo; i++) {
    for (final l in listas) {
      if (i < l.length) salida.add(l[i]);
    }
  }
  return salida;
}

/// Avance de una obra a medias, si se conoce.
int? _porcentaje(LibraryItem o) {
  switch (o.type) {
    case LibraryItemType.book:
      return o.readingPercent;
    case LibraryItemType.movieSeries:
      final total = o.progressTotal ?? 0;
      return total > 0
          ? ((o.progressCurrent ?? 0) / total * 100).round().clamp(0, 100)
          : null;
    case LibraryItemType.game:
      return null;
  }
}

/// Peso de un mes para desempatar el «mes del año».
num _pesoMes(ResumenObras r, int mes) => switch (r) {
      ResumenLibros l => l.segundosPorMes[mes],
      ResumenJuegos j => j.logrosPorMes[mes],
      ResumenGeneral g =>
        g.libros.segundosPorMes[mes] / 60 + g.juegos.logrosPorMes[mes] * 10,
      _ => 0,
    };

String _detalleMes(ResumenObras r, int mes, int n) {
  final base = switch (r) {
    ResumenPantalla() => '$n ${n == 1 ? 'título visto' : 'títulos vistos'}',
    ResumenJuegos() =>
      '$n ${n == 1 ? 'juego completado' : 'juegos completados'}',
    ResumenGeneral() => '$n ${n == 1 ? 'obra terminada' : 'obras terminadas'}',
    _ => '$n ${n == 1 ? 'libro terminado' : 'libros terminados'}',
  };
  final extra = switch (r) {
    ResumenLibros l => l.segundosPorMes[mes] > 0
        ? ' y ${duracionLarga(l.segundosPorMes[mes])} en el Kindle'
        : '',
    ResumenJuegos j =>
      j.logrosPorMes[mes] > 0 ? ' y ${j.logrosPorMes[mes]} logros' : '',
    _ => '',
  };
  return '$base$extra.';
}

List<String> _chipsDestacado(ResumenObras r, LibraryItem o) {
  switch (r) {
    case ResumenLibros l:
      final segundos = l.segundosDe(o);
      final citas = l.citas.where((c) => c.libro.id == o.id).length;
      final paginas = l.paginasPorLibro[o];
      return [
        if (segundos > 0) duracionLarga(segundos),
        if (paginas != null) '${miles(paginas)} págs.',
        if (citas > 0) '$citas ${citas == 1 ? 'cita' : 'citas'}',
      ];
    case ResumenPantalla p:
      final m = p.minutos[o];
      return [
        if (o.mediaType == LibraryMediaType.series) 'Serie' else 'Película',
        if (m != null)
          '${m.estimado ? '≈ ' : ''}${duracionLarga(m.minutos * 60)}',
        if ((o.creatorOrDirector ?? '').isNotEmpty) o.creatorOrDirector!,
      ];
    case ResumenJuegos j:
      final logros = j.logrosDe(o);
      final minutos = j.minutosDe(o);
      return [
        if (logros > 0) '$logros logros este año',
        if ((minutos ?? 0) > 0) '${(minutos! / 60).round()} h en Steam',
        if ((o.developer ?? '').isNotEmpty) o.developer!.split(',').first,
      ];
    case ResumenGeneral g:
      return [
        switch (o.type) {
          LibraryItemType.book => 'Libro',
          LibraryItemType.movieSeries =>
            o.mediaType == LibraryMediaType.series ? 'Serie' : 'Película',
          LibraryItemType.game => 'Videojuego',
        },
        ..._chipsDestacado(
                switch (o.type) {
                  LibraryItemType.book => g.libros,
                  LibraryItemType.movieSeries => g.pantalla,
                  LibraryItemType.game => g.juegos,
                },
                o)
            .where((c) => c != 'Serie' && c != 'Película')
            .take(2),
      ];
  }
  return const [];
}

List<(String, String)> _datosResumen(ResumenObras r) {
  final comunes = <(String, String)>[
    if (r.notaMedia != null) ('${decimal(r.notaMedia!)} ★', 'nota media'),
    if (r.sagas.isNotEmpty)
      ('${r.sagas.length}', r.sagas.length == 1 ? 'saga' : 'sagas'),
    if (r.creadores.isNotEmpty) ('${r.creadores.length}', r.k.firmas),
  ];
  return switch (r) {
    ResumenLibros l => [
        if (l.terminados.isNotEmpty) ('${l.terminados.length}', 'libros'),
        if (l.paginas > 0) (miles(l.paginas), 'páginas'),
        if (l.hayKindle) ('${(l.segundos / 3600).round()} h', 'en el Kindle'),
        if (l.rachaMaxima > 1) ('${l.rachaMaxima}', 'días de racha'),
        if (l.notaMedia != null) ('${decimal(l.notaMedia!)} ★', 'nota media'),
        if (l.citas.isNotEmpty)
          ('${l.citas.length}', l.citas.length == 1 ? 'cita' : 'citas'),
        ...comunes.skip(1),
      ],
    ResumenPantalla p => [
        if (p.peliculas.isNotEmpty) ('${p.peliculas.length}', 'películas'),
        if (p.series.isNotEmpty) ('${p.series.length}', 'series'),
        if (p.minutosTotales > 0)
          (
            '${p.hayEstimaciones ? '≈' : ''}${(p.minutosTotales / 60).round()} h',
            'frente a la pantalla'
          ),
        if (p.episodios > 0) ('${p.episodios}', 'episodios'),
        if (p.paises.isNotEmpty)
          ('${p.paises.length}', p.paises.length == 1 ? 'país' : 'países'),
        ...comunes,
      ],
    ResumenJuegos j => [
        if (j.terminados.isNotEmpty) ('${j.terminados.length}', 'completados'),
        if (j.hayLogros) (miles(j.logrosDelAno.length), 'logros'),
        if (j.completados.isNotEmpty)
          (
            '${j.completados.length}',
            j.completados.length == 1 ? 'al 100 %' : 'al 100 %'
          ),
        if (j.rachaLogros > 1) ('${j.rachaLogros}', 'días de racha'),
        if (j.porHoras.isNotEmpty)
          ('${(j.minutosJugados / 60).round()} h', 'en Steam'),
        ...comunes,
      ],
    ResumenGeneral g => [
        ('${g.terminados.length}', 'obras'),
        if (g.cuantos(LibraryItemType.book) > 0)
          ('${g.cuantos(LibraryItemType.book)}', 'libros'),
        if (g.cuantos(LibraryItemType.movieSeries) > 0)
          ('${g.cuantos(LibraryItemType.movieSeries)}', 'series y pelis'),
        if (g.cuantos(LibraryItemType.game) > 0)
          ('${g.cuantos(LibraryItemType.game)}', 'juegos'),
        if (g.minutosHistorias > 0)
          ('${(g.minutosHistorias / 60).round()} h', 'de historias'),
        if (g.juegos.hayLogros) (miles(g.juegos.logrosDelAno.length), 'logros'),
        ...comunes,
      ],
    _ => comunes,
  };
}

/// Datos curiosos de cada tipo: valor grande, explicación e icono.
List<(String, String, IconData)> _curiosidades(ResumenObras r) {
  final anadidos = r.diaMasAnadidos != null && r.anadidosDiaRecord >= 3
      ? (
          '${r.anadidosDiaRecord} ${r.k.varios}',
          'añadiste de golpe el ${fechaLarga(r.diaMasAnadidos!)}.',
          Icons.library_add_rounded
        )
      : null;
  final maraton = r.terminadosDiaRecord.length >= 2
      ? (
          '${r.terminadosDiaRecord.length} en un día',
          'el ${fechaLarga(r.diaMasTerminados!)} terminaste ${r.terminadosDiaRecord.map((o) => '«${o.title}»').take(3).join(', ')}.',
          Icons.local_fire_department_rounded
        )
      : null;
  switch (r) {
    case ResumenLibros l:
      return [
        if (l.fisicos > 0 && l.digitales > 0)
          (
            '${l.fisicos} · ${l.digitales}',
            'en papel y en pantalla. ${l.fisicos >= l.digitales ? 'El papel sigue ganando' : 'La pantalla se impone'}.',
            Icons.layers_rounded
          ),
        if (l.libroMasRapido != null && l.diasLibroMasRapido <= 21)
          (
            '${l.diasLibroMasRapido} ${l.diasLibroMasRapido == 1 ? 'día' : 'días'}',
            'tardaste en devorar «${l.libroMasRapido!.title}».',
            Icons.bolt_rounded
          ),
        if (anadidos != null) anadidos,
        if (l.citas.isNotEmpty)
          (
            '${l.citas.length}',
            l.citas.length == 1
                ? 'cita subrayada en el Kindle.'
                : 'citas subrayadas en el Kindle.',
            Icons.format_quote_rounded
          ),
        if (l.enCurso.isNotEmpty && l.terminados.length < 3)
          (
            '${l.enCurso.length}',
            l.enCurso.length == 1
                ? 'libro a medias ahora mismo.'
                : 'libros a medias ahora mismo.',
            Icons.bookmark_rounded
          ),
      ];
    case ResumenPantalla p:
      return [
        if (maraton != null) maraton,
        if (p.estrenos.isNotEmpty)
          (
            '${p.estrenos.length} ${p.estrenos.length == 1 ? 'estreno' : 'estrenos'}',
            'de ${p.year}: viste lo más nuevo casi recién salido.',
            Icons.new_releases_rounded
          ),
        if (p.enCine.isNotEmpty)
          (
            '${p.enCine.length} en el cine',
            p.enCine.length == 1
                ? '«${p.enCine.first.title}», en pantalla grande.'
                : 'con butaca y palomitas.',
            Icons.theaters_rounded
          ),
        if (p.repetidas.isNotEmpty)
          (
            '${p.repetidas.length} ${p.repetidas.length == 1 ? 'repetida' : 'repetidas'}',
            'porque «${p.repetidas.first.title}» merecía otra vuelta.',
            Icons.replay_rounded
          ),
        if (anadidos != null) anadidos,
      ];
    case ResumenJuegos j:
      return [
        if (j.diaRecordLogros != null && j.logrosDiaRecord >= 3)
          (
            '${j.logrosDiaRecord} logros',
            'en un solo día, el ${fechaLarga(j.diaRecordLogros!)}, con «${j.juegoDiaRecord!.title}».',
            Icons.emoji_events_rounded
          ),
        if (maraton != null) maraton,
        if (j.completados.isNotEmpty)
          (
            '${j.completados.length} al 100 %',
            j.completados.length == 1
                ? '«${j.completados.first.juego.title}», con todos sus logros.'
                : 'juegos con todos sus logros.',
            Icons.workspace_premium_rounded
          ),
        if (anadidos != null) anadidos,
      ];
    case ResumenGeneral g:
      return [
        if (maraton != null) maraton,
        if (anadidos != null) anadidos,
        (
          '${g.diasConFinal} días',
          'del año en los que terminaste algo.',
          Icons.event_available_rounded
        ),
        if (g.universos.isNotEmpty)
          (
            g.universos.first.nombre,
            'te acompañó en ${g.universos.first.tipos.length} formatos distintos.',
            Icons.public_rounded
          ),
      ];
  }
  return const [];
}

/// Perfil de cada tipo: un nombre con gancho y unos rasgos.
({String nombre, List<String> rasgos}) _perfil(ResumenObras r) {
  final genero = r.generos.isEmpty ? '' : r.generos.first.key.toLowerCase();
  bool hay(String patron) => RegExp(patron).hasMatch(genero);
  final nombre = switch (r) {
    ResumenPantalla() when hay(r'terror|suspense|thriller') =>
      'Butaca del miedo',
    ResumenPantalla() when hay(r'anim|anime') => 'Alma de anime',
    ResumenPantalla() when hay(r'acci|aventur') => 'Adrenalina en vena',
    ResumenPantalla() when hay(r'drama') => 'Corazón de drama',
    ResumenPantalla() when hay(r'comedia|humor') => 'Risa fácil',
    ResumenPantalla() => 'Mirada de cine',
    ResumenJuegos() when hay(r'rogue') => 'Una partida más',
    ResumenJuegos() when hay(r'terror') => 'Nervios de acero',
    ResumenJuegos() when hay(r'rpg|rol') => 'Alma de aventura',
    ResumenJuegos() when hay(r'estrateg|defensa|tactic') => 'Mente estratega',
    ResumenJuegos() when hay(r'idle|incremental|casual') =>
      'Paciencia infinita',
    ResumenJuegos() => 'Mando en mano',
    ResumenGeneral() => 'Devorar historias',
    _ when hay(r'misterio|polic|detect|negra|crimen') => 'Detective de sillón',
    _ when hay(r'litrpg|fantas|epica|épica|aventur') => 'Alma aventurera',
    _ when hay(r'ciencia|sci|espacial') => 'Mente galáctica',
    _ when hay(r'terror|gótic|gotic|oscur') => 'Amante del escalofrío',
    _ when hay(r'romance|romántic|romantic') => 'Corazón romántico',
    _ when hay(r'clásic|clasic|ruso') => 'Alma clásica',
    _ when hay(r'ensayo|autoayuda|divulg') => 'Mente curiosa',
    _ => 'Lectura sin fondo',
  };
  final rasgos = <String>[
    if (r.sagas.isNotEmpty && r.sagas.first.leidos.length >= 2)
      'Te enganchan las sagas: ${r.sagas.first.leidos.length} de ${r.sagas.first.nombre}',
    if (r.creadores.isNotEmpty && r.creadores.first.obras.length >= 3)
      'Fidelidad absoluta a ${r.creadores.first.nombre}',
    ...switch (r) {
      ResumenLibros l => [
          if (l.hayKindle)
            '${_momento(l.segundosPorHora).nombre}: ${_momento(l.segundosPorHora).detalle.toLowerCase()}',
          if (l.rachaMaxima >= 5)
            'Constancia de hierro: ${l.rachaMaxima} días seguidos',
        ],
      ResumenPantalla p => [
          if (p.paises.length >= 3)
            'Vuelta al mundo: ${p.paises.length} países',
          if (p.series.isNotEmpty && p.peliculas.isNotEmpty)
            '${p.peliculas.length} películas y ${p.series.length} series',
        ],
      ResumenJuegos j => [
          if (j.hayLogros)
            '${_momento(j.logrosPorHora).nombre}: ${_momento(j.logrosPorHora).detalle.toLowerCase()}',
          if (j.logroMasRaro != null &&
              (j.logroMasRaro!.porcentajeGlobal ?? 100) < 10)
            'Cazador de rarezas: un logro del ${decimal(j.logroMasRaro!.porcentajeGlobal!)} %',
        ],
      ResumenGeneral g => [
          'Libros, pantalla y mando: ${g.cuantos(LibraryItemType.book)} · ${g.cuantos(LibraryItemType.movieSeries)} · ${g.cuantos(LibraryItemType.game)}',
          if (g.universos.isNotEmpty)
            '${g.universos.first.nombre} en todos los formatos',
        ],
      _ => <String>[],
    },
    if ((r.anoMasReciente ?? 0) - (r.anoMasAntiguo ?? 0) >= 60)
      'Sin miedo a lo clásico: de ${r.anoMasAntiguo} a ${r.anoMasReciente}',
    if (r.generos.length >= 6)
      'Todoterreno: ${r.generos.length} géneros distintos',
  ];
  return (nombre: nombre, rasgos: rasgos.take(4).toList());
}

/// Momento del día preferido según un reparto por horas.
({String nombre, String detalle, IconData icono}) _momento(List<int> horas) {
  int suma(Iterable<int> h) => h.fold(0, (s, x) => s + horas[x]);
  final tramos = [
    (
      suma([5, 6, 7, 8, 9, 10, 11]),
      'Alondra madrugadora',
      'Lo tuyo son las mañanas',
      Icons.wb_twilight_rounded
    ),
    (
      suma([12, 13, 14, 15, 16, 17]),
      'Tarde de sobremesa',
      'Te rinden las tardes',
      Icons.wb_sunny_rounded
    ),
    (
      suma([18, 19, 20, 21, 22]),
      'Hora dorada',
      'Te pones cuando cae el sol',
      Icons.nights_stay_rounded
    ),
    (
      suma([23, 0, 1, 2, 3, 4]),
      'Búho nocturno',
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

// ============================================================ construcción

/// Ayuda común para montar la lista de diapositivas con sus paletas.
class _Lista {
  _Lista(this.r, this.nombres) {
    final nombre = r.ajustes.paleta?.toLowerCase().trim();
    _fija = Paleta.porNombre[nombre];
    _ciclo = _fija == null ? 0 : Paleta.ciclo.indexOf(_fija!).clamp(0, 99);
    _porPortadas = _fija == null && nombre != 'ciclo';
  }

  final ResumenObras r;
  final Map<String, String> nombres;
  final lista = <DiapositivaWrapped>[];
  Paleta? _fija;
  late int _ciclo;
  late bool _porPortadas;

  Paleta paleta([LibraryItem? destacado, String? fuente]) {
    if (_porPortadas) {
      final color = ColoresPortada.deCache(destacado?.coverUrl ?? fuente);
      if (color != null) {
        _ciclo++;
        return Paleta.desde(color);
      }
    }
    return Paleta.ciclo[_ciclo++ % Paleta.ciclo.length];
  }

  void anadir(String id, Paleta p, Widget Function(BuildContext, double) f,
      {double duracion = 1}) {
    if (r.ajustes.ocultar.contains(id)) return;
    lista.add(DiapositivaWrapped(
        id: id,
        nombre: nombres[id] ?? id,
        paleta: p,
        construir: f,
        duracion: duracion));
  }

  /// Diapositivas comunes con datos suficientes. [como] guarda el
  /// identificador antiguo de una diapositiva (p. ej. «autor» en libros).
  void comunes(String id, [String? como]) {
    if (como != null) {
      final antes = lista.length;
      comunes(id);
      if (lista.length > antes) {
        final d = lista.removeLast();
        if (r.ajustes.ocultar.contains(como)) return;
        lista.add(DiapositivaWrapped(
            id: como,
            nombre: nombres[como] ?? d.nombre,
            paleta: d.paleta,
            construir: d.construir,
            duracion: d.duracion));
      }
      return;
    }
    switch (id) {
      case 'inicio':
        anadir('inicio', paleta(r.portada), (c, t) => _Inicio(r: r, t: t),
            duracion: .9);
      case 'terminados':
        if (r.terminados.isNotEmpty) {
          anadir('terminados', paleta(r.terminados.last),
              (c, t) => _Terminados(r: r, t: t));
        }
      case 'meses':
        // Al menos cuatro obras repartidas en dos meses o más.
        if (r.terminados.length >= 4 &&
            r.terminadosPorMes.where((n) => n > 0).length >= 2) {
          anadir('meses', paleta(), (c, t) => _Meses(r: r, t: t),
              duracion: 1.1);
        }
      case 'creador':
        if (r.creadores.isNotEmpty && r.creadores.first.obras.length >= 2) {
          anadir('creador', paleta(r.creadores.first.obras.last),
              (c, t) => _Autor(r: r, t: t));
        }
      case 'sagas':
        // Solo si de una misma saga se terminaron dos entregas o más.
        if (r.sagas.isNotEmpty && r.sagas.first.leidos.length >= 2) {
          anadir('sagas', paleta(r.sagas.first.leidos.last),
              (c, t) => _Sagas(r: r, t: t),
              duracion: 1.15);
        }
      case 'generos':
        if (r.generos.length >= 3 && r.generos.first.value >= 2) {
          anadir('generos', paleta(), (c, t) => _Generos(r: r, t: t));
        }
      case 'epocas':
        if (r.anoMasAntiguo != null &&
            r.anoMasReciente != null &&
            r.anoMasReciente! - r.anoMasAntiguo! >= 10 &&
            r.terminados.where((o) => (o.releaseYear ?? 0) > 0).length >= 3) {
          anadir('epocas', paleta(r.obraMasAntigua),
              (c, t) => _Epocas(r: r, t: t));
        }
      case 'curiosidades':
        if (_curiosidades(r).length >= 2) {
          anadir('curiosidades', paleta(), (c, t) => _Curiosidades(r: r, t: t),
              duracion: 1.1);
        }
      case 'notas':
        if (r.valorados.length >= 3) {
          anadir('notas', Paleta.oro, (c, t) => _Notas(r: r, t: t));
        }
      case 'propositos':
        if (r.propositos >= 2) {
          anadir('propositos', paleta(), (c, t) => _Propositos(r: r, t: t));
        }
      case 'destacado':
        // Elegir «lo mejor del año» solo tiene sentido entre varias obras.
        if (r.destacado != null &&
            (r.terminados.length >= 2 || r.destacado!.rating != null)) {
          anadir('destacado', paleta(r.destacado),
              (c, t) => _LibroDelAno(r: r, t: t),
              duracion: 1.15);
        }
      case 'perfil':
        if (_perfil(r).rasgos.length >= 2) {
          anadir('perfil', paleta(), (c, t) => _Perfil(r: r, t: t));
        }
      case 'lo-que-viene':
        if (_hayFuturo(r)) {
          anadir(
              'lo-que-viene', Paleta.aurora, (c, t) => _LoQueViene(r: r, t: t),
              duracion: 1.1);
        }
      case 'resumen':
        anadir('resumen', paleta(r.portada), (c, t) => _Resumen(r: r, t: t),
            duracion: 1.4);
    }
  }
}

/// Obras con algo que enseñar en el año (para elegir portada o destacado).
List<LibraryItem> obrasDestacables(ResumenObras r) => _destacables(r);
