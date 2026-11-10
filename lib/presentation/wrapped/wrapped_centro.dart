import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/wrapped/resumen_libros.dart';
import '../../application/wrapped/wrapped_modelo.dart';
import '../../domain/models.dart';
import 'wrapped_libros.dart';
import 'wrapped_piezas.dart';
import 'wrapped_reproductor.dart';
import 'wrapped_video.dart';

/// Huella de los datos y ajustes de un Wrapped (sin la música), para saber
/// si un vídeo ya generado sigue valiendo. Incluye la fecha del ejecutable:
/// tras cada actualización de la app se vuelve a generar con el diseño nuevo.
String firmaBaseWrapped(
    WrappedTipo tipo,
    int year,
    List<LibraryItem> biblioteca,
    List<LibraryGoal> propositos,
    AjustesWrappedTipo ajustes) {
  String? ejecutable;
  try {
    ejecutable =
        File(Platform.resolvedExecutable).lastModifiedSync().toIso8601String();
  } catch (_) {}
  final sinMusica = Map.of(ajustes.toJson())..remove('musica');
  return VideosWrapped.firmaDe([
    tipo.clave,
    year,
    ejecutable,
    sinMusica,
    [
      for (final l in biblioteca)
        if (l.type == LibraryItemType.book)
          [
            l.id,
            l.updatedAt.toIso8601String(),
            l.status.name,
            l.completedDate?.toIso8601String(),
            l.rating,
            l.coverUrl,
            l.reading?.observedAt,
            l.reading?.statistics.values
                .fold<int>(0, (a, b) => a + b.observedAt),
            l.reading?.quotes.length,
          ]
    ],
    [
      for (final m in propositos)
        if (m.targetYear == year) [m.id, m.status.name, m.linkedLibraryItemId]
    ],
  ]);
}

/// Datos y diapositivas listos para reproducir o para generar el vídeo.
class WrappedPreparado {
  WrappedPreparado(
      this.resumen, this.diapositivas, this.ajustes, this.firmaBase);
  final ResumenLibros resumen;
  final List<DiapositivaWrapped> diapositivas;
  final AjustesWrappedTipo ajustes;
  final String firmaBase;

  int get segundos => ajustes.segundosPorDiapositiva ?? 7;
  Iterable<String?> get portadas => portadasDeLibros(resumen);
}

Future<WrappedPreparado> prepararWrapped(
    {required WrappedTipo tipo,
    required int year,
    required List<LibraryItem> biblioteca,
    required List<LibraryGoal> propositos,
    required AjustesWrapped ajustes}) async {
  final colecciones = await _cargarColecciones();
  final ajustesTipo = ajustes.para(tipo, year);
  final resumen = ResumenLibros.calcular(
    biblioteca: biblioteca,
    propositos: propositos,
    colecciones: colecciones,
    year: year,
    ajustes: ajustesTipo,
  );
  await ColoresPortada.precargar(portadasDeLibros(resumen));
  return WrappedPreparado(resumen, diapositivasLibros(resumen), ajustesTipo,
      firmaBaseWrapped(tipo, year, biblioteca, propositos, ajustesTipo));
}

/// Genera el vídeo de un Wrapped sin abrirlo, para que esté listo al pedirlo.
Future<void> prepararVideoEnSegundoPlano(
    {required WrappedTipo tipo,
    required int year,
    required List<LibraryItem> biblioteca,
    required List<LibraryGoal> propositos,
    required AlmacenWrapped almacen}) async {
  if (await buscarFfmpeg() == null) return;
  final ajustes = almacen.leerAjustes();
  final w = await prepararWrapped(
      tipo: tipo,
      year: year,
      biblioteca: biblioteca,
      propositos: propositos,
      ajustes: ajustes);
  final fuente = fuenteMusicaWrapped(w.ajustes.musica);
  final ruta = fuente == null ? null : await rutaDeAudio(fuente);
  VideosWrapped.preparar(
    clave: '${tipo.clave}-$year',
    firma: firmaVideoWrapped(
        w.firmaBase, ruta == null ? null : fuente, w.segundos, w.diapositivas),
    diapositivas: w.diapositivas,
    duraciones: duracionesWrapped(w.diapositivas, w.segundos),
    portadas: w.portadas,
    rutaMusica: ruta,
  );
}

List<Coleccion>? _colecciones;

