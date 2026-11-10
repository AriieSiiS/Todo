import 'dart:math' as math;

import '../../domain/models.dart';
import 'wrapped_modelo.dart';

/// Libro con el tiempo y las páginas que registró el Kindle en el año.
class LibroConLectura {
  const LibroConLectura(this.libro, this.segundos, this.paginas, this.dias);
  final LibraryItem libro;
  final int segundos;
  final int paginas;
  final int dias;
}

/// Autor con los libros que se terminaron suyos en el año.
class AutorDelAno {
  const AutorDelAno(this.nombre, this.libros, {required this.nuevo});
  final String nombre;
  final List<LibraryItem> libros;

  /// No se había terminado ningún libro suyo en años anteriores.
  final bool nuevo;
}

/// Siguiente entrega de una saga, sacada de la Biblioteca o del catálogo.
class SiguienteEntrega {
  const SiguienteEntrega({
    required this.titulo,
    required this.numero,
    this.portada,
    this.libro,
    this.fechaPrevista,
    this.anoSalida,
  });
  final String titulo;
  final int numero;
  final String? portada;

  /// Ficha de Biblioteca si ya está añadida (pendiente o en curso).
  final LibraryItem? libro;

  /// Texto de la fecha prevista del catálogo, como «28 de enero de 2027».
  final String? fechaPrevista;
  final int? anoSalida;
}

class SagaDelAno {
  const SagaDelAno(
      {required this.nombre,
      required this.leidos,
      this.enCurso,
      this.siguiente});
  final String nombre;

  /// Entregas terminadas en el año, en orden de saga.
  final List<LibraryItem> leidos;
  final LibraryItem? enCurso;
  final SiguienteEntrega? siguiente;
}

class CitaDelAno {
  const CitaDelAno(this.libro, this.texto, this.nota);
  final LibraryItem libro;
  final String texto;
  final String? nota;
}

/// Todos los datos del Wrapped de libros de un año.
///
/// Se calcula a partir de la Biblioteca en el momento de abrirlo, así que un
/// libro terminado el 31 de diciembre cuenta aunque el aviso saliera antes.
class ResumenLibros {
  ResumenLibros._(this.year, this.ajustes);

  final int year;
  final AjustesWrappedTipo ajustes;

  /// Terminados en el año, del primero al último.
  final List<LibraryItem> terminados = [];
  int terminadosAnterior = 0;

  // Kindle ------------------------------------------------------------------
  int segundos = 0;
  int segundosAnterior = 0;
  int paginasKindle = 0;
  final Map<DateTime, int> segundosPorDia = {};
  final List<int> segundosPorMes = List.filled(12, 0);
  final List<int> segundosPorHora = List.filled(24, 0);
  final List<int> segundosPorDiaSemana = List.filled(7, 0);
  final List<LibroConLectura> porTiempo = [];
  int rachaMaxima = 0;
  DateTime? inicioRacha;
  DateTime? finRacha;
  DateTime? diaRecord;
  int segundosDiaRecord = 0;
  LibraryItem? libroDiaRecord;

  /// Libro terminado en menos días desde que se empezó en el Kindle.
  LibraryItem? libroMasRapido;
  int diasLibroMasRapido = 0;

  // Páginas -----------------------------------------------------------------
  final Map<LibraryItem, int> paginasPorLibro = {};
  int paginas = 0;
  int paginasAnterior = 0;

  // Notas y destacados ------------------------------------------------------
  double? notaMedia;
  LibraryItem? libroDelAno;
  LibraryItem? portada;
  LibraryItem? peorValorado;
  final List<int> notasPorEstrella = List.filled(5, 0);

  // Autores, géneros y sagas -----------------------------------------------
  final List<AutorDelAno> autores = [];
  final List<MapEntry<String, int>> generos = [];
  final List<SagaDelAno> sagas = [];

