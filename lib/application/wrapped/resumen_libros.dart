import '../../domain/models.dart';
import 'resumen_obras.dart';
import 'wrapped_modelo.dart';

export 'resumen_obras.dart';

/// Libro con el tiempo y las páginas que registró el Kindle en el año.
class LibroConLectura {
  const LibroConLectura(this.libro, this.segundos, this.paginas, this.dias);
  final LibraryItem libro;
  final int segundos;
  final int paginas;
  final int dias;
}

/// Autor de los libros del año (nombre histórico de [CreadorDelAno]).
typedef AutorDelAno = CreadorDelAno;

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
class ResumenLibros extends ResumenObras {
  ResumenLibros._(super.year, super.ajustes);

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

  /// Nombres propios de los libros para los campos comunes.
  LibraryItem? get libroDelAno => destacado;
  List<AutorDelAno> get autores => creadores;

  // Formatos y citas --------------------------------------------------------
  int fisicos = 0;
  int digitales = 0;
  final List<CitaDelAno> citas = [];
  CitaDelAno? citaDestacada;

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
    final libros = ResumenObras.obrasDe(
        biblioteca, (l) => l.type == LibraryItemType.book, ajustes);
    r.prepararTerminados(libros);
    r._calcularKindle(libros);
    r._calcularPaginas(
        libros.where((l) => ResumenObras.terminadoEn(l, year - 1)));
    r.calcularComun(
      obras: libros,
      biblioteca: biblioteca,
      metas: propositos,
      metaDelTipo: (m) => m.type == LibraryItemType.book,
      colecciones: colecciones,
    );
    r._calcularFormatos();
    r._calcularCitas(libros);
    return r;
  }

  /// Busca un libro por id o por título normalizado.
  static LibraryItem? buscar(Iterable<LibraryItem> libros, String? clave) =>
      ResumenObras.buscar(libros, clave);

  @override
  String? creadorDe(LibraryItem obra) => obra.author;

  @override
  int peso(LibraryItem obra) => segundosDe(obra);

  @override
  LibraryItem? destacadoSinNota() =>
      porTiempo.isNotEmpty ? porTiempo.first.libro : super.destacadoSinNota();

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

  void _calcularFormatos() {
    for (final l in terminados) {
      final formato = normalizarTituloWrapped(l.format ?? '');
      if (formato.contains('fisic') || formato.contains('papel')) {
        fisicos++;
      } else if (formato.contains('ebook') ||
          formato.contains('electr') ||
          formato.contains('kindle') ||
          formato.contains('digital')) {
        digitales++;
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
      if (c.libro.id == destacado?.id) p += 30;
      p += (c.libro.rating ?? 0).round() * 4;
      return p;
    }

    citaDestacada =
        ([...citas]..sort((a, b) => puntos(b).compareTo(puntos(a)))).first;
  }
}
