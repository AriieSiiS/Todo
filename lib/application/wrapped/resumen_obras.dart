import 'dart:math' as math;

import '../../domain/models.dart';
import 'wrapped_modelo.dart';

/// Autor, cineasta o estudio con las obras que se terminaron suyas en el año.
class CreadorDelAno {
  const CreadorDelAno(this.nombre, this.obras, {required this.nuevo});
  final String nombre;
  final List<LibraryItem> obras;

  /// No se había terminado ninguna obra suya en años anteriores.
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

typedef PropositoDelAno = ({String titulo, String? portada, bool cumplido});

/// Lo que comparten todos los Wrapped de Biblioteca: obras terminadas, notas,
/// creadores, géneros, sagas, épocas, propósitos y lo que queda pendiente.
///
/// Cada tipo (libros, series y películas, juegos) extiende esta clase con sus
/// datos propios y llama a [calcularComun] con sus obras.
abstract class ResumenObras {
  ResumenObras(this.year, this.ajustes);

  final int year;
  final AjustesWrappedTipo ajustes;

  /// Terminadas en el año, de la primera a la última.
  final List<LibraryItem> terminados = [];
  int terminadosAnterior = 0;

  double? notaMedia;
  LibraryItem? destacado;
  LibraryItem? portada;
  LibraryItem? peorValorado;
  final List<int> notasPorEstrella = List.filled(5, 0);

  final List<CreadorDelAno> creadores = [];
  final List<MapEntry<String, int>> generos = [];
  final List<SagaDelAno> sagas = [];

  int? anoMasAntiguo;
  int? anoMasReciente;
  LibraryItem? obraMasAntigua;
  LibraryItem? obraMasReciente;
  final List<int> terminadosPorMes = List.filled(12, 0);

  /// Día en que se añadieron más obras de este tipo a la Biblioteca.
  DateTime? diaMasAnadidos;
  int anadidosDiaRecord = 0;
  int anadidosEnElAno = 0;

  /// Día en que se terminaron más obras (un maratón).
  DateTime? diaMasTerminados;
  final List<LibraryItem> terminadosDiaRecord = [];

  int propositos = 0;
  int propositosCumplidos = 0;
  final List<PropositoDelAno> listaPropositos = [];
  final List<LibraryItem> enCurso = [];
  int pendientes = 0;

  /// Obras con nota de las terminadas en el año.
  List<LibraryItem> get valorados =>
      terminados.where((l) => l.rating != null).toList();

  /// Peso extra de una obra para desempatar (horas, logros...).
  int peso(LibraryItem obra) => 0;

  /// Persona o estudio detrás de una obra.
  String? creadorDe(LibraryItem obra);

  /// Obra que se usa como destacada si ninguna tiene nota.
  LibraryItem? destacadoSinNota() =>
      terminados.isEmpty ? null : terminados.last;

  static bool terminadoEn(LibraryItem l, int a) =>
      l.status == LibraryItemStatus.completed && l.completedDate?.year == a;

  /// Filtra la Biblioteca por tipo y quita las obras excluidas en ajustes.
  static List<LibraryItem> obrasDe(List<LibraryItem> biblioteca,
      bool Function(LibraryItem) delTipo, AjustesWrappedTipo ajustes) {
    final excluidos = ajustes.excluir.map(normalizarTituloWrapped).toSet();
    return [
      for (final l in biblioteca)
        if (delTipo(l) &&
            !ajustes.excluir.contains(l.id) &&
            !excluidos.contains(normalizarTituloWrapped(l.title)))
          l
    ];
  }

  /// Busca una obra por id o por título normalizado.
  static LibraryItem? buscar(Iterable<LibraryItem> obras, String? clave) {
    if (clave == null || clave.trim().isEmpty) return null;
    for (final obra in obras) {
      if (obra.id == clave) return obra;
    }
    final buscado = normalizarTituloWrapped(clave);
    for (final obra in obras) {
      if (normalizarTituloWrapped(obra.title) == buscado) return obra;
    }
    for (final obra in obras) {
      if (normalizarTituloWrapped(obra.title).contains(buscado)) return obra;
    }
    return null;
  }