  // Tiempo, formatos y ritmo ------------------------------------------------
  int? anoMasAntiguo;
  int? anoMasReciente;
  LibraryItem? libroMasAntiguo;
  LibraryItem? libroMasReciente;
  int fisicos = 0;
  int digitales = 0;
  final List<int> terminadosPorMes = List.filled(12, 0);
  DateTime? diaMasAnadidos;
  int librosDiaMasAnadidos = 0;

  // Citas, propósitos y lo que viene ----------------------------------------
  final List<CitaDelAno> citas = [];
  CitaDelAno? citaDestacada;
  int propositos = 0;
  int propositosCumplidos = 0;
  final List<({String titulo, String? portada, bool cumplido})>
      listaPropositos = [];
  final List<LibraryItem> enCurso = [];
  int pendientes = 0;

  bool get hayKindle => segundos > 0;
  bool get hayDatos => terminados.isNotEmpty || hayKindle;

  /// Días con lectura en el Kindle.
  int get diasConLectura => segundosPorDia.length;

  /// Páginas por hora en el Kindle, si hay datos suficientes.
  int? get paginasPorHora => paginasKindle > 20 && segundos > 1800
      ? (paginasKindle / segundos * 3600).round()
      : null;

  static ResumenLibros calcular({
    required List<LibraryItem> biblioteca,
    required int year,
    List<LibraryGoal> propositos = const [],
    List<Coleccion> colecciones = const [],
    AjustesWrappedTipo ajustes = const AjustesWrappedTipo(),
  }) {
    final r = ResumenLibros._(year, ajustes);
    final excluidos = ajustes.excluir.map(normalizarTituloWrapped).toSet();
    bool excluido(LibraryItem l) =>
        ajustes.excluir.contains(l.id) ||
        excluidos.contains(normalizarTituloWrapped(l.title));
    final libros = biblioteca
        .where((l) => l.type == LibraryItemType.book && !excluido(l))
        .toList();
    bool terminadoEn(LibraryItem l, int a) =>
        l.status == LibraryItemStatus.completed && l.completedDate?.year == a;

    r.terminados
      ..addAll(libros.where((l) => terminadoEn(l, year)))
      ..sort((a, b) => a.completedDate!.compareTo(b.completedDate!));
    r.terminadosAnterior = libros.where((l) => terminadoEn(l, year - 1)).length;

    r._calcularKindle(libros);
    r._calcularPaginas(libros.where((l) => terminadoEn(l, year - 1)));
    r._calcularNotas(libros);
    r._calcularAutoresYGeneros(libros);
    r._calcularSagas(libros, colecciones);
    r._calcularEpocasYFormatos(libros);
    r._calcularCitas(libros);
    r._calcularPropositos(propositos, biblioteca);
    r.enCurso
        .addAll(libros.where((l) => l.status == LibraryItemStatus.inProgress));
    r.pendientes =
        libros.where((l) => l.status == LibraryItemStatus.pending).length;
    return r;
  }

  /// Busca un libro por id o por título normalizado.
  static LibraryItem? buscar(Iterable<LibraryItem> libros, String? clave) {
    if (clave == null || clave.trim().isEmpty) return null;
    for (final libro in libros) {
      if (libro.id == clave) return libro;
    }
    final buscado = normalizarTituloWrapped(clave);
    for (final libro in libros) {
      if (normalizarTituloWrapped(libro.title) == buscado) return libro;
    }
    for (final libro in libros) {
      if (normalizarTituloWrapped(libro.title).contains(buscado)) return libro;
    }
    return null;
  }