Future<List<Coleccion>> _cargarColecciones() async {
  if (_colecciones != null) return _colecciones!;
  try {
    final texto =
        await rootBundle.loadString('assets/colecciones/colecciones.json');
    return _colecciones = Coleccion.desdeJson(texto);
  } catch (_) {
    return const [];
  }
}

/// ¿Tiene el año algo que contar? (libros terminados o lectura en el Kindle).
bool hayDatosWrapped(WrappedTipo tipo, int year, List<LibraryItem> biblioteca) {
  if (tipo != WrappedTipo.libros) return false;
  for (final l in biblioteca) {
    if (l.type != LibraryItemType.book) continue;
    if (l.status == LibraryItemStatus.completed &&
        l.completedDate?.year == year) {
      return true;
    }
    for (final s
        in l.reading?.statistics.values ?? const <BookReadingStatistics>[]) {
      if (s.periods.any((p) => p.seconds > 0 && p.localDate.year == year)) {
        return true;
      }
    }
  }
  return false;
}

/// Años con datos de libros, del más reciente al más antiguo.
List<int> anosConLibros(List<LibraryItem> biblioteca) {
  final anos = <int>{};
  for (final l in biblioteca) {
    if (l.type != LibraryItemType.book) continue;
    if (l.status == LibraryItemStatus.completed && l.completedDate != null) {
      anos.add(l.completedDate!.year);
    }
    for (final s
        in l.reading?.statistics.values ?? const <BookReadingStatistics>[]) {
      for (final p in s.periods) {
        if (p.seconds > 0) anos.add(p.localDate.year);
      }
    }
  }
  return anos.toList()..sort((a, b) => b.compareTo(a));
}

/// Abre el Wrapped a pantalla completa.
Future<void> abrirWrapped(
  BuildContext context, {
  required WrappedTipo tipo,
  required int year,
  required List<LibraryItem> Function() biblioteca,
  required List<LibraryGoal> Function() propositos,
  AlmacenWrapped? almacen,
}) {
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: true,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, _, __) => _PantallaWrapped(
      tipo: tipo,
      year: year,
      biblioteca: biblioteca,
      propositos: propositos,
      almacen: almacen ?? AlmacenWrapped(),
    ),
    transitionsBuilder: (context, animacion, _, hijo) => FadeTransition(
      opacity: animacion,
      child: ScaleTransition(
        scale: Tween(begin: 1.04, end: 1.0).animate(
            CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic)),
        child: hijo,
      ),
    ),
  ));
}

class _PantallaWrapped extends StatefulWidget {
  const _PantallaWrapped({
    required this.tipo,
    required this.year,
    required this.biblioteca,
    required this.propositos,
    required this.almacen,
  });
  final WrappedTipo tipo;
  final int year;
  final List<LibraryItem> Function() biblioteca;
  final List<LibraryGoal> Function() propositos;
  final AlmacenWrapped almacen;

  @override
  State<_PantallaWrapped> createState() => _PantallaWrappedState();
}