  /// Rellena los terminados del año; va antes de los cálculos propios.
  void prepararTerminados(List<LibraryItem> obras) {
    terminados
      ..addAll(obras.where((l) => terminadoEn(l, year)))
      ..sort((a, b) => a.completedDate!.compareTo(b.completedDate!));
    terminadosAnterior = obras.where((l) => terminadoEn(l, year - 1)).length;
  }

  void calcularComun({
    required List<LibraryItem> obras,
    required List<LibraryItem> biblioteca,
    required List<LibraryGoal> metas,
    required bool Function(LibraryGoal) metaDelTipo,
    List<Coleccion> colecciones = const [],
  }) {
    _calcularNotas(obras);
    _calcularCreadores(obras);
    _calcularGeneros();
    _calcularSagas(obras, colecciones);
    _calcularEpocasYDias(obras);
    _calcularPropositos(metas.where(metaDelTipo), biblioteca);
    enCurso
        .addAll(obras.where((l) => l.status == LibraryItemStatus.inProgress));
    pendientes =
        obras.where((l) => l.status == LibraryItemStatus.pending).length;
  }

  int _comparar(LibraryItem a, LibraryItem b) {
    final nota = (b.rating ?? -1).compareTo(a.rating ?? -1);
    if (nota != 0) return nota;
    return peso(b).compareTo(peso(a));
  }

  void _calcularNotas(List<LibraryItem> obras) {
    final conNota = valorados;
    if (conNota.isNotEmpty) {
      notaMedia =
          conNota.fold<double>(0, (s, l) => s + l.rating!) / conNota.length;
      for (final l in conNota) {
        notasPorEstrella[l.rating!.round().clamp(1, 5) - 1]++;
      }
    }
    destacado = buscar(obras, ajustes.destacado) ??
        (conNota.isNotEmpty
            ? ([...conNota]..sort(_comparar)).first
            : destacadoSinNota());
    portada = buscar(obras, ajustes.portada) ??
        destacado ??
        (terminados.isEmpty ? null : terminados.last);
    if (conNota.length >= 3) {
      final peor = ([...conNota]..sort(_comparar)).last;
      if (peor.rating! < (notaMedia ?? 0) - 0.4 && peor.id != destacado?.id) {
        peorValorado = peor;
      }
    }
  }

  void _calcularCreadores(List<LibraryItem> obras) {
    final previos = <String>{
      for (final l in obras)
        if (l.status == LibraryItemStatus.completed &&
            l.completedDate != null &&
            l.completedDate!.year < year)
          for (final c in _nombres(creadorDe(l))) normalizarTituloWrapped(c),
    };
    final porCreador = <String, List<LibraryItem>>{};
    final nombreDe = <String, String>{};
    for (final l in terminados) {
      for (final nombre in _nombres(creadorDe(l))) {
        final clave = normalizarTituloWrapped(nombre);
        nombreDe.putIfAbsent(clave, () => nombre);
        porCreador.putIfAbsent(clave, () => []).add(l);
      }
    }
    int pesoTotal(CreadorDelAno c) =>
        c.obras.fold<int>(0, (t, l) => t + peso(l));
    creadores
      ..addAll([
        for (final e in porCreador.entries)
          CreadorDelAno(nombreDe[e.key]!, e.value,
              nuevo: !previos.contains(e.key))
      ])
      ..sort((a, b) {
        final c = b.obras.length.compareTo(a.obras.length);
        if (c != 0) return c;
        final s = pesoTotal(b).compareTo(pesoTotal(a));
        return s != 0 ? s : a.nombre.compareTo(b.nombre);
      });
  }

