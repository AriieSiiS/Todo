import '../../domain/models.dart';
import 'resumen_obras.dart';
import 'wrapped_modelo.dart';

export 'resumen_obras.dart';

/// Un logro de Steam desbloqueado en el año.
class LogroDelAno {
  const LogroDelAno({
    required this.juego,
    required this.nombre,
    required this.descripcion,
    required this.cuando,
    this.porcentajeGlobal,
    this.icono,
  });
  final LibraryItem juego;
  final String nombre;
  final String descripcion;
  final DateTime cuando;

  /// Porcentaje de jugadores de Steam que lo tienen (rareza).
  final double? porcentajeGlobal;
  final String? icono;
}

/// Juego con sus logros del año y sus horas en Steam.
class JuegoConLogros {
  const JuegoConLogros({
    required this.juego,
    required this.delAno,
    required this.desbloqueados,
    required this.total,
    this.minutos,
    this.completadoEn,
  });
  final LibraryItem juego;
  final int delAno;
  final int desbloqueados;
  final int total;

  /// Minutos jugados en total según Steam (no solo en el año).
  final num? minutos;

  /// Día del último logro si se consiguieron todos.
  final DateTime? completadoEn;

  double get porcentaje => total == 0 ? 0 : desbloqueados / total * 100;
}

/// Id de Steam de un juego, sacado de su enlace o de su nota.
int? appIdDeJuego(LibraryItem juego) {
  final enlace = RegExp(r'store\.steampowered\.com/app/(\d+)')
      .firstMatch(juego.externalUrl ?? '');
  final nota = RegExp(r'Steam appid:\s*(\d+)', caseSensitive: false)
      .firstMatch(juego.note ?? '');
  return int.tryParse(enlace?.group(1) ?? nota?.group(1) ?? '');
}

/// Datos del Wrapped de videojuegos de un año.
///
/// [logros] es el contenido de cada `logros.json` guardado por la conexión de
/// Steam (por appid) y [minutosSteam], las horas jugadas por appid.
class ResumenJuegos extends ResumenObras {
  ResumenJuegos._(super.year, super.ajustes);

  final List<LogroDelAno> logrosDelAno = [];
  final List<JuegoConLogros> porLogros = [];
  final Map<DateTime, int> logrosPorDia = {};
  final List<int> logrosPorHora = List.filled(24, 0);
  final List<int> logrosPorDiaSemana = List.filled(7, 0);
  final List<int> logrosPorMes = List.filled(12, 0);
  LogroDelAno? logroMasRaro;
  DateTime? diaRecordLogros;
  int logrosDiaRecord = 0;
  LibraryItem? juegoDiaRecord;
  int rachaLogros = 0;
  DateTime? inicioRacha;
  DateTime? finRacha;

  /// Juegos con todos los logros, conseguidos este año.
  final List<JuegoConLogros> completados = [];

  /// Juegos jugados este año ordenados por horas totales en Steam.
  final List<JuegoConLogros> porHoras = [];
  final List<MapEntry<String, int>> plataformas = [];

  bool get hayLogros => logrosDelAno.isNotEmpty;
  bool get hayDatos => terminados.isNotEmpty || hayLogros;
  num get minutosJugados =>
      porHoras.fold<num>(0, (s, j) => s + (j.minutos ?? 0));

  static ResumenJuegos calcular({
    required List<LibraryItem> biblioteca,
    required int year,
    List<LibraryGoal> propositos = const [],
    List<Coleccion> colecciones = const [],
    Map<int, Map<String, dynamic>> logros = const {},
    Map<int, num> minutosSteam = const {},
    AjustesWrappedTipo ajustes = const AjustesWrappedTipo(),
  }) {
    final r = ResumenJuegos._(year, ajustes);
    final juegos = ResumenObras.obrasDe(
        biblioteca, (l) => l.type == LibraryItemType.game, ajustes);
    r.prepararTerminados(juegos);
    r._calcularSteam(juegos, logros, minutosSteam);
    r.calcularComun(
      obras: juegos,
      biblioteca: biblioteca,
      metas: propositos,
      metaDelTipo: (m) => m.type == LibraryItemType.game,
      colecciones: colecciones,
    );
    final cuenta = <String, int>{};
    for (final j in r.terminados) {
      final p = (j.platform ?? '').trim();
      if (p.isNotEmpty) cuenta.update(p, (v) => v + 1, ifAbsent: () => 1);
    }
    r.plataformas
        .addAll(cuenta.entries.toList()..sort((a, b) => b.value - a.value));
    return r;
  }

  int logrosDe(LibraryItem juego) {
    for (final j in porLogros) {
      if (j.juego.id == juego.id) return j.delAno;
    }
    return 0;
  }