class _PantallaWrappedState extends State<_PantallaWrapped> {
  late AjustesWrapped _ajustes;
  ResumenLibros? _resumen;
  WrappedPreparado? _preparado;
  List<DiapositivaWrapped> _slides = const [];
  int _version = 0;
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _ajustes = widget.almacen.leerAjustes();
    unawaited(_calcular());
    final publicado =
        !DateTime.now().isBefore(_ajustes.publicacion(widget.year));
    if (publicado) {
      try {
        widget.almacen.guardarEstado(widget.almacen
            .leerEstado()
            .marcarVisto(widget.tipo, widget.year, DateTime.now()));
      } catch (_) {}
      avisosWrapped.value = avisosWrapped.value
          .where((w) => w != WrappedListo(widget.tipo, widget.year))
          .toList();
    }
  }

  Future<void> _calcular() async {
    final w = await prepararWrapped(
      tipo: widget.tipo,
      year: widget.year,
      biblioteca: widget.biblioteca(),
      propositos: widget.propositos(),
      ajustes: _ajustes,
    );
    if (!mounted) return;
    setState(() {
      _preparado = w;
      _resumen = w.resumen;
      _slides = w.diapositivas;
      _version++;
    });
  }

  /// Guarda la pista elegida en el reproductor sin reiniciarlo.
  void _guardarMusica(String valor) {
    final clave = AjustesWrapped.claveDe(widget.tipo, widget.year);
    final propio = _ajustes.porClave[clave] ?? const AjustesWrappedTipo();
    _ajustes = _ajustes.conTipo(
        widget.tipo, widget.year, propio.copiaCon(musica: valor));
    try {
      widget.almacen.guardarAjustes(_ajustes);
    } catch (_) {}
  }

  Future<void> _precargar(BuildContext context) async {
    final resumen = _resumen;
    if (resumen == null) return;
    await Future.wait([
      for (final fuente in portadasDeLibros(resumen))
        if (proveedorPortada(fuente) case final proveedor?)
          precacheImage(proveedor, context).catchError((Object _) {}),
    ]).timeout(const Duration(seconds: 8), onTimeout: () => const []);
  }

  String? get _vistaPrevia {
    final fecha = _ajustes.publicacion(widget.year);
    if (!DateTime.now().isBefore(fecha)) return null;
    return 'Vista previa. Tu Wrapped de ${widget.year} se publica el '
        '${fechaLarga(fecha)}${fecha.year != widget.year ? ' de ${fecha.year}' : ''}; '
        'hasta entonces se va completando con lo que leas.';
  }

  Future<void> _personalizar(int indice) async {
    final resumen = _resumen;
    if (resumen == null) return;
    _indice = indice;
    final nuevo = await showDialog<AjustesWrappedTipo>(
      context: context,
      builder: (_) => _PanelPersonalizar(
        year: widget.year,
        biblioteca: widget.biblioteca(),
        ajustes: _ajustes
                .porClave[AjustesWrapped.claveDe(widget.tipo, widget.year)] ??
            const AjustesWrappedTipo(),
        efectivos: _ajustes.para(widget.tipo, widget.year),
        resumen: resumen,
        rutaAjustes: widget.almacen.rutaAjustes,
      ),
    );
    if (nuevo == null || !mounted) return;
    _ajustes = _ajustes.conTipo(widget.tipo, widget.year, nuevo);
    try {
      widget.almacen.guardarAjustes(_ajustes);
    } catch (_) {}
    await _calcular();
  }

  @override
  Widget build(BuildContext context) {
    if (_resumen == null || _slides.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF050508),
        body: Center(
          child: SizedBox.square(
            dimension: 30,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          ),
        ),
      );
    }
    return ReproductorWrapped(
      key: ValueKey(_version),
      tipo: widget.tipo,
      year: widget.year,
      diapositivas: _slides,
      indiceInicial: _indice.clamp(0, _slides.length - 1),
      segundosPorDiapositiva:
          _ajustes.para(widget.tipo, widget.year).segundosPorDiapositiva ?? 7,
      musica: _ajustes.para(widget.tipo, widget.year).musica,
      onMusica: _guardarMusica,
      firmaVideo: _preparado?.firmaBase,
      portadas: _preparado?.portadas ?? const [],
      vistaPrevia: _vistaPrevia,
      precargar: _precargar,
      onPersonalizar: _personalizar,
    );
  }
}

// ---------------------------------------------------------------- personalizar

class _PanelPersonalizar extends StatefulWidget {
  const _PanelPersonalizar({
    required this.year,
    required this.biblioteca,
    required this.ajustes,
    required this.efectivos,
    required this.resumen,
    required this.rutaAjustes,
  });
  final int year;
  final List<LibraryItem> biblioteca;

  /// Ajustes propios del año (los que se guardan).
  final AjustesWrappedTipo ajustes;

  /// Ajustes que se aplican (año + generales), para mostrar el estado actual.
  final AjustesWrappedTipo efectivos;
  final ResumenLibros resumen;
  final String rutaAjustes;

  @override
  State<_PanelPersonalizar> createState() => _PanelPersonalizarState();
}

class _PanelPersonalizarState extends State<_PanelPersonalizar> {
  late String? _portada = widget.ajustes.portada;
  late String? _destacado = widget.ajustes.destacado;
  late String? _paleta = widget.ajustes.paleta;
  late String? _musica = widget.ajustes.musica;
  late final Set<String> _ocultar = widget.efectivos.ocultar.toSet();
  late final Set<String> _excluir = widget.efectivos.excluir.toSet();

  List<LibraryItem> get _delAno => [
        for (final l in widget.biblioteca)
          if (l.type == LibraryItemType.book &&
              l.status == LibraryItemStatus.completed &&
              l.completedDate?.year == widget.year)
            l,
      ]..sort((a, b) => b.completedDate!.compareTo(a.completedDate!));

  List<LibraryItem> get _elegibles {
    final ids = <String>{};
    return [
      for (final l in [
        ..._delAno,
        ...widget.resumen.porTiempo.map((e) => e.libro)
      ])
        if (ids.add(l.id)) l,
    ];
  }