  /// Un creador o varios separados por comas, «/» o « y ».
  static List<String> _nombres(String? texto) => [
        for (final parte in (texto ?? '').split(RegExp(r',|/| y | & ')))
          if (parte.trim().length > 1 &&
              !RegExp(r'\(mac\)|^unknown$', caseSensitive: false)
                  .hasMatch(parte.trim()))
            parte.trim()
      ];

  void _calcularGeneros() {
    final cuenta = <String, int>{};
    final etiqueta = <String, String>{};
    // En los empates gana el género que suele ir primero en las fichas y,
    // después, el de las obras con más peso (horas, logros...).
    final pesos = <String, int>{};
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
        final extra = math.max(0, 3 - posicion) * 1000000 + peso(l) ~/ 60;
        pesos.update(clave, (v) => v + extra, ifAbsent: () => extra);
        posicion++;
      }
    }
    final orden = cuenta.keys.toList()
      ..sort((a, b) {
        final c = cuenta[b]!.compareTo(cuenta[a]!);
        if (c != 0) return c;
        final p = pesos[b]!.compareTo(pesos[a]!);
        return p != 0 ? p : a.compareTo(b);
      });
    generos.addAll(orden.map((k) => MapEntry(etiqueta[k]!, cuenta[k]!)));
  }

  void _calcularSagas(List<LibraryItem> obras, List<Coleccion> colecciones) {
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
      final leidos = [...e.value]..sort((a, b) =>
          (a.collectionNumber ?? 999).compareTo(b.collectionNumber ?? 999));
      final deLaSaga = obras
          .where(
              (l) => normalizarTituloWrapped(l.collectionName ?? '') == e.key)
          .toList();
      final enCursoSaga = deLaSaga
          .where((l) => l.status == LibraryItemStatus.inProgress)
          .toList()
        ..sort((a, b) =>
            (a.collectionNumber ?? 0).compareTo(b.collectionNumber ?? 0));
      var ultimo = 0;
      for (final l in deLaSaga) {
        if (l.status == LibraryItemStatus.pending) continue;
        ultimo = math.max(ultimo, l.collectionNumber ?? 0);
      }
      sagas.add(SagaDelAno(
          nombre: nombreDe[e.key]!,
          leidos: leidos,
          enCurso: enCursoSaga.isEmpty ? null : enCursoSaga.last,
          siguiente: ultimo > 0
              ? _siguiente(e.key, ultimo + 1, deLaSaga, colecciones)
              : null));
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

  void _calcularEpocasYDias(List<LibraryItem> obras) {
    final porDia = <DateTime, List<LibraryItem>>{};
    for (final l in terminados) {
      final ano = l.releaseYear;
      if (ano != null && ano > 0) {
        if (anoMasAntiguo == null || ano < anoMasAntiguo!) {
          anoMasAntiguo = ano;
          obraMasAntigua = l;
        }
        if (anoMasReciente == null || ano >= anoMasReciente!) {
          anoMasReciente = ano;
          obraMasReciente = l;
        }
      }
      final c = l.completedDate!.toLocal();
      terminadosPorMes[c.month - 1]++;
      porDia.putIfAbsent(DateTime(c.year, c.month, c.day), () => []).add(l);
    }
    for (final e in porDia.entries) {
      if (e.value.length > terminadosDiaRecord.length) {
        diaMasTerminados = e.key;
        terminadosDiaRecord
          ..clear()
          ..addAll(e.value);
      }
    }
    final anadidos = <DateTime, int>{};
    for (final l in obras) {
      final c = l.createdAt.toLocal();
      if (c.year != year) continue;
      anadidosEnElAno++;
      anadidos.update(DateTime(c.year, c.month, c.day), (v) => v + 1,
          ifAbsent: () => 1);
    }
    for (final e in anadidos.entries) {
      if (e.value > anadidosDiaRecord) {
        anadidosDiaRecord = e.value;
        diaMasAnadidos = e.key;
      }
    }
  }

  void _calcularPropositos(
      Iterable<LibraryGoal> metas, List<LibraryItem> biblioteca) {
    for (final meta in metas) {
      if (meta.targetYear != year) continue;
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
