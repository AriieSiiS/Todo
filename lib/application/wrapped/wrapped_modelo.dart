import 'dart:convert';
import 'dart:io';

/// Resúmenes anuales de Biblioteca al estilo de las historias animadas.
///
/// Cada tipo se genera solo al llegar su fecha de publicación (por defecto el
/// 31 de diciembre) y se avisa dentro de la app. Los ajustes viven en
/// `Documents/Todo/wrapped/ajustes.json` para poder cambiarlos a mano, desde
/// la propia app o pidiéndoselo a un agente; el estado de avisos y vistas va
/// aparte en `estado.json`. La guía de variables está en `docs/WRAPPED.md`.
enum WrappedTipo {
  libros('libros', 'Libros', 'Tu año en libros', disponible: true),
  general('general', 'Biblioteca', 'Tu año en Biblioteca'),
  pantalla('pantalla', 'Series y películas', 'Tu año en series y películas'),
  juegos('juegos', 'Videojuegos', 'Tu año en videojuegos');

  const WrappedTipo(this.clave, this.nombre, this.titulo,
      {this.disponible = false});

  /// Identificador estable en archivos y nombres de imagen.
  final String clave;
  final String nombre;
  final String titulo;

  /// Los tipos aún no construidos no se publican ni aparecen en la app.
  final bool disponible;

  static WrappedTipo? desdeClave(String clave) {
    for (final tipo in values) {
      if (tipo.clave == clave) return tipo;
    }
    return null;
  }
}

/// Variables de un Wrapped. Todas son opcionales: sin ellas se elige solo.
///
/// Los libros se indican por su id de Biblioteca o por su título (se ignoran
/// mayúsculas y tildes), así que «pon Circe en portada» es `portada: "Circe"`.
class AjustesWrappedTipo {
  const AjustesWrappedTipo({
    this.portada,
    this.destacado,
    this.excluir = const [],
    this.ocultar = const [],
    this.titulo,
    this.nombre,
    this.mensajeFinal,
    this.cita,
    this.musica,
    this.paleta,
    this.segundosPorDiapositiva,
  });

  /// Libro de la portada (primera diapositiva).
  final String? portada;

  /// Libro del año; si falta, el de mejor nota y más tiempo de lectura.
  final String? destacado;

  /// Libros que no cuentan en el resumen.
  final List<String> excluir;

  /// Diapositivas ocultas, por su identificador (ver `docs/WRAPPED.md`).
  final List<String> ocultar;

  /// Texto grande de la portada en lugar de «Tu año en libros».
  final String? titulo;

  /// Nombre con el que saludar en la portada.
  final String? nombre;

  /// Frase de la última diapositiva.
  final String? mensajeFinal;

  /// Fragmento de la cita que se quiere destacar.
  final String? cita;

  /// Ruta de un mp3 propio, o `ninguna` para silenciar.
  final String? musica;

  /// `automatica` (colores de las portadas) o el nombre de una paleta.
  final String? paleta;
  final int? segundosPorDiapositiva;

  static const campos = [
    'portada',
    'destacado',
    'excluir',
    'ocultar',
    'titulo',
    'nombre',
    'mensajeFinal',
    'cita',
    'musica',
    'paleta',
    'segundosPorDiapositiva',
  ];

  bool get sinMusica => musica?.trim().toLowerCase() == 'ninguna';

  /// Combina los ajustes de un año con los generales del tipo.
  AjustesWrappedTipo sobre(AjustesWrappedTipo base) => AjustesWrappedTipo(
        portada: portada ?? base.portada,
        destacado: destacado ?? base.destacado,
        excluir: {...base.excluir, ...excluir}.toList(),
        ocultar: {...base.ocultar, ...ocultar}.toList(),
        titulo: titulo ?? base.titulo,
        nombre: nombre ?? base.nombre,
        mensajeFinal: mensajeFinal ?? base.mensajeFinal,
        cita: cita ?? base.cita,
        musica: musica ?? base.musica,
        paleta: paleta ?? base.paleta,
        segundosPorDiapositiva:
            segundosPorDiapositiva ?? base.segundosPorDiapositiva,
      );