  bool _excluido(LibraryItem l) =>
      _excluir.contains(l.id) ||
      _excluir
          .map(normalizarTituloWrapped)
          .contains(normalizarTituloWrapped(l.title));

  Widget _selectorLibro(String titulo, String? valor, String automatico,
      ValueChanged<String?> cambiar) {
    final elegibles = _elegibles;
    final actual = ResumenLibros.buscar(elegibles, valor);
    return Row(children: [
      SizedBox(width: 130, child: Text(titulo)),
      Expanded(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: actual?.id,
          items: [
            DropdownMenuItem(value: null, child: Text(automatico)),
            for (final l in elegibles)
              DropdownMenuItem(
                value: l.id,
                child: Text(l.title, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) => setState(() => cambiar(id == null
              ? null
              : elegibles.firstWhere((l) => l.id == id).title)),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final paletas = [
      'automatica',
      ...Paleta.porNombre.keys
          .where((k) => !k.contains('é') && !k.contains('í'))
    ];
    final sinMusica = _musica?.toLowerCase() == 'ninguna';
    return AlertDialog(
      title: Text('Personalizar el Wrapped de ${widget.year}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _selectorLibro('Portada', _portada, 'Automática (libro del año)',
                  (v) => _portada = v),
              _selectorLibro('Libro del año', _destacado,
                  'Automático (mejor nota y más horas)', (v) => _destacado = v),
              const SizedBox(height: 14),
              Text('Colores', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final p in paletas)
                  ChoiceChip(
                    label: Text(
                        p == 'automatica' ? 'De las portadas' : capitalizar(p)),
                    avatar: p == 'automatica'
                        ? null
                        : CircleAvatar(backgroundColor: Paleta.porNombre[p]!.a),
                    selected: (_paleta ?? 'automatica') == p,
                    onSelected: (_) =>
                        setState(() => _paleta = p == 'automatica' ? null : p),
                  ),
              ]),
              const SizedBox(height: 14),
              Text('Música', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final pista in pistasWrapped)
                      ChoiceChip(
                        label: Text('${pista.nombre} · ${pista.estilo}'),
                        selected: (pistaWrapped(_musica)?.id ??
                                (_musica == null
                                    ? pistaWrappedPorDefecto
                                    : null)) ==
                            pista.id,
                        onSelected: (_) => setState(() => _musica = pista.id),
                      ),
                    ChoiceChip(
                      label: Text(_musica != null &&
                              !sinMusica &&
                              pistaWrapped(_musica) == null
                          ? 'Propia: ${_musica!.split(RegExp(r'[\\/]')).last}'
                          : 'Elegir un mp3…'),
                      selected: _musica != null &&
                          !sinMusica &&
                          pistaWrapped(_musica) == null,
                      onSelected: (_) async {
                        final archivo =
                            await openFile(acceptedTypeGroups: const [
                          XTypeGroup(
                              label: 'Audio',
                              extensions: ['mp3', 'm4a', 'wav', 'ogg'])
                        ]);
                        if (archivo != null) {
                          setState(() => _musica = archivo.path);
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Sin música'),
                      selected: sinMusica,
                      onSelected: (_) => setState(() => _musica = 'ninguna'),
                    ),
                  ]),
              const SizedBox(height: 14),
              Text('Diapositivas',
                  style: Theme.of(context).textTheme.titleSmall),
              Wrap(spacing: 6, runSpacing: 2, children: [
                for (final e in diapositivasDeLibros.entries)
                  FilterChip(
                    label: Text(e.value),
                    selected: !_ocultar.contains(e.key),
                    onSelected: (v) => setState(
                        () => v ? _ocultar.remove(e.key) : _ocultar.add(e.key)),
                  ),
              ]),
              const SizedBox(height: 14),
              Text('Libros que cuentan',
                  style: Theme.of(context).textTheme.titleSmall),
              for (final l in _delAno)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: !_excluido(l),
                  title: Text(l.title),
                  onChanged: (v) => setState(() {
                    _excluir
                      ..remove(l.id)
                      ..removeWhere((x) =>
                          normalizarTituloWrapped(x) ==
                          normalizarTituloWrapped(l.title));
                    if (v == false) _excluir.add(l.title);
                  }),
                ),
              const SizedBox(height: 10),
              Text(
                'Se guarda solo para ${widget.year} en ${widget.rutaAjustes}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(AjustesWrappedTipo(
            portada: _portada,
            destacado: _destacado,
            paleta: _paleta,
            musica: _musica,
            ocultar: _ocultar.toList(),
            excluir: _excluir.toList(),
            titulo: widget.ajustes.titulo,
            nombre: widget.ajustes.nombre,
            mensajeFinal: widget.ajustes.mensajeFinal,
            cita: widget.ajustes.cita,
            segundosPorDiapositiva: widget.ajustes.segundosPorDiapositiva,
          )),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- centro

/// Ventana con los Wrapped disponibles, abierta desde Biblioteca.
Future<void> abrirCentroWrapped(
  BuildContext context, {
  required List<LibraryItem> Function() biblioteca,
  required List<LibraryGoal> Function() propositos,
}) {
  final almacen = AlmacenWrapped();
  final ajustes = almacen.leerAjustes();
  final anos = anosConLibros(biblioteca());
  final actual = DateTime.now().year;
  if (!anos.contains(actual)) anos.insert(0, actual);
  return showDialog<void>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('Wrapped'),
      content: SizedBox(
        width: 460,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu resumen del año se prepara solo el ${fechaLarga(ajustes.publicacion(actual))} '
                'y te aviso en cuanto esté listo.',
                style: Theme.of(dialogo).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              for (final tipo in WrappedTipo.values)
                for (final year in (tipo.disponible ? anos : [actual]))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FilaWrapped(
                      tipo: tipo,
                      year: year,
                      publicado:
                          !DateTime.now().isBefore(ajustes.publicacion(year)),
                      onAbrir: tipo.disponible
                          ? () {
                              Navigator.of(dialogo).pop();
                              unawaited(abrirWrapped(context,
                                  tipo: tipo,
                                  year: year,
                                  biblioteca: biblioteca,
                                  propositos: propositos,
                                  almacen: almacen));
                            }
                          : null,
                    ),
                  ),
            ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Cerrar')),
      ],
    ),
  );
}

class _FilaWrapped extends StatelessWidget {
  const _FilaWrapped(
      {required this.tipo,
      required this.year,
      required this.publicado,
      required this.onAbrir});
  final WrappedTipo tipo;
  final int year;
  final bool publicado;
  final VoidCallback? onAbrir;