  void _calcularKindle(List<LibraryItem> libros) {
    // Una misma fuente del Kindle puede estar en dos fichas (al unirlas): se
    // cuenta una sola vez, con la versión más reciente.
    final fuentes = <String, BookReadingStatistics>{};
    final duenoDe = <String, LibraryItem>{};
    for (final libro in libros) {
      for (final e in libro.reading?.statistics.entries ??
          const <MapEntry<String, BookReadingStatistics>>[]) {
        if (e.value.observedAt >= (fuentes[e.key]?.observedAt ?? -1)) {
          fuentes[e.key] = e.value;
          duenoDe[e.key] = libro;
        }
      }
    }
    final porLibro = <LibraryItem, ({int s, int p, Set<DateTime> d})>{};
    final porDiaYLibro = <DateTime, Map<LibraryItem, int>>{};
    final primerDia = <LibraryItem, DateTime>{};
    for (final e in fuentes.entries) {
      final libro = duenoDe[e.key]!;
      final paginable =
          e.value.pageUnit == 'page' || e.value.pageUnit == 'estimated_page';
      for (final p in e.value.periods) {
        if (p.seconds <= 0) continue;
        final fecha = p.localDate;
        final dia = DateTime(fecha.year, fecha.month, fecha.day);
        final previo = primerDia[libro];
        if (previo == null || dia.isBefore(previo)) primerDia[libro] = dia;
        if (fecha.year == year - 1) segundosAnterior += p.seconds;
        if (fecha.year != year) continue;
        segundos += p.seconds;
        if (paginable) paginasKindle += p.pages;
        segundosPorDia.update(dia, (v) => v + p.seconds,
            ifAbsent: () => p.seconds);
        segundosPorMes[fecha.month - 1] += p.seconds;
        segundosPorHora[fecha.hour] += p.seconds;
        segundosPorDiaSemana[fecha.weekday - 1] += p.seconds;
        final actual = porLibro[libro] ?? (s: 0, p: 0, d: <DateTime>{});
        porLibro[libro] = (
          s: actual.s + p.seconds,
          p: actual.p + (paginable ? p.pages : 0),
          d: actual.d..add(dia)
        );
        porDiaYLibro
            .putIfAbsent(dia, () => {})
            .update(libro, (v) => v + p.seconds, ifAbsent: () => p.seconds);
      }
    }
    porTiempo
      ..addAll([
        for (final e in porLibro.entries)
          LibroConLectura(e.key, e.value.s, e.value.p, e.value.d.length)
      ])
      ..sort((a, b) => b.segundos.compareTo(a.segundos));

    // Racha más larga, con sus fechas.
    final dias = segundosPorDia.keys.toList()..sort();
    var actual = 0;
    DateTime? inicio, previo;
    for (final dia in dias) {
      final seguido = previo != null &&
          DateTime(previo.year, previo.month, previo.day + 1) == dia;
      if (seguido) {
        actual++;
      } else {
        actual = 1;
        inicio = dia;
      }
      if (actual > rachaMaxima) {
        rachaMaxima = actual;
        inicioRacha = inicio;
        finRacha = dia;
      }
      previo = dia;
    }

    for (final e in segundosPorDia.entries) {
      if (e.value > segundosDiaRecord) {
        segundosDiaRecord = e.value;
        diaRecord = e.key;
      }
    }
    if (diaRecord != null) {
      final delDia = porDiaYLibro[diaRecord]!.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      libroDiaRecord = delDia.first.key;
    }

    for (final libro in terminados) {
      final empezado = primerDia[libro];
      final fin = libro.completedDate;
      if (empezado == null || fin == null) continue;
      final diasLibro =
          DateTime(fin.year, fin.month, fin.day).difference(empezado).inDays +
              1;
      if (diasLibro <= 0) continue;
      if (libroMasRapido == null || diasLibro < diasLibroMasRapido) {
        libroMasRapido = libro;
        diasLibroMasRapido = diasLibro;
      }
    }
  }

  void _calcularPaginas(Iterable<LibraryItem> anteriores) {
    for (final libro in terminados) {
      final total = bookPageTotal(libro.pages, libro.reading);
      if (total == null || total <= 0) continue;
      paginasPorLibro[libro] = total;
      paginas += total;
    }
    for (final libro in anteriores) {
      paginasAnterior += bookPageTotal(libro.pages, libro.reading) ?? 0;
    }
  }

