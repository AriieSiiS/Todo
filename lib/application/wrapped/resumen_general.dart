import '../../domain/models.dart';
import 'resumen_juegos.dart';
import 'resumen_libros.dart';
import 'resumen_pantalla.dart';
import 'wrapped_modelo.dart';

export 'resumen_juegos.dart';
export 'resumen_libros.dart';
export 'resumen_pantalla.dart';

/// Un universo o saga que aparece en varios tipos de obra del año.
class UniversoCruzado {
  const UniversoCruzado(this.nombre, this.obras);
  final String nombre;
  final List<LibraryItem> obras;
  Set<LibraryItemType> get tipos => {for (final o in obras) o.type};
}

/// Datos del Wrapped general: toda la Biblioteca del año de un vistazo.
///
/// Reúne los tres resúmenes especializados (con los ajustes de cada uno) y
/// calcula lo común sobre todas las obras juntas.
class ResumenGeneral extends ResumenObras {
  ResumenGeneral._(
      super.year, super.ajustes, this.libros, this.pantalla, this.juegos);

  final ResumenLibros libros;
  final ResumenPantalla pantalla;
  final ResumenJuegos juegos;
  final List<UniversoCruzado> universos = [];

  /// Días distintos en los que se terminó algo.
  int diasConFinal = 0;

  bool get hayDatos =>
      terminados.isNotEmpty || libros.hayKindle || juegos.hayLogros;

  int cuantos(LibraryItemType tipo) =>
      terminados.where((o) => o.type == tipo).length;

  /// Horas dedicadas con datos reales o estimados: Kindle y pantalla.
  int get minutosHistorias => libros.segundos ~/ 60 + pantalla.minutosTotales;

  static ResumenGeneral calcular({
    required List<LibraryItem> biblioteca,
    required int year,
    List<LibraryGoal> propositos = const [],
    List<Coleccion> colecciones = const [],
    Map<int, Map<String, dynamic>> logros = const {},
    Map<int, num> minutosSteam = const {},
    required AjustesWrapped todos,
  }) {
    final general = todos.para(WrappedTipo.general, year);
    // Lo que se excluye en el general vale para los tres resúmenes.
    AjustesWrappedTipo con(WrappedTipo t) {
      final propio = todos.para(t, year);
      return AjustesWrappedTipo(
        portada: propio.portada,
        destacado: propio.destacado,
        excluir: {...propio.excluir, ...general.excluir}.toList(),
      );
    }

    final r = ResumenGeneral._(
      year,
      general,
      ResumenLibros.calcular(
          biblioteca: biblioteca,
          year: year,
          propositos: propositos,
          colecciones: colecciones,
          ajustes: con(WrappedTipo.libros)),
      ResumenPantalla.calcular(
          biblioteca: biblioteca,
          year: year,
          propositos: propositos,
          colecciones: colecciones,
          ajustes: con(WrappedTipo.pantalla)),
      ResumenJuegos.calcular(
          biblioteca: biblioteca,
          year: year,
          propositos: propositos,
          colecciones: colecciones,
          logros: logros,
          minutosSteam: minutosSteam,
          ajustes: con(WrappedTipo.juegos)),
    );
    final obras = ResumenObras.obrasDe(biblioteca, (_) => true, general);
    r.prepararTerminados(obras);
    r.calcularComun(
      obras: obras,
      biblioteca: biblioteca,
      metas: propositos,
      metaDelTipo: (_) => true,
      colecciones: colecciones,
    );
    r._calcularUniversos(obras);
    r.diasConFinal = {
      for (final o in r.terminados)
        DateTime(
            o.completedDate!.year, o.completedDate!.month, o.completedDate!.day)
    }.length;
    return r;
  }

  @override
  String? creadorDe(LibraryItem obra) => switch (obra.type) {
        LibraryItemType.book => obra.author,
        LibraryItemType.movieSeries => obra.creatorOrDirector,
        LibraryItemType.game => obra.developer,
      };

  @override
  int peso(LibraryItem obra) => switch (obra.type) {
        LibraryItemType.book => libros.peso(obra),
        LibraryItemType.movieSeries => pantalla.peso(obra),
        LibraryItemType.game => juegos.peso(obra),
      };

  void _calcularUniversos(List<LibraryItem> obras) {
    final porNombre = <String, List<LibraryItem>>{};
    final nombreDe = <String, String>{};
    for (final o in terminados) {
      final nombres = {
        for (final n in [o.universeName, o.collectionName])
          if ((n ?? '').trim().isNotEmpty) n!.trim()
      };
      for (final n in nombres) {
        final clave = normalizarTituloWrapped(n);
        nombreDe.putIfAbsent(clave, () => n);
        final lista = porNombre.putIfAbsent(clave, () => []);
        if (!lista.contains(o)) lista.add(o);
      }
    }
    universos
      ..addAll([
        for (final e in porNombre.entries)
          if ({for (final o in e.value) o.type}.length >= 2)
            UniversoCruzado(nombreDe[e.key]!, e.value)
      ])
      ..sort((a, b) => b.obras.length.compareTo(a.obras.length));
  }
}