  factory AjustesWrappedTipo.desdeJson(Map<String, dynamic> json) {
    String? texto(String clave) {
      final valor = json[clave];
      return valor is String && valor.trim().isNotEmpty ? valor.trim() : null;
    }

    List<String> lista(String clave) => [
          for (final valor in json[clave] as List? ?? const [])
            if (valor is String && valor.trim().isNotEmpty) valor.trim()
        ];
    final segundos = json['segundosPorDiapositiva'];
    return AjustesWrappedTipo(
      portada: texto('portada'),
      destacado: texto('destacado'),
      excluir: lista('excluir'),
      ocultar: lista('ocultar'),
      titulo: texto('titulo'),
      nombre: texto('nombre'),
      mensajeFinal: texto('mensajeFinal'),
      cita: texto('cita'),
      musica: texto('musica'),
      paleta: texto('paleta'),
      segundosPorDiapositiva:
          segundos is num ? segundos.round().clamp(3, 30) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (portada != null) 'portada': portada,
        if (destacado != null) 'destacado': destacado,
        if (excluir.isNotEmpty) 'excluir': excluir,
        if (ocultar.isNotEmpty) 'ocultar': ocultar,
        if (titulo != null) 'titulo': titulo,
        if (nombre != null) 'nombre': nombre,
        if (mensajeFinal != null) 'mensajeFinal': mensajeFinal,
        if (cita != null) 'cita': cita,
        if (musica != null) 'musica': musica,
        if (paleta != null) 'paleta': paleta,
        if (segundosPorDiapositiva != null)
          'segundosPorDiapositiva': segundosPorDiapositiva,
      };

  AjustesWrappedTipo copiaCon({
    String? portada,
    bool quitarPortada = false,
    String? destacado,
    bool quitarDestacado = false,
    List<String>? excluir,
    List<String>? ocultar,
    String? musica,
    bool quitarMusica = false,
    String? paleta,
  }) =>
      AjustesWrappedTipo(
        portada: quitarPortada ? null : portada ?? this.portada,
        destacado: quitarDestacado ? null : destacado ?? this.destacado,
        excluir: excluir ?? this.excluir,
        ocultar: ocultar ?? this.ocultar,
        titulo: titulo,
        nombre: nombre,
        mensajeFinal: mensajeFinal,
        cita: cita,
        musica: quitarMusica ? null : musica ?? this.musica,
        paleta: paleta ?? this.paleta,
        segundosPorDiapositiva: segundosPorDiapositiva,
      );
}

/// Todos los ajustes: fecha de publicación y variables por tipo y año.
///
/// En el JSON, la clave `libros` vale para todos los años y `libros-2026`
/// solo para ese año (gana sobre la general).
class AjustesWrapped {
  const AjustesWrapped({
    this.automatico = true,
    this.mesPublicacion = 12,
    this.diaPublicacion = 31,
    this.horaPublicacion = 10,
    this.porClave = const {},
  });

  final bool automatico;
  final int mesPublicacion;
  final int diaPublicacion;
  final int horaPublicacion;
  final Map<String, AjustesWrappedTipo> porClave;

  static String claveDe(WrappedTipo tipo, int year) => '${tipo.clave}-$year';

  AjustesWrappedTipo para(WrappedTipo tipo, int year) {
    final base = porClave[tipo.clave] ?? const AjustesWrappedTipo();
    final anual = porClave[claveDe(tipo, year)];
    return anual == null ? base : anual.sobre(base);
  }

  /// Momento en que el Wrapped de [year] queda listo.
  DateTime publicacion(int year) {
    final mes = mesPublicacion.clamp(1, 12);
    // Publicar en enero significa enero del año siguiente: el año ya cerrado.
    final anoReal = mes <= 2 ? year + 1 : year;
    final ultimoDia = DateTime(anoReal, mes + 1, 0).day;
    return DateTime(anoReal, mes, diaPublicacion.clamp(1, ultimoDia),
        horaPublicacion.clamp(0, 23));
  }

  AjustesWrapped conTipo(WrappedTipo tipo, int year, AjustesWrappedTipo valor,
          {bool todosLosAnos = false}) =>
      AjustesWrapped(
        automatico: automatico,
        mesPublicacion: mesPublicacion,
        diaPublicacion: diaPublicacion,
        horaPublicacion: horaPublicacion,
        porClave: {
          ...porClave,
          todosLosAnos ? tipo.clave : claveDe(tipo, year): valor,
        },
      );

  factory AjustesWrapped.desdeJson(Map<String, dynamic> json) {
    final publicacion = json['publicacion'];
    int leer(String clave, int defecto) {
      final valor = publicacion is Map ? publicacion[clave] : null;
      return valor is num ? valor.round() : defecto;
    }

    final porClave = <String, AjustesWrappedTipo>{};
    for (final entrada in json.entries) {
      final clave = entrada.key;
      final valor = entrada.value;
      if (valor is! Map) continue;
      final tipo = WrappedTipo.desdeClave(clave.split('-').first);
      if (tipo == null) continue;
      porClave[clave] =
          AjustesWrappedTipo.desdeJson(Map<String, dynamic>.from(valor));
    }
    return AjustesWrapped(
      automatico:
          json['automatico'] is bool ? json['automatico'] as bool : true,
      mesPublicacion: leer('mes', 12),
      diaPublicacion: leer('dia', 31),
      horaPublicacion: leer('hora', 10),
      porClave: porClave,
    );
  }