  int segundosDe(LibraryItem libro) {
    for (final e in porTiempo) {
      if (e.libro.id == libro.id) return e.segundos;
    }
    return 0;
  }

  void _calcularNotas(List<LibraryItem> libros) {
    final valorados = terminados.where((l) => l.rating != null).toList();
    if (valorados.isNotEmpty) {
      notaMedia =
          valorados.fold<double>(0, (s, l) => s + l.rating!) / valorados.length;
      for (final l in valorados) {
        final estrellas = l.rating!.round().clamp(1, 5);
        notasPorEstrella[estrellas - 1]++;
      }
    }
    int comparar(LibraryItem a, LibraryItem b) {
      final nota = (b.rating ?? -1).compareTo(a.rating ?? -1);
      if (nota != 0) return nota;
      final tiempo = segundosDe(b).compareTo(segundosDe(a));
      if (tiempo != 0) return tiempo;
      return (paginasPorLibro[b] ?? 0).compareTo(paginasPorLibro[a] ?? 0);
    }

    final candidatos = [...terminados];
    libroDelAno = buscar(libros, ajustes.destacado) ??
        (valorados.isNotEmpty
            ? ([...valorados]..sort(comparar)).first
            : (porTiempo.isNotEmpty
                ? porTiempo.first.libro
                : (candidatos.isEmpty ? null : candidatos.last)));
    portada = buscar(libros, ajustes.portada) ??
        libroDelAno ??
        (terminados.isEmpty ? null : terminados.last);
    if (valorados.length >= 3) {
      final orden = [...valorados]..sort(comparar);
      final peor = orden.last;
      if (peor.rating! < (notaMedia ?? 0) - 0.4 && peor.id != libroDelAno?.id) {
        peorValorado = peor;
      }
    }
  }

  void _calcularAutoresYGeneros(List<LibraryItem> libros) {
    final previos = <String>{
      for (final l in libros)
        if (l.status == LibraryItemStatus.completed &&
            l.completedDate != null &&
            l.completedDate!.year < year &&
            (l.author ?? '').trim().isNotEmpty)
          normalizarTituloWrapped(l.author!),
    };
    final porAutor = <String, List<LibraryItem>>{};
    final nombreDe = <String, String>{};
    for (final l in terminados) {
      final autor = (l.author ?? '').trim();
      if (autor.isEmpty) continue;
      final clave = normalizarTituloWrapped(autor);
      nombreDe.putIfAbsent(clave, () => autor);
      porAutor.putIfAbsent(clave, () => []).add(l);
    }
    autores
      ..addAll([
        for (final e in porAutor.entries)
          AutorDelAno(nombreDe[e.key]!, e.value,
              nuevo: !previos.contains(e.key))
      ])
      ..sort((a, b) {
        final c = b.libros.length.compareTo(a.libros.length);
        if (c != 0) return c;
        final s = b.libros
            .fold<int>(0, (t, l) => t + segundosDe(l))
            .compareTo(a.libros.fold<int>(0, (t, l) => t + segundosDe(l)));
        return s != 0 ? s : a.nombre.compareTo(b.nombre);
      });

    final cuenta = <String, int>{};
    final etiqueta = <String, String>{};
    // En los empates gana el género que suele ir primero en las fichas y,
    // después, el de los libros con más horas de lectura.
    final peso = <String, int>{};
    for (final l in terminados) {
      final vistos = <String>{};
      var posicion = 0;
      for (final parte in (l.genre ?? '').split(RegExp(r'[,/;·]| y '))) {
        final limpio = parte.trim();
        if (limpio.length < 3) continue;
        final clave = normalizarTituloWrapped(limpio);
        if (!vistos.add(clave)) continue;
        etiqueta.putIfAbsent(
            clave, () => limpio[0].toUpperCase() + limpio.substring(1));
        cuenta.update(clave, (v) => v + 1, ifAbsent: () => 1);
        final extra = math.max(0, 3 - posicion) * 1000000 + segundosDe(l) ~/ 60;
        peso.update(clave, (v) => v + extra, ifAbsent: () => extra);
        posicion++;
      }
    }
    final orden = cuenta.keys.toList()
      ..sort((a, b) {
        final c = cuenta[b]!.compareTo(cuenta[a]!);
        if (c != 0) return c;
        final p = peso[b]!.compareTo(peso[a]!);
        return p != 0 ? p : a.compareTo(b);
      });
    generos.addAll(orden.map((k) => MapEntry(etiqueta[k]!, cuenta[k]!)));
  }