  static const _colores = {
    WrappedTipo.libros: [Color(0xFF7C3AED), Color(0xFFDB2777)],
    WrappedTipo.general: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
    WrappedTipo.pantalla: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    WrappedTipo.juegos: [Color(0xFF10B981), Color(0xFF0EA5E9)],
  };

  static const _iconos = {
    WrappedTipo.libros: Icons.auto_stories_rounded,
    WrappedTipo.general: Icons.collections_bookmark_rounded,
    WrappedTipo.pantalla: Icons.movie_rounded,
    WrappedTipo.juegos: Icons.sports_esports_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final disponible = onAbrir != null;
    return Opacity(
      opacity: disponible ? 1 : .5,
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _colores[tipo]!),
          ),
          child: InkWell(
            onTap: onAbrir,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Icon(_iconos[tipo], color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            disponible ? '${tipo.titulo} · $year' : tipo.titulo,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        Text(
                            !disponible
                                ? 'Próximamente'
                                : (publicado
                                    ? 'Listo para ver'
                                    : 'Vista previa, aún en curso'),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ]),
                ),
                if (disponible)
                  const Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 30),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- avisos

/// Wrapped listos y sin ver; el aviso flotante los muestra.
final avisosWrapped = ValueNotifier<List<WrappedListo>>(const []);

/// Comprueba cada cierto tiempo si toca publicar un Wrapped y lo anuncia
/// dentro de la app (y una vez con una notificación de Windows).
class AvisoWrapped extends StatefulWidget {
  const AvisoWrapped({
    required this.biblioteca,
    required this.propositos,
    this.notificarSistema,
    this.almacen,
    this.reloj,
    super.key,
  });
  final List<LibraryItem> Function() biblioteca;
  final List<LibraryGoal> Function() propositos;
  final Future<void> Function(String titulo, String cuerpo)? notificarSistema;
  final AlmacenWrapped? almacen;
  final DateTime Function()? reloj;

  @override
  State<AvisoWrapped> createState() => _AvisoWrappedState();
}

class _AvisoWrappedState extends State<AvisoWrapped> {
  Timer? _temporizador;
  late final AlmacenWrapped _almacen = widget.almacen ?? AlmacenWrapped();
  final Set<WrappedListo> _descartados = {};