  num? minutosDe(LibraryItem juego) {
    for (final j in porHoras) {
      if (j.juego.id == juego.id) return j.minutos;
    }
    return null;
  }

  @override
  String? creadorDe(LibraryItem obra) => obra.developer;

  @override
  int peso(LibraryItem obra) =>
      logrosDe(obra) * 600 + (minutosDe(obra) ?? 0).round();

  @override
  LibraryItem? destacadoSinNota() {
    final conLogros = terminados.where((j) => logrosDe(j) > 0).toList()
      ..sort((a, b) => peso(b).compareTo(peso(a)));
    return conLogros.isNotEmpty ? conLogros.first : super.destacadoSinNota();
  }

  void _calcularSteam(List<LibraryItem> juegos,
      Map<int, Map<String, dynamic>> logros, Map<int, num> minutosSteam) {
    final jugados = <LibraryItem>{
      ...terminados,
      ...juegos.where((j) => j.status == LibraryItemStatus.inProgress),
    };
    for (final juego in juegos) {
      final appId = appIdDeJuego(juego);
      final datos = appId == null ? null : logros[appId];
      var delAno = 0;
      var desbloqueados = 0;
      var total = 0;
      DateTime? ultimo;
      for (final a in (datos?['achievements'] as List? ?? const [])) {
        if (a is! Map) continue;
        total++;
        if (a['unlocked'] != true) continue;
        desbloqueados++;
        final instante = a['unlock_time'];
        if (instante is! int || instante <= 0) continue;
        final cuando = DateTime.fromMillisecondsSinceEpoch(instante * 1000);
        if (ultimo == null || cuando.isAfter(ultimo)) ultimo = cuando;
        if (cuando.year != year) continue;
        delAno++;
        final logro = LogroDelAno(
          juego: juego,
          nombre: '${a['name'] ?? ''}'.trim(),
          descripcion: '${a['description'] ?? ''}'.trim(),
          cuando: cuando,
          porcentajeGlobal: (a['global_percent'] as num?)?.toDouble(),
          icono: a['icon_path'] as String?,
        );
        logrosDelAno.add(logro);
        final dia = DateTime(cuando.year, cuando.month, cuando.day);
        logrosPorDia.update(dia, (v) => v + 1, ifAbsent: () => 1);
        logrosPorHora[cuando.hour]++;
        logrosPorDiaSemana[cuando.weekday - 1]++;
        logrosPorMes[cuando.month - 1]++;
        final rareza = logro.porcentajeGlobal;
        if (rareza != null &&
            rareza > 0 &&
            (logroMasRaro == null ||
                rareza < (logroMasRaro!.porcentajeGlobal ?? 101))) {
          logroMasRaro = logro;
        }
      }
      if (delAno > 0) jugados.add(juego);
      final minutos = appId == null
          ? null
          : (datos?['playtime_minutes'] as num? ?? minutosSteam[appId]);
      final info = JuegoConLogros(
        juego: juego,
        delAno: delAno,
        desbloqueados: desbloqueados,
        total: total,
        minutos: minutos,
        completadoEn: total > 0 && desbloqueados == total ? ultimo : null,
      );
      if (delAno > 0) porLogros.add(info);
      if (jugados.contains(juego) && (minutos ?? 0) > 0) porHoras.add(info);
      if (info.completadoEn?.year == year) completados.add(info);
    }
    porLogros.sort((a, b) => b.delAno.compareTo(a.delAno));
    porHoras.sort((a, b) => (b.minutos ?? 0).compareTo(a.minutos ?? 0));
    logrosDelAno.sort((a, b) => a.cuando.compareTo(b.cuando));

    for (final e in logrosPorDia.entries) {
      if (e.value > logrosDiaRecord) {
        logrosDiaRecord = e.value;
        diaRecordLogros = e.key;
      }
    }
    if (diaRecordLogros != null) {
      final cuenta = <LibraryItem, int>{};
      for (final l in logrosDelAno) {
        final d = l.cuando;
        if (DateTime(d.year, d.month, d.day) == diaRecordLogros) {
          cuenta.update(l.juego, (v) => v + 1, ifAbsent: () => 1);
        }
      }
      juegoDiaRecord = (cuenta.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;
    }
    final dias = logrosPorDia.keys.toList()..sort();
    var actual = 0;
    DateTime? inicio, previo;
    for (final dia in dias) {
      final seguido = previo != null &&
          DateTime(previo.year, previo.month, previo.day + 1) == dia;
      actual = seguido ? actual + 1 : 1;
      if (!seguido) inicio = dia;
      if (actual > rachaLogros) {
        rachaLogros = actual;
        inicioRacha = inicio;
        finRacha = dia;
      }
      previo = dia;
    }
  }
}