  void _calcularSagas(List<LibraryItem> libros, List<Coleccion> colecciones) {
    final porSaga = <String, List<LibraryItem>>{};
    final nombreDe = <String, String>{};
    for (final l in terminados) {
      final saga = (l.collectionName ?? '').trim();
      if (saga.isEmpty) continue;
      final clave = normalizarTituloWrapped(saga);
      nombreDe.putIfAbsent(clave, () => saga);
      porSaga.putIfAbsent(clave, () => []).add(l);
    }
    for (final e in porSaga.entries) {
      final nombre = nombreDe[e.key]!;
      final leidos = [...e.value]..sort((a, b) =>
          (a.collectionNumber ?? 999).compareTo(b.collectionNumber ?? 999));
      final deLaSaga = libros
          .where(
              (l) => normalizarTituloWrapped(l.collectionName ?? '') == e.key)
          .toList();
      final enCurso = deLaSaga
          .where((l) => l.status == LibraryItemStatus.inProgress)
          .toList()
        ..sort((a, b) =>
            (a.collectionNumber ?? 0).compareTo(b.collectionNumber ?? 0));
      var ultimo = 0;
      for (final l in deLaSaga) {
        if (l.status == LibraryItemStatus.pending) continue;
        ultimo = math.max(ultimo, l.collectionNumber ?? 0);
      }
      SiguienteEntrega? siguiente;
      if (ultimo > 0) {
        siguiente = _siguiente(e.key, ultimo + 1, deLaSaga, colecciones);
      }
      sagas.add(SagaDelAno(
          nombre: nombre,
          leidos: leidos,
          enCurso: enCurso.isEmpty ? null : enCurso.last,
          siguiente: siguiente));
    }
    sagas.sort((a, b) {
      final c = b.leidos.length.compareTo(a.leidos.length);
      return c != 0 ? c : a.nombre.compareTo(b.nombre);
    });
  }

  SiguienteEntrega? _siguiente(String saga, int numero,
      List<LibraryItem> deLaSaga, List<Coleccion> colecciones) {
    LibraryItem? enBiblioteca;
    for (final l in deLaSaga) {
      if (l.collectionNumber == numero) enBiblioteca = l;
    }
    for (final coleccion in colecciones) {
      for (final obra in coleccion.obras) {
        if (obra.collectionNumber != numero ||
            normalizarTituloWrapped(obra.collectionName ?? '') != saga) {
          continue;
        }
        final id = obra.catalogKeys.isEmpty
            ? ''
            : obra.catalogKeys.single.split('/').last;
        final fecha = coleccion.fechasPrevistas[id]?.trim();
        enBiblioteca ??= deLaSaga
            .where((l) => l.catalogKeys.any(obra.catalogKeys.contains))
            .firstOrNull;
        return SiguienteEntrega(
          titulo: enBiblioteca?.title ?? obra.title,
          numero: numero,
          portada: enBiblioteca?.coverUrl ?? obra.coverUrl,
          libro: enBiblioteca,
          fechaPrevista: fecha == null || fecha.isEmpty ? null : fecha,
          anoSalida: obra.releaseYear,
        );
      }
    }
    if (enBiblioteca == null) return null;
    return SiguienteEntrega(
        titulo: enBiblioteca.title,
        numero: numero,
        portada: enBiblioteca.coverUrl,
        libro: enBiblioteca,
        anoSalida: enBiblioteca.releaseYear);
  }