  Map<String, dynamic> toJson() => {
        'automatico': automatico,
        'publicacion': {
          'mes': mesPublicacion,
          'dia': diaPublicacion,
          'hora': horaPublicacion,
        },
        for (final entrada
            in (porClave.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key))))
          if (entrada.value.toJson().isNotEmpty)
            entrada.key: entrada.value.toJson(),
      };
}

/// Cuándo se avisó y se vio cada Wrapped (`libros-2026`).
class EstadoWrapped {
  const EstadoWrapped({this.avisados = const {}, this.vistos = const {}});

  final Map<String, DateTime> avisados;
  final Map<String, DateTime> vistos;

  bool visto(WrappedTipo tipo, int year) =>
      vistos.containsKey(AjustesWrapped.claveDe(tipo, year));
  bool avisado(WrappedTipo tipo, int year) =>
      avisados.containsKey(AjustesWrapped.claveDe(tipo, year));

  EstadoWrapped marcarAvisado(WrappedTipo tipo, int year, DateTime cuando) =>
      EstadoWrapped(
          avisados: {...avisados, AjustesWrapped.claveDe(tipo, year): cuando},
          vistos: vistos);

  EstadoWrapped marcarVisto(WrappedTipo tipo, int year, DateTime cuando) =>
      EstadoWrapped(
          avisados: avisados,
          vistos: {...vistos, AjustesWrapped.claveDe(tipo, year): cuando});

  factory EstadoWrapped.desdeJson(Map<String, dynamic> json) {
    Map<String, DateTime> fechas(String clave) => {
          for (final e in (json[clave] as Map? ?? const {}).entries)
            if (DateTime.tryParse('${e.value}') case final fecha?)
              '${e.key}': fecha
        };
    return EstadoWrapped(
        avisados: fechas('avisados'), vistos: fechas('vistos'));
  }

  Map<String, dynamic> toJson() => {
        'avisados': avisados.map((k, v) => MapEntry(k, v.toIso8601String())),
        'vistos': vistos.map((k, v) => MapEntry(k, v.toIso8601String())),
      };
}

/// Un Wrapped publicado que todavía no se ha visto.
class WrappedListo {
  const WrappedListo(this.tipo, this.year);
  final WrappedTipo tipo;
  final int year;

  @override
  bool operator ==(Object other) =>
      other is WrappedListo && other.tipo == tipo && other.year == year;
  @override
  int get hashCode => Object.hash(tipo, year);
  @override
  String toString() => AjustesWrapped.claveDe(tipo, year);
}

/// Cuántos días sigue avisando la app de un Wrapped sin ver.
const diasDeAvisoWrapped = 45;

/// Wrappeds publicados y sin ver en [ahora]; [conDatos] filtra los años vacíos.
List<WrappedListo> wrappedsListos({
  required DateTime ahora,
  required AjustesWrapped ajustes,
  required EstadoWrapped estado,
  required bool Function(WrappedTipo tipo, int year) conDatos,
}) {
  if (!ajustes.automatico) return const [];
  final listos = <WrappedListo>[];
  for (final tipo in WrappedTipo.values.where((t) => t.disponible)) {
    for (final year in [ahora.year, ahora.year - 1]) {
      final fecha = ajustes.publicacion(year);
      if (ahora.isBefore(fecha)) continue;
      if (ahora.difference(fecha).inDays > diasDeAvisoWrapped) continue;
      if (estado.visto(tipo, year)) continue;
      if (!conDatos(tipo, year)) continue;
      listos.add(WrappedListo(tipo, year));
    }
  }
  return listos;
}

/// Lee y guarda los archivos de `Documents/Todo/wrapped`.
class AlmacenWrapped {
  AlmacenWrapped({Directory? carpeta})
      : carpeta = carpeta ?? carpetaPorDefecto();

  final Directory carpeta;

  static Directory carpetaPorDefecto() {
    final inicio = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final s = Platform.pathSeparator;
    return Directory('$inicio${s}Documents${s}Todo${s}wrapped');
  }

  File get _ajustes =>
      File('${carpeta.path}${Platform.pathSeparator}ajustes.json');
  File get _estado =>
      File('${carpeta.path}${Platform.pathSeparator}estado.json');

