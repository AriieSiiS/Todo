import '../../domain/models.dart';
import 'resumen_obras.dart';
import 'wrapped_modelo.dart';

export 'resumen_obras.dart';

/// Minutos de una obra de pantalla y si son una estimación.
typedef MinutosObra = ({int minutos, bool estimado, int episodios});

/// Calcula cuánto dura una película o una serie a partir de su ficha.
///
/// Entiende «137 min», «2 h 52 min», «41-61 min» (por episodio), «24
/// episodios», «2 temporadas, 26 episodios» o «28 min por episodio». Si falta
/// algún dato se estima: 110 minutos por película, 24 por episodio de anime y
/// 45 por episodio de otras series.
MinutosObra minutosDeObra(LibraryItem obra) {
  final texto = (obra.duration ?? '').toLowerCase();
  int? numero(RegExp r) => int.tryParse(r.firstMatch(texto)?.group(1) ?? '');
  final horas = numero(RegExp(r'(\d+)\s*h\b'));
  final sueltos = numero(RegExp(r'(\d+)\s*m(?:in)?\b'));
  final rango = RegExp(r'(\d+)\s*-\s*(\d+)\s*min').firstMatch(texto);
  int? minutos;
  if (rango != null) {
    minutos = (int.parse(rango.group(1)!) + int.parse(rango.group(2)!)) ~/ 2;
  } else if (horas != null) {
    minutos = horas * 60 + (sueltos ?? 0);
  } else {
    minutos = sueltos;
  }
  if (obra.mediaType != LibraryMediaType.series) {
    return (minutos: minutos ?? 110, estimado: minutos == null, episodios: 0);
  }
  final anime =
      normalizarTituloWrapped('${obra.format} ${obra.country} ${obra.genre}')
          .contains(RegExp(r'anime|japon'));
  final porEpisodio =
      minutos != null && minutos <= 80 ? minutos : (anime ? 24 : 45);
  final episodios = numero(RegExp(r'(\d+)\s*episodios?')) ??
      obra.progressTotal ??
      (obra.seasonCount ?? 1) * (anime ? 12 : 10);
  return (
    minutos: porEpisodio * episodios,
    estimado: minutos == null || !texto.contains('episodio'),
    episodios: episodios,
  );
}

/// Datos del Wrapped de series y películas de un año.
class ResumenPantalla extends ResumenObras {
  ResumenPantalla._(super.year, super.ajustes);

  final List<LibraryItem> peliculas = [];
  final List<LibraryItem> series = [];
  final Map<LibraryItem, MinutosObra> minutos = {};
  int minutosPeliculas = 0;
  int minutosSeries = 0;
  int episodios = 0;
  bool hayEstimaciones = false;
  LibraryItem? masLarga;
  LibraryItem? masCorta;
  final List<MapEntry<String, int>> paises = [];
  final List<MapEntry<String, int>> plataformas = [];
  final List<LibraryItem> estrenos = [];
  final List<LibraryItem> enCine = [];
  final List<LibraryItem> repetidas = [];
  final List<int> terminadosPorDiaSemana = List.filled(7, 0);

  int get minutosTotales => minutosPeliculas + minutosSeries;
  bool get hayDatos => terminados.isNotEmpty;

  static ResumenPantalla calcular({
    required List<LibraryItem> biblioteca,
    required int year,
    List<LibraryGoal> propositos = const [],
    List<Coleccion> colecciones = const [],
    AjustesWrappedTipo ajustes = const AjustesWrappedTipo(),
  }) {
    final r = ResumenPantalla._(year, ajustes);
    final obras = ResumenObras.obrasDe(
        biblioteca, (l) => l.type == LibraryItemType.movieSeries, ajustes);
    r.prepararTerminados(obras);
    r._calcularPropios();
    r.calcularComun(
      obras: obras,
      biblioteca: biblioteca,
      metas: propositos,
      metaDelTipo: (m) => m.type == LibraryItemType.movieSeries,
      colecciones: colecciones,
    );
    return r;
  }

  @override
  String? creadorDe(LibraryItem obra) => obra.creatorOrDirector;

  @override
  int peso(LibraryItem obra) => minutos[obra]?.minutos ?? 0;

  void _calcularPropios() {
    final paisesCuenta = <String, int>{};
    final plataformasCuenta = <String, int>{};
    for (final o in terminados) {
      final m = minutosDeObra(o);
      minutos[o] = m;
      hayEstimaciones |= m.estimado;
      if (o.mediaType == LibraryMediaType.series) {
        series.add(o);
        minutosSeries += m.minutos;
        episodios += m.episodios;
      } else {
        peliculas.add(o);
        minutosPeliculas += m.minutos;
        if (!m.estimado) {
          if (masLarga == null || m.minutos > minutos[masLarga]!.minutos) {
            masLarga = o;
          }
          if (masCorta == null || m.minutos < minutos[masCorta]!.minutos) {
            masCorta = o;
          }
        }
      }
      for (final parte in (o.country ?? '').split(RegExp(r',| y '))) {
        final pais = _pais(parte.trim());
        if (pais.isNotEmpty) {
          paisesCuenta.update(pais, (v) => v + 1, ifAbsent: () => 1);
        }
      }
      final plataforma = (o.platform ?? '').trim();
      if (plataforma.isNotEmpty) {
        plataformasCuenta.update(plataforma, (v) => v + 1, ifAbsent: () => 1);
      }
      if (o.releaseYear == year) estrenos.add(o);
      if (normalizarTituloWrapped(o.format ?? '').contains('cine')) {
        enCine.add(o);
      }
      if (o.rewatchCount > 1) repetidas.add(o);
      terminadosPorDiaSemana[o.completedDate!.toLocal().weekday - 1]++;
    }
    int orden(MapEntry<String, int> a, MapEntry<String, int> b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    }

    paises.addAll(paisesCuenta.entries.toList()..sort(orden));
    plataformas.addAll(plataformasCuenta.entries.toList()..sort(orden));
  }

  /// Nombres de país unificados («Japon» → «Japón»).
  static String _pais(String texto) {
    const conocidos = {
      'japon': 'Japón',
      'espana': 'España',
      'canada': 'Canadá',
      'reino unido': 'Reino Unido',
      'estados unidos': 'Estados Unidos',
      'eeuu': 'Estados Unidos',
      'francia': 'Francia',
      'mexico': 'México',
      'corea del sur': 'Corea del Sur',
    };
    final clave = normalizarTituloWrapped(texto);
    if (clave.isEmpty) return '';
    return conocidos[clave] ?? texto[0].toUpperCase() + texto.substring(1);
  }
}