  void _calcularEpocasYFormatos(List<LibraryItem> libros) {
    for (final l in terminados) {
      final ano = l.releaseYear;
      if (ano != null && ano > 0) {
        if (anoMasAntiguo == null || ano < anoMasAntiguo!) {
          anoMasAntiguo = ano;
          libroMasAntiguo = l;
        }
        if (anoMasReciente == null || ano >= anoMasReciente!) {
          anoMasReciente = ano;
          libroMasReciente = l;
        }
      }
      final formato = normalizarTituloWrapped(l.format ?? '');
      if (formato.contains('fisic') || formato.contains('papel')) {
        fisicos++;
      } else if (formato.contains('ebook') ||
          formato.contains('electr') ||
          formato.contains('kindle') ||
          formato.contains('digital')) {
        digitales++;
      }
      terminadosPorMes[l.completedDate!.month - 1]++;
    }
    final anadidos = <DateTime, int>{};
    for (final l in libros) {
      final c = l.createdAt.toLocal();
      if (c.year != year) continue;
      anadidos.update(DateTime(c.year, c.month, c.day), (v) => v + 1,
          ifAbsent: () => 1);
    }
    for (final e in anadidos.entries) {
      if (e.value > librosDiaMasAnadidos) {
        librosDiaMasAnadidos = e.value;
        diaMasAnadidos = e.key;
      }
    }
  }

  void _calcularCitas(List<LibraryItem> libros) {
    for (final libro in libros) {
      for (final cita in libro.reading?.quotes ?? const []) {
        final texto = (cita['text'] as String? ?? '').trim();
        if (texto.isEmpty) continue;
        var instante = (cita['observed_at'] as num?)?.toInt() ?? 0;
        if (instante > 100000000000) instante ~/= 1000;
        final fecha = DateTime.fromMillisecondsSinceEpoch(instante * 1000);
        if (fecha.year != year) continue;
        final nota = (cita['note'] as String?)?.trim();
        citas.add(CitaDelAno(
            libro, texto, nota == null || nota.isEmpty ? null : nota));
      }
    }
    if (citas.isEmpty) return;
    final buscada =
        ajustes.cita == null ? null : normalizarTituloWrapped(ajustes.cita!);
    if (buscada != null) {
      citaDestacada = citas
          .where((c) => normalizarTituloWrapped(c.texto).contains(buscada))
          .firstOrNull;
    }
    if (citaDestacada != null) return;
    // Una cita de largo cómodo, preferiblemente del libro del año.
    int puntos(CitaDelAno c) {
      final largo = c.texto.length;
      var p = largo >= 50 && largo <= 220 ? 100 : (largo <= 320 ? 40 : 0);
      if (c.libro.id == libroDelAno?.id) p += 30;
      p += (c.libro.rating ?? 0).round() * 4;
      return p;
    }

    citaDestacada =
        ([...citas]..sort((a, b) => puntos(b).compareTo(puntos(a)))).first;
  }

  void _calcularPropositos(
      List<LibraryGoal> metas, List<LibraryItem> biblioteca) {
    for (final meta in metas) {
      if (meta.type != LibraryItemType.book || meta.targetYear != year) {
        continue;
      }
      final enlazado =
          biblioteca.where((l) => l.id == meta.linkedLibraryItemId).firstOrNull;
      final cumplido = meta.isCompleted ||
          (enlazado?.status == LibraryItemStatus.completed &&
              enlazado?.completedDate?.year == year);
      propositos++;
      if (cumplido) propositosCumplidos++;
      listaPropositos.add((
        titulo: meta.title,
        portada: enlazado?.coverUrl ?? meta.coverUrl,
        cumplido: cumplido
      ));
    }
    listaPropositos.sort((a, b) => (b.cumplido ? 1 : 0) - (a.cumplido ? 1 : 0));
  }
}