  String get rutaAjustes => _ajustes.path;

  Map<String, dynamic>? _leer(File archivo) {
    try {
      if (!archivo.existsSync()) return null;
      final datos = jsonDecode(archivo.readAsStringSync());
      return datos is Map<String, dynamic> ? datos : null;
    } catch (_) {
      return null;
    }
  }

  void _escribir(File archivo, Map<String, dynamic> datos) {
    archivo.parent.createSync(recursive: true);
    final temporal = File('${archivo.path}.tmp');
    temporal.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(datos),
        flush: true);
    temporal.renameSync(archivo.path);
  }

  AjustesWrapped leerAjustes() {
    final datos = _leer(_ajustes);
    if (datos == null) {
      // Se crea con los valores por defecto para que sea fácil de editar.
      const porDefecto = AjustesWrapped();
      try {
        if (!_ajustes.existsSync()) _escribir(_ajustes, porDefecto.toJson());
      } catch (_) {}
      return porDefecto;
    }
    return AjustesWrapped.desdeJson(datos);
  }

  void guardarAjustes(AjustesWrapped ajustes) {
    // Se conservan las claves desconocidas que alguien haya añadido a mano.
    final previo = _leer(_ajustes) ?? {};
    final nuevo = ajustes.toJson();
    for (final clave in previo.keys.toList()) {
      final conocida = clave == 'automatico' ||
          clave == 'publicacion' ||
          WrappedTipo.desdeClave(clave.split('-').first) != null;
      if (conocida && !nuevo.containsKey(clave)) previo.remove(clave);
    }
    _escribir(_ajustes, {...previo, ...nuevo});
  }

  EstadoWrapped leerEstado() {
    final datos = _leer(_estado);
    return datos == null
        ? const EstadoWrapped()
        : EstadoWrapped.desdeJson(datos);
  }

  void guardarEstado(EstadoWrapped estado) =>
      _escribir(_estado, estado.toJson());

  /// Carpeta donde se descargan imágenes y vídeo de un Wrapped.
  static Directory carpetaDescargas(WrappedTipo tipo, int year) {
    final inicio = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final s = Platform.pathSeparator;
    final imagenes = Directory('$inicio${s}Pictures');
    final base =
        imagenes.existsSync() ? imagenes.path : '$inicio${s}Documents${s}Todo';
    return Directory('$base${s}Wrapped$s$year · ${tipo.nombre}');
  }
}

/// Normaliza un título para compararlo sin mayúsculas, tildes ni signos.
String normalizarTituloWrapped(String texto) {
  const tildes = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };
  final minus = texto.toLowerCase();
  final salida = StringBuffer();
  for (final rune in minus.runes) {
    final c = String.fromCharCode(rune);
    salida.write(tildes[c] ?? c);
  }
  return salida.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Banda sonora del catálogo propio del Wrapped (composiciones originales).
class PistaWrapped {
  const PistaWrapped(this.id, this.nombre, this.estilo, this.archivo);
  final String id;
  final String nombre;
  final String estilo;
  final String archivo;

  String get fuente => 'asset:assets/wrapped/musica/$archivo';
}

const pistasWrapped = [
  PistaWrapped('aurora', 'Aurora', 'Épica suave', 'aurora.mp3'),
  PistaWrapped('taberna', 'Taberna del bardo', 'Lofi medieval', 'taberna.mp3'),
  PistaWrapped('bardo', 'Nocturno del bardo', 'Lofi medieval con lluvia',
      'bardo.mp3'),
  PistaWrapped('cafe', 'Café y papel', 'Lofi jazz', 'cafe.mp3'),
  PistaWrapped('cronica', 'Crónica', 'Épica orquestal', 'cronica.mp3'),
  PistaWrapped('neon', 'Páginas de neón', 'Synthwave', 'neon.mp3'),
];

const pistaWrappedPorDefecto = 'aurora';

PistaWrapped? pistaWrapped(String? valor) {
  final clave = valor?.trim().toLowerCase();
  for (final pista in pistasWrapped) {
    if (pista.id == clave) return pista;
  }
  return null;
}

/// Fuente de audio para un valor de `musica`: una pista del catálogo, un
/// archivo propio o `null` si es `ninguna`. Sin valor, la pista por defecto.
String? fuenteMusicaWrapped(String? valor) {
  final v = valor?.trim();
  if (v == null || v.isEmpty) return pistaWrapped(pistaWrappedPorDefecto)!.fuente;
  if (v.toLowerCase() == 'ninguna') return null;
  return pistaWrapped(v)?.fuente ?? v;
}