  @override
  void initState() {
    super.initState();
    avisosWrapped.addListener(_cambio);
    // Se espera a que la app termine de arrancar.
    _temporizador = Timer(const Duration(seconds: 6), () {
      _comprobar();
      _temporizador =
          Timer.periodic(const Duration(minutes: 20), (_) => _comprobar());
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    avisosWrapped.removeListener(_cambio);
    super.dispose();
  }

  void _cambio() {
    if (mounted) setState(() {});
  }

  void _comprobar() {
    try {
      final ahora = (widget.reloj ?? DateTime.now)();
      final ajustes = _almacen.leerAjustes();
      var estado = _almacen.leerEstado();
      final biblioteca = widget.biblioteca();
      final listos = wrappedsListos(
        ahora: ahora,
        ajustes: ajustes,
        estado: estado,
        conDatos: (tipo, year) => hayDatosWrapped(tipo, year, biblioteca),
      );
      for (final w in listos) {
        unawaited(prepararVideoEnSegundoPlano(
                tipo: w.tipo,
                year: w.year,
                biblioteca: biblioteca,
                propositos: widget.propositos(),
                almacen: _almacen)
            .catchError((Object _) {}));
        if (estado.avisado(w.tipo, w.year)) continue;
        estado = estado.marcarAvisado(w.tipo, w.year, ahora);
        unawaited(widget.notificarSistema?.call(
                '✨ Tu Wrapped ${w.year} ya está listo',
                '${w.tipo.titulo}: ábrelo en Todo para verlo con música y descargarlo.') ??
            Future<void>.value());
      }
      _almacen.guardarEstado(estado);
      avisosWrapped.value = listos;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final visibles =
        avisosWrapped.value.where((w) => !_descartados.contains(w)).toList();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (hijo, animacion) => SlideTransition(
        position: Tween(begin: const Offset(0, .4), end: Offset.zero).animate(
            CurvedAnimation(parent: animacion, curve: Curves.easeOutBack)),
        child: FadeTransition(opacity: animacion, child: hijo),
      ),
      child: visibles.isEmpty
          ? const SizedBox.shrink()
          : _TarjetaAviso(
              key: ValueKey(visibles.first),
              listo: visibles.first,
              biblioteca: widget.biblioteca,
              onVer: () {
                final w = visibles.first;
                unawaited(abrirWrapped(context,
                    tipo: w.tipo,
                    year: w.year,
                    biblioteca: widget.biblioteca,
                    propositos: widget.propositos,
                    almacen: _almacen));
              },
              onLuego: () => setState(() => _descartados.add(visibles.first)),
            ),
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({
    required this.listo,
    required this.biblioteca,
    required this.onVer,
    required this.onLuego,
    super.key,
  });
  final WrappedListo listo;
  final List<LibraryItem> Function() biblioteca;
  final VoidCallback onVer;
  final VoidCallback onLuego;

  @override
  Widget build(BuildContext context) {
    final portadas = [
      for (final l in biblioteca())
        if (l.type == LibraryItemType.book &&
            l.status == LibraryItemStatus.completed &&
            l.completedDate?.year == listo.year &&
            (l.coverUrl ?? '').isNotEmpty)
          l,
    ]..sort((a, b) => b.completedDate!.compareTo(a.completedDate!));
    return Container(
      width: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4C1D95), Color(0xFFBE185D)],
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 14)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
          child: Row(children: [
            SizedBox(
              width: 74,
              height: 76,
              child: Stack(children: [
                for (final (i, libro)
                    in portadas.take(3).toList().reversed.indexed)
                  Positioned(
                    left: i * 14.0,
                    top: i * 3.0,
                    child: Transform.rotate(
                      angle: (i - 1) * .12,
                      child: Portada(
                          fuente: libro.coverUrl,
                          titulo: libro.title,
                          ancho: 46,
                          alto: 69,
                          radio: 3),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TU WRAPPED ESTÁ LISTO',
                        style: TipografiaWrapped.etiqueta(
                            size: 9.5, color: Colors.white70)),
                    const SizedBox(height: 3),
                    Text('${listo.tipo.titulo} · ${listo.year}',
                        style: TipografiaWrapped.titular(
                            size: 21, spacing: -.6, height: 1.05)),
                    const SizedBox(height: 8),
                    Row(children: [
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: onVer,
                        child: const Text('Verlo ahora'),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            visualDensity: VisualDensity.compact),
                        onPressed: onLuego,
                        child: const Text('Más tarde'),
                      ),
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }
}
