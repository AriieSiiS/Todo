part of 'app_shell.dart';

const _rutaCatalogoColecciones = 'assets/colecciones/colecciones.json';

List<Coleccion>? _colecciones;

Future<void> _cargarColecciones() async {
  _colecciones ??= Coleccion.desdeJson(
    await rootBundle.loadString(_rutaCatalogoColecciones),
  );
}

/// Colección de una saga o universo de la Biblioteca, si está en el catálogo.
Coleccion? _coleccionPorNombre(String nombre) {
  final buscado = nombre.paraBuscar;
  for (final coleccion in _colecciones ?? const <Coleccion>[]) {
    if (coleccion.nombres.any((otro) => otro.paraBuscar == buscado)) {
      return coleccion;
    }
  }
  return null;
}

/// Clave de una obra para quitarla, ordenarla o editarla: la de su colección
/// de origen, para que sea la misma aunque se vea dentro de otra colección.
String _claveObra(Coleccion coleccion, LibraryItem obra) =>
    obra.catalogKeys.firstOrNull ?? '${coleccion.id}/${obra.id}';

/// Una colección deja de existir cuando le quedan menos de dos obras sin
/// quitar: ya no es una saga.
bool _coleccionVigente(TodoWorkspace controller, Coleccion coleccion) {
  final quitadas = controller.visibilitySettings.hiddenCollectionWorks;
  if (quitadas.contains(_claveBorrada(coleccion))) return false;
  return coleccion.obras
          .where((obra) => !quitadas.contains(_claveObra(coleccion, obra)))
          .length >=
      2;
}

/// Marca de una colección borrada a mano, guardada junto a las obras quitadas.
String _claveBorrada(Coleccion coleccion) => '${coleccion.id}/borrada';

/// Pide confirmación y borra la colección: desaparece de la pestaña y sus
/// fichas de Biblioteca pierden esa saga o ese universo.
Future<void> _borrarColeccion(
  BuildContext context,
  TodoWorkspace controller,
  Coleccion coleccion,
) async {
  final nombres = {for (final n in coleccion.nombres) n.toLowerCase()};
  final fichas = controller.libraryItems
      .where((item) =>
          nombres.contains((item.collectionName ?? '').toLowerCase()) ||
          nombres.contains((item.universeName ?? '').toLowerCase()))
      .length;
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Borrar la colección «${coleccion.nombre}»'),
      content: Text(fichas == 0
          ? 'Desaparecerá de la pestaña Colecciones.'
          : 'Desaparecerá de la pestaña Colecciones y $fichas '
              '${fichas == 1 ? 'ficha perderá' : 'fichas perderán'} '
              'esa saga o ese universo.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const ValueKey('coleccion-borrar-aceptar'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  if (confirmado != true) return;
  controller.setCollectionWorkHidden(_claveBorrada(coleccion), true);
  _disolverColeccionesSinObras(controller);
}

/// Quita la saga o el universo de las fichas de Biblioteca que apuntaban a
/// colecciones que se han quedado vacías o con una sola obra.
void _disolverColeccionesSinObras(TodoWorkspace controller) {
  final nombres = [
    for (final coleccion in _colecciones ?? const <Coleccion>[])
      if (!_coleccionVigente(controller, coleccion)) ...coleccion.nombres,
  ];
  if (nombres.isNotEmpty) controller.dissolveLibraryCollections(nombres);
}

/// Fecha prevista de salida de una obra que aún no ha salido; vacía si no se
/// conoce y nula si la obra ya está publicada.
String? _fechaPrevista(LibraryItem obra) {
  for (final coleccion in _colecciones ?? const <Coleccion>[]) {
    if (coleccion.fechasPrevistas.containsKey(obra.id) &&
        coleccion.obras.any((otra) => otra.id == obra.id)) {
      return coleccion.fechasPrevistas[obra.id];
    }
  }
  return null;
}

/// Elemento de la Biblioteca que corresponde a una obra del catálogo, si existe.
LibraryItem? _obraEnBiblioteca(TodoWorkspace controller, LibraryItem obra) {
  // Todos los tomos de un manga comparten la ficha de la serie.
  if (_esTomo(obra)) {
    final serie = obra.collectionName!.paraBuscar;
    for (final item in controller.libraryItems) {
      if (item.type == LibraryItemType.book &&
          (item.title.paraBuscar == serie ||
              item.collectionName?.paraBuscar == serie)) {
        return item;
      }
    }
    return null;
  }
  // Las fichas enlazadas se reconocen por el identificador de la obra, así
  // que da igual que se cambie su título.
  final clave = obra.catalogKeys.firstOrNull;
  if (clave != null) {
    for (final item in controller.libraryItems) {
      if (item.catalogKeys.contains(clave)) return item;
    }
  }
  // Las fichas sin enlazar, solo por tipo y título.
  final titulo = obra.title.paraBuscar;
  for (final item in controller.libraryItems) {
    if (item.catalogKeys.isEmpty &&
        item.type == obra.type &&
        item.title.paraBuscar == titulo) {
      return item;
    }
  }
  return null;
}

/// Identificadores de todas las obras del catálogo con el mismo tipo y título
/// que [item] (una película puede estar en su saga y en la de su director).
List<String> _clavesPorTitulo(LibraryItem item) {
  final titulo = item.title.paraBuscar;
  return [
    for (final coleccion in _colecciones ?? const <Coleccion>[])
      for (final obra in coleccion.obras)
        if (!_esTomo(obra) &&
            obra.type == item.type &&
            obra.title.paraBuscar == titulo)
          ...obra.catalogKeys,
  ];
}

/// Enlaza una sola vez las fichas de la Biblioteca que aún no tienen enlace
/// con sus obras del catálogo, emparejándolas por tipo y título.
void _enlazarBibliotecaConCatalogo(TodoWorkspace controller) {
  if (_colecciones == null) return;
  final enlaces = <String, List<String>>{
    for (final item in controller.libraryItems)
      if (item.catalogKeys.isEmpty) item.id: _clavesPorTitulo(item),
  }..removeWhere((_, claves) => claves.isEmpty);
  if (enlaces.isNotEmpty) controller.linkLibraryItemsToCatalog(enlaces);
}

/// Tomo de un manga del catálogo. Sus tomos no son obras distintas: se
/// guardan como tomos leídos de una única ficha de la serie.
bool _esTomo(LibraryItem obra) =>
    obra.type == LibraryItemType.book &&
    obra.creatorOrDirector == 'Manga' &&
    obra.collectionNumber != null &&
    obra.collectionName != null;

/// Tomos del catálogo de la misma serie que [obra].
List<LibraryItem> _tomosDe(LibraryItem obra) => [
      for (final coleccion in _colecciones ?? const <Coleccion>[])
        for (final otra in coleccion.obras)
          if (_esTomo(otra) && otra.collectionName == obra.collectionName) otra,
    ];

/// Estado de una obra en la Biblioteca. En un tomo es el suyo propio:
/// leído, leyéndose o, si es nulo, sin leer.
LibraryItemStatus? _estadoObra(TodoWorkspace controller, LibraryItem obra) {
  final item = _obraEnBiblioteca(controller, obra);
  if (item == null || !_esTomo(obra)) return item?.status;
  final tomo = obra.collectionNumber!;
  if (item.readVolumes.contains(tomo)) return LibraryItemStatus.completed;
  if (item.currentVolume == tomo) return LibraryItemStatus.inProgress;
  return null;
}

/// Marca un tomo como leído, leyéndose o sin leer (pendiente) y ajusta el
/// estado de la serie: pendiente sin nada leído, completada si se han leído
/// todos los tomos de una serie terminada y en curso en los demás casos. La
/// portada de la ficha pasa a ser la del tomo por el que se va leyendo.
Future<void> _ponerEstadoTomo(
  TodoWorkspace controller,
  LibraryItem obra,
  LibraryItemStatus estado,
) async {
  final item = _obraEnBiblioteca(controller, obra);
  if (item == null) return;
  final tomo = obra.collectionNumber!;
  final leidos = {...item.readVolumes};
  var actual = item.currentVolume;
  switch (estado) {
    case LibraryItemStatus.completed:
      leidos.add(tomo);
      if (actual == tomo) actual = null;
    case LibraryItemStatus.inProgress:
      leidos.remove(tomo);
      actual = tomo;
    case LibraryItemStatus.pending:
      leidos.remove(tomo);
      if (actual == tomo) actual = null;
  }
  final tomos = _tomosDe(obra);
  final total = tomos.length;
  // El tomo que se está leyendo; si no hay, el siguiente al último leído, o
  // el último si ya están todos.
  final ultimo = leidos.isEmpty ? null : leidos.reduce(max);
  final porLeer = actual ??
      (ultimo == null
          ? null
          : tomos.any((t) => t.collectionNumber == ultimo + 1)
              ? ultimo + 1
              : ultimo);
  final tomoPortada =
      tomos.where((t) => t.collectionNumber == porLeer).firstOrNull;
  final portada =
      tomoPortada == null ? null : await _portadaDeTomo(tomoPortada);
  final status = leidos.isEmpty && actual == null
      ? LibraryItemStatus.pending
      : leidos.length >= total &&
              actual == null &&
              item.publicationStatus == LibraryPublicationStatus.finished
          ? LibraryItemStatus.completed
          : LibraryItemStatus.inProgress;
  // Se vuelve a leer la ficha: mientras se copiaba la portada pudo cambiar.
  final vigente = _obraEnBiblioteca(controller, obra) ?? item;
  controller.updateLibraryItem(vigente.copyWith(
    status: status,
    coverUrl: portada,
    readVolumes: leidos.toList()..sort(),
    currentVolume: actual,
    clearCurrentVolume: actual == null,
  ));
}

/// Bytes de una portada del catálogo, o de un archivo si la portada se cambió
/// a mano.
Future<Uint8List> _bytesPortada(String ruta) async {
  if (ruta.startsWith('assets/')) {
    return (await rootBundle.load(ruta)).buffer.asUint8List();
  }
  return File(ruta).readAsBytes();
}

/// Imagen de una portada del catálogo o de un archivo elegido a mano.
ImageProvider _imagenPortada(String ruta) => ruta.startsWith('assets/')
    ? AssetImage(ruta) as ImageProvider
    : FileImage(File(ruta));

/// Obra del catálogo con los cambios que el usuario le haya hecho.
LibraryItem _obraEditada(
  TodoWorkspace controller,
  Coleccion coleccion,
  LibraryItem obra,
) {
  final cambios = controller
      .visibilitySettings.collectionWorkEdits[_claveObra(coleccion, obra)];
  if (cambios == null) return obra;
  return LibraryItem.fromJson({
    ...obra.toJson(),
    ...cambios,
    'id': obra.id,
    'status': obra.status.name,
  });
}

/// Colección con los cambios propios aplicados a sus obras.
Coleccion _coleccionEditada(TodoWorkspace controller, Coleccion coleccion) {
  final ediciones = controller.visibilitySettings.collectionWorkEdits;
  if (!coleccion.obras
      .any((obra) => ediciones.containsKey(_claveObra(coleccion, obra)))) {
    return coleccion;
  }
  return Coleccion(
    id: coleccion.id,
    nombre: coleccion.nombre,
    alias: coleccion.alias,
    fondo: coleccion.fondo,
    fechasPrevistas: coleccion.fechasPrevistas,
    grupos: [
      for (final grupo in coleccion.grupos)
        GrupoColeccion(
          nombre: grupo.nombre,
          obras: [
            for (final obra in grupo.obras)
              _obraEditada(controller, coleccion, obra),
          ],
        ),
    ],
  );
}

/// Abre el editor de Biblioteca sobre una obra del catálogo y guarda el
/// resultado como cambios propios de esa obra.
Future<void> _editarObraColeccion(
  BuildContext context,
  TodoWorkspace controller,
  String coleccionId,
  LibraryItem obra,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => _LibraryItemDialog(
      controller: controller,
      item: obra,
      initialType: obra.type,
      onCatalogSave: (editada) {
        final campos = editada.toJson()
          ..remove('id')
          ..remove('status')
          ..remove('completedDate')
          ..remove('yearGroup')
          ..remove('createdAt')
          ..remove('updatedAt');
        controller.setCollectionWorkEdit(
          obra.catalogKeys.firstOrNull ?? '$coleccionId/${obra.id}',
          campos,
        );
      },
    ),
  );
}

/// Copia la portada de un tomo a las portadas de la Biblioteca una sola vez y
/// devuelve su ruta.
Future<String?> _portadaDeTomo(LibraryItem tomo) async {
  final origen = tomo.coverUrl;
  if (origen == null) return null;
  if (!origen.startsWith('assets/')) return origen;
  try {
    final directorio = await _libraryCoversDirectory();
    final destino = File('${directorio.path}${Platform.pathSeparator}'
        'cover_tomo_${tomo.collectionName!.paraBuscar.replaceAll(RegExp(r'[^a-z0-9]+'), '-')}'
        '_${tomo.collectionNumber}.jpg');
    if (!await destino.exists()) {
      final datos = await rootBundle.load(origen);
      await destino.writeAsBytes(datos.buffer.asUint8List(), flush: true);
    }
    return destino.path;
  } on Exception {
    return null;
  }
}

/// Crea la ficha de la serie de un manga a partir de su primer tomo.
Future<void> _anadirSerieABiblioteca(
  TodoWorkspace controller,
  LibraryItem tomo,
) async {
  final tomos = _tomosDe(tomo)
    ..sort((a, b) => a.collectionNumber!.compareTo(b.collectionNumber!));
  final primero = tomos.isEmpty ? tomo : tomos.first;
  final coverUrl =
      await _copyLibraryCoverBytes(await _bytesPortada(primero.coverUrl!));
  if (_obraEnBiblioteca(controller, tomo) != null) return;
  // La sinopsis del primer tomo sin la línea que describe la edición.
  final nota = primero.note
      ?.replaceAll(RegExp(r'\s*Tomo 1 de la edición[^.]*\.'), '')
      .trim();
  controller.createLibraryItem(
    type: LibraryItemType.book,
    title: tomo.collectionName!,
    status: LibraryItemStatus.pending,
    coverUrl: coverUrl,
    externalUrl: primero.externalUrl,
    note: nota,
    author: primero.author,
    releaseYear: primero.releaseYear,
    creatorOrDirector: 'Manga',
    genre: primero.genre,
    universeName: primero.universeName,
    collectionName: tomo.collectionName,
    publicationStatus: LibraryPublicationStatus.ongoing,
  );
}

/// Copia la portada del catálogo y crea el elemento como pendiente.
Future<void> _anadirObraABiblioteca(
  TodoWorkspace controller,
  LibraryItem obra, {
  LibraryItemStatus status = LibraryItemStatus.pending,
}) async {
  if (_esTomo(obra)) return _anadirSerieABiblioteca(controller, obra);
  final coverUrl =
      await _copyLibraryCoverBytes(await _bytesPortada(obra.coverUrl!));
  if (_obraEnBiblioteca(controller, obra) != null) return;
  final creado = controller.createLibraryItem(
    type: obra.type,
    title: obra.title,
    status: status,
    coverUrl: coverUrl,
    externalUrl: obra.externalUrl,
    note: obra.note,
    platform: obra.platform,
    developer: obra.developer,
    author: obra.author,
    mediaType: obra.mediaType,
    releaseYear: obra.releaseYear,
    creatorOrDirector: obra.creatorOrDirector,
    genre: obra.genre,
    format: obra.format,
    duration: obra.duration,
    pages: obra.pages,
    country: obra.country,
    universeName: obra.universeName,
    collectionName: obra.collectionName,
    collectionNumber: obra.collectionNumber,
    showCollectionNumber: obra.showCollectionNumber,
    seasonCount: obra.seasonCount,
  );
  controller.linkLibraryItemsToCatalog({
    creado.id: {...obra.catalogKeys, ..._clavesPorTitulo(obra)}.toList(),
  });
}

/// Añade una obra del catálogo a la Biblioteca con ese estado, o cambia su
/// estado si ya estaba.
Future<void> _ponerEstadoObra(
  TodoWorkspace controller,
  LibraryItem obra,
  LibraryItemStatus estado,
) async {
  if (_esTomo(obra)) {
    if (_obraEnBiblioteca(controller, obra) == null) {
      await _anadirSerieABiblioteca(controller, obra);
    }
    await _ponerEstadoTomo(controller, obra, estado);
    return;
  }
  final existente = _obraEnBiblioteca(controller, obra);
  if (existente != null) {
    controller.updateLibraryItemStatus(existente.id, estado);
  } else {
    await _anadirObraABiblioteca(controller, obra, status: estado);
  }
}

String _estadoEnPlural(LibraryItemStatus estado, {bool tomos = false}) =>
    switch (estado) {
      LibraryItemStatus.pending => tomos ? 'sin leer' : 'pendientes',
      LibraryItemStatus.inProgress => tomos ? 'leyendo' : 'en curso',
      LibraryItemStatus.completed => tomos ? 'leídos' : 'completadas',
    };

/// Nombre del estado de un tomo de manga.
String _estadoTomo(LibraryItemStatus? estado) => switch (estado) {
      LibraryItemStatus.completed => 'Leído',
      LibraryItemStatus.inProgress => 'Leyendo',
      _ => 'Sin leer',
    };

/// Abre la saga sobre la vista actual, desde la pestaña Colecciones o desde la
/// chapa de saga o universo de una ficha.
Future<void> _abrirColeccion(
  BuildContext context,
  TodoWorkspace controller,
  Coleccion coleccion,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: _FondoColeccion(coleccion: coleccion)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => _ColeccionDetalle(
                controller: controller,
                coleccion: coleccion,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Fondo de la vista de una colección: una imagen de la saga a la derecha,
/// desvaída y fundida con el color del diálogo para no restar protagonismo a
/// las portadas. Sin imagen propia, se usa la portada de la primera obra
/// desenfocada.
class _FondoColeccion extends StatelessWidget {
  const _FondoColeccion({required this.coleccion});

  final Coleccion coleccion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final base = tema.dialogTheme.backgroundColor ??
        tema.colorScheme.surfaceContainerHigh;
    final oscuro = tema.brightness == Brightness.dark;
    final fondo = coleccion.fondo;
    final portada = coleccion.obras.isEmpty ? null : coleccion.obras.first;
    Widget? imagen;
    if (fondo != null) {
      imagen =
          Image.asset(fondo, fit: BoxFit.cover, alignment: Alignment.center);
    } else if (portada?.coverUrl != null) {
      imagen = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Image(
          image: _imagenPortada(portada!.coverUrl!),
          fit: BoxFit.cover,
        ),
      );
    }
    if (imagen == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.72,
              heightFactor: 1,
              child: Opacity(
                opacity: fondo != null
                    ? (oscuro ? 0.42 : 0.5)
                    : (oscuro ? 0.28 : 0.32),
                child: imagen,
              ),
            ),
          ),
          // Funde la imagen con el diálogo hacia la izquierda y la aclara u
          // oscurece para que los textos y las portadas se lean bien.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  base,
                  base,
                  base.withValues(alpha: oscuro ? 0.55 : 0.5),
                  base.withValues(alpha: oscuro ? 0.25 : 0.3),
                ],
                stops: const [0, 0.28, 0.62, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  base.withValues(alpha: 0.35),
                  base.withValues(alpha: 0),
                  base.withValues(alpha: 0.25),
                ],
                stops: const [0, 0.35, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColeccionDetalle extends StatefulWidget {
  const _ColeccionDetalle({required this.controller, required this.coleccion});

  final TodoWorkspace controller;
  final Coleccion coleccion;

  @override
  State<_ColeccionDetalle> createState() => _ColeccionDetalleState();
}

class _ColeccionDetalleState extends State<_ColeccionDetalle> {
  final _anadiendo = <String>{};
  bool _verQuitadas = false;
  bool _seleccionando = false;
  final _seleccion = <String>{};
  bool _porAnio = false;
  bool _ocultarTengo = false;

  TodoWorkspace get controller => widget.controller;

  String _clave(LibraryItem obra) => _claveObra(widget.coleccion, obra);

  bool _quitada(LibraryItem obra) =>
      controller.visibilitySettings.hiddenCollectionWorks
          .contains(_clave(obra));

  void _alternar(LibraryItem obra) {
    controller.setCollectionWorkHidden(_clave(obra), !_quitada(obra));
    // Con menos de dos obras la colección desaparece, también de las fichas.
    if (!_coleccionVigente(controller, widget.coleccion)) {
      _disolverColeccionesSinObras(controller);
      Navigator.of(context).maybePop();
    }
  }

  /// Los apartados plegados se guardan junto a las obras quitadas, con su
  /// propia clave, para conservarlos al reiniciar.
  String _claveGrupo(GrupoColeccion grupo) =>
      '${widget.coleccion.id}/grupo:${grupo.nombre}';

  String _claveOrden(GrupoColeccion grupo) =>
      '${widget.coleccion.id}/orden:${grupo.nombre}';

  /// Orden elegido a mano para el apartado, si lo hay.
  List<String>? _ordenGuardado(GrupoColeccion grupo) {
    final prefijo = '${_claveOrden(grupo)}=';
    for (final entrada in controller.visibilitySettings.hiddenCollectionWorks) {
      if (entrada.startsWith(prefijo)) {
        return entrada.substring(prefijo.length).split('|');
      }
    }
    return null;
  }

  /// Obras del apartado en el orden elegido a mano; las que no aparecen en
  /// él (por ejemplo, obras nuevas del catálogo) siguen al final.
  List<LibraryItem> _ordenado(GrupoColeccion grupo) {
    final orden = _ordenGuardado(grupo);
    if (orden == null) return grupo.obras;
    final posicion = {for (var i = 0; i < orden.length; i++) orden[i]: i};
    final indices = {
      for (var i = 0; i < grupo.obras.length; i++) grupo.obras[i].id: i
    };
    return [...grupo.obras]..sort((a, b) {
        final pa = posicion[a.id] ?? orden.length + indices[a.id]!;
        final pb = posicion[b.id] ?? orden.length + indices[b.id]!;
        return pa.compareTo(pb);
      });
  }

  /// Coloca [arrastrada] en el sitio de [destino] dentro de su apartado.
  // Arrastre de portadas: mientras se arrastra, el apartado se dibuja ya con
  // el orden que quedaría, y la portada arrastrada deja un hueco en su sitio.
  String? _grupoArrastre;
  LibraryItem? _obraArrastrada;
  int? _destinoArrastre;

  // Arrastre de apartados, con la misma vista previa.
  String? _apartadoArrastrado;
  int? _destinoApartado;

  String get _claveOrdenApartados => '${widget.coleccion.id}/orden-apartados';

  List<String>? get _ordenApartados {
    final prefijo = '$_claveOrdenApartados=';
    for (final entrada in controller.visibilitySettings.hiddenCollectionWorks) {
      if (entrada.startsWith(prefijo)) {
        return entrada.substring(prefijo.length).split('|');
      }
    }
    return null;
  }

  /// Apartados en el orden elegido a mano, con la vista previa del arrastre.
  List<GrupoColeccion> _apartadosOrdenados(List<GrupoColeccion> grupos) {
    final orden = _ordenApartados;
    var lista = [...grupos];
    if (orden != null) {
      final posicion = {for (var i = 0; i < orden.length; i++) orden[i]: i};
      final original = {
        for (var i = 0; i < grupos.length; i++) grupos[i].nombre: i
      };
      lista.sort((a, b) {
        final pa = posicion[a.nombre] ?? orden.length + original[a.nombre]!;
        final pb = posicion[b.nombre] ?? orden.length + original[b.nombre]!;
        return pa.compareTo(pb);
      });
    }
    final movido = _apartadoArrastrado;
    final destino = _destinoApartado;
    if (movido != null && destino != null) {
      final grupo = lista.where((g) => g.nombre == movido).firstOrNull;
      if (grupo != null) {
        lista = [...lista]..remove(grupo);
        lista.insert(destino.clamp(0, lista.length), grupo);
      }
    }
    return lista;
  }

  void _terminarArrastreApartado() {
    if (_apartadoArrastrado == null) return;
    setState(() {
      _apartadoArrastrado = null;
      _destinoApartado = null;
    });
  }

  void _soltarApartado(List<GrupoColeccion> vista) {
    final visibles = vista.map((g) => g.nombre).toList();
    _terminarArrastreApartado();
    final todos = _apartadosOrdenados(widget.coleccion.grupos)
        .map((g) => g.nombre)
        .toList();
    // Los apartados ocultos por los filtros conservan su sitio al final.
    final resto = todos.where((n) => !visibles.contains(n));
    controller
        .setCollectionGroupOrder(_claveOrdenApartados, [...visibles, ...resto]);
  }

  List<LibraryItem> _vistaPrevia(GrupoColeccion grupo) {
    final arrastrada = _obraArrastrada;
    final destino = _destinoArrastre;
    if (_grupoArrastre != grupo.nombre ||
        arrastrada == null ||
        destino == null) {
      return grupo.obras;
    }
    final lista = [...grupo.obras]
      ..removeWhere((obra) => identical(obra, arrastrada));
    lista.insert(destino.clamp(0, lista.length), arrastrada);
    return lista;
  }

  void _terminarArrastre() {
    if (_obraArrastrada == null && _grupoArrastre == null) return;
    setState(() {
      _grupoArrastre = null;
      _obraArrastrada = null;
      _destinoArrastre = null;
    });
  }

  /// Guarda el orden que mostraba la vista previa al soltar la portada.
  void _soltar(String nombreGrupo, List<LibraryItem> vista) {
    final arrastrada = _obraArrastrada;
    _terminarArrastre();
    final grupo = widget.coleccion.grupos
        .where((g) => g.nombre == nombreGrupo)
        .firstOrNull;
    if (grupo == null || arrastrada == null) return;
    final i = vista.indexWhere((obra) => identical(obra, arrastrada));
    final ids = _ordenado(grupo).map((obra) => obra.id).toList()
      ..remove(arrastrada.id);
    if (i + 1 < vista.length) {
      ids.insert(ids.indexOf(vista[i + 1].id), arrastrada.id);
    } else if (i > 0) {
      ids.insert(ids.indexOf(vista[i - 1].id) + 1, arrastrada.id);
    } else {
      ids.insert(0, arrastrada.id);
    }
    controller.setCollectionGroupOrder(_claveOrden(grupo), ids);
  }

  /// Portada que se arrastra dentro de su apartado. Al pasar sobre otra, las
  /// demás se apartan para mostrar dónde quedará.
  Widget _portadaArrastrable({
    required GrupoColeccion grupo,
    required LibraryItem obra,
    required int index,
    required List<LibraryItem> vista,
    required Widget tarjeta,
  }) {
    final esLaArrastrada = identical(obra, _obraArrastrada);
    return LayoutBuilder(
      key: ValueKey(_clave(obra)),
      builder: (context, constraints) => DragTarget<LibraryItem>(
        onWillAcceptWithDetails: (_) => _grupoArrastre == grupo.nombre,
        onMove: (_) {
          if (_grupoArrastre == grupo.nombre && _destinoArrastre != index) {
            setState(() => _destinoArrastre = index);
          }
        },
        onAcceptWithDetails: (_) => _soltar(grupo.nombre, vista),
        builder: (context, _, __) => Draggable<LibraryItem>(
          key: ValueKey('coleccion-arrastrar-${obra.id}'),
          data: obra,
          onDragStarted: () => setState(() {
            _grupoArrastre = grupo.nombre;
            _obraArrastrada = obra;
            _destinoArrastre = index;
          }),
          onDragEnd: (detalles) {
            if (!detalles.wasAccepted) _terminarArrastre();
          },
          onDraggableCanceled: (_, __) => _terminarArrastre(),
          feedback: Material(
            color: Colors.transparent,
            elevation: 14,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: Transform.scale(
              scale: 1.04,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child:
                    _LibraryCoverImage(source: obra.coverUrl, type: obra.type),
              ),
            ),
          ),
          childWhenDragging: _HuecoPortada(obra: obra),
          child: esLaArrastrada ? _HuecoPortada(obra: obra) : tarjeta,
        ),
      ),
    );
  }

  /// Cabecera de un apartado, que se arrastra para cambiar el orden de los
  /// apartados de la colección.
  Widget _cabeceraArrastrable({
    required GrupoColeccion grupo,
    required int posicion,
    required List<GrupoColeccion> apartados,
    required bool activo,
    required Widget child,
  }) {
    final visuals = context.visuals;
    final cabecera = Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 6, 6),
      child: Row(
        children: [
          if (activo)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Icon(Icons.drag_indicator_rounded,
                  size: 18, color: visuals.textMuted),
            ),
          Expanded(child: child),
        ],
      ),
    );
    if (!activo) return cabecera;
    final arrastrado = _apartadoArrastrado == grupo.nombre;
    return DragTarget<GrupoColeccion>(
      onWillAcceptWithDetails: (_) => _apartadoArrastrado != null,
      onMove: (_) {
        if (_apartadoArrastrado != null && _destinoApartado != posicion) {
          setState(() => _destinoApartado = posicion);
        }
      },
      onAcceptWithDetails: (_) => _soltarApartado(apartados),
      builder: (context, _, __) => Draggable<GrupoColeccion>(
        key: ValueKey('coleccion-arrastrar-apartado-${grupo.nombre}'),
        data: grupo,
        axis: Axis.vertical,
        onDragStarted: () => setState(() {
          _apartadoArrastrado = grupo.nombre;
          _destinoApartado = posicion;
        }),
        onDragEnd: (detalles) {
          if (!detalles.wasAccepted) _terminarArrastreApartado();
        },
        onDraggableCanceled: (_, __) => _terminarArrastreApartado(),
        feedback: Material(
          elevation: 10,
          color: visuals.panel,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              '${grupo.nombre} · ${grupo.obras.length}',
              style: TextStyle(
                color: visuals.textStrong,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: cabecera),
        child: arrastrado ? Opacity(opacity: 0.35, child: cabecera) : cabecera,
      ),
    );
  }

  bool _plegado(GrupoColeccion grupo) =>
      controller.visibilitySettings.hiddenCollectionWorks
          .contains(_claveGrupo(grupo));

  Future<void> _estado(LibraryItem obra, LibraryItemStatus estado) async {
    if (!_anadiendo.add(obra.id)) return;
    try {
      await _ponerEstadoObra(controller, obra, estado);
    } finally {
      _anadiendo.remove(obra.id);
    }
  }

  Future<void> _anadir(LibraryItem obra) =>
      _estado(obra, LibraryItemStatus.pending);

  Future<void> _editar(LibraryItem obra) => _editarObraColeccion(
        context,
        controller,
        widget.coleccion.id,
        obra,
      );

  bool _editada(LibraryItem obra) =>
      controller.visibilitySettings.collectionWorkEdits
          .containsKey(_claveObra(widget.coleccion, obra));

  /// Botón «+» de la portada: añade la obra o, en un tomo, lo marca leído.
  Future<void> _anadirDesdeTarjeta(LibraryItem obra) => _estado(
        obra,
        _esTomo(obra) ? LibraryItemStatus.completed : LibraryItemStatus.pending,
      );

  /// Menú del clic derecho: el mismo de Biblioteca si la obra ya está en
  /// ella; si no, las opciones para añadirla. Los tomos de un manga se marcan
  /// como leídos, leyéndose o sin leer.
  Future<void> _menuObra(
    BuildContext context,
    LibraryItem obra,
    Offset posicion,
  ) async {
    final item = _obraEnBiblioteca(controller, obra);
    // Las opciones de añadir de la pestaña Biblioteca no aplican aquí.
    _libraryAddMenuContext = null;
    if (item != null && !_esTomo(obra)) {
      await _showLibraryContextMenu(
        context: context,
        position: posicion,
        onPages: () => _openKnowledgeWorkspace(context, controller, item),
        onStart: _libraryStartAction(controller, item),
        onComplete: _libraryCompleteAction(context, controller, item),
        onRating: item.status != LibraryItemStatus.completed
            ? null
            : () => _editLibraryRating(context, controller, item),
        onProgress: _libraryMarkProgressAction(context, controller, item),
        progressLabel: _libraryMarkProgressLabel(item),
        onEdit: () => showDialog<void>(
          context: context,
          builder: (context) =>
              _LibraryItemDialog(controller: controller, item: item),
        ),
        onDelete: () async {
          final confirmado = await _confirmLibraryDelete(
            context,
            title: 'Borrar de la biblioteca',
            message: _libraryDeleteMessage(controller, item),
          );
          if (confirmado) controller.deleteLibraryItem(item.id);
        },
      );
      return;
    }
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final tomo = _esTomo(obra);
    final actual = _estadoObra(controller, obra);
    PopupMenuItem<Object> opcion(Object valor, IconData icono, String texto) =>
        PopupMenuItem<Object>(
          value: valor,
          child: ListTile(
            dense: true,
            leading: Icon(icono),
            title: Text(texto),
          ),
        );
    final elegido = await showMenu<Object>(
      context: context,
      position: RelativeRect.fromRect(
        posicion & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (tomo) ...[
          if (actual != LibraryItemStatus.completed)
            opcion(LibraryItemStatus.completed,
                Icons.check_circle_outline_rounded, 'Marcar como leído'),
          if (actual != LibraryItemStatus.inProgress)
            opcion(LibraryItemStatus.inProgress, Icons.play_arrow_rounded,
                'Marcar como leyendo'),
          if (actual != null)
            opcion(LibraryItemStatus.pending, Icons.bookmark_outline_rounded,
                'Marcar como sin leer'),
          if (item != null)
            opcion('ver', Icons.local_library_rounded,
                'Ver el manga en Biblioteca'),
        ] else ...[
          opcion(LibraryItemStatus.pending, Icons.bookmark_outline_rounded,
              'Añadir como pendiente'),
          opcion(LibraryItemStatus.inProgress, Icons.play_arrow_rounded,
              'Añadir como en curso'),
          opcion(LibraryItemStatus.completed,
              Icons.check_circle_outline_rounded, 'Añadir como completado'),
        ],
        const PopupMenuDivider(),
        opcion('editar', Icons.edit_outlined, 'Editar portada y datos'),
        if (_editada(obra))
          opcion('restaurar', Icons.restart_alt_rounded,
              'Volver a los datos originales'),
        opcion(
            'quitar',
            Icons.close_rounded,
            _quitada(obra)
                ? 'Recuperar en la colección'
                : 'Quitar de la colección'),
      ],
    );
    if (!mounted) return;
    if (elegido is LibraryItemStatus) {
      await _estado(obra, elegido);
    } else if (elegido == 'ver' && item != null && context.mounted) {
      await _showLibraryItemDetails(context, controller, [item], item);
    } else if (elegido == 'quitar') {
      _alternar(obra);
    } else if (elegido == 'editar') {
      await _editar(obra);
    } else if (elegido == 'restaurar') {
      controller.setCollectionWorkEdit(
          _claveObra(widget.coleccion, obra), null);
    }
  }

  void _terminarSeleccion() => setState(() {
        _seleccionando = false;
        _seleccion.clear();
      });

  /// Añade o cambia de estado varias obras, tras confirmarlo.
  Future<void> _enBloque(
    List<LibraryItem> obras,
    LibraryItemStatus estado,
  ) async {
    if (obras.isEmpty) return;
    final tomos = obras.every(_esTomo);
    final nuevas =
        obras.where((obra) => _obraEnBiblioteca(controller, obra) == null);
    final cambian = obras.length - nuevas.length;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Marcar ${obras.length} como '
            '${_estadoEnPlural(estado, tomos: tomos)}'),
        content: Text(tomos
            ? 'Todos los tomos comparten la ficha del manga en tu Biblioteca.'
            : [
                if (nuevas.isNotEmpty)
                  'Se añadirán ${nuevas.length} a tu Biblioteca.',
                if (cambian > 0)
                  'Se cambiará el estado de $cambian que ya están en tu Biblioteca.',
              ].join(' ')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('coleccion-bloque-aceptar'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    for (final obra in obras) {
      await _estado(obra, estado);
    }
    if (mounted) _terminarSeleccion();
  }

  Widget _menuEstados({
    required Key key,
    required String texto,
    required IconData icono,
    required bool activo,
    required void Function(LibraryItemStatus estado) alElegir,
    bool tomos = false,
  }) {
    return MenuAnchor(
      menuChildren: [
        for (final estado in LibraryItemStatus.values)
          MenuItemButton(
            key: ValueKey('$key-${estado.name}'),
            onPressed: () => alElegir(estado),
            child: Text('Como ${_estadoEnPlural(estado, tomos: tomos)}'),
          ),
      ],
      builder: (context, menu, _) => OutlinedButton.icon(
        key: key,
        onPressed:
            activo ? () => menu.isOpen ? menu.close() : menu.open() : null,
        icon: Icon(icono, size: 18),
        label: Text(texto),
        style: _libraryDetailSecondaryButtonStyle(context),
      ),
    );
  }

  String _resumen(List<LibraryItem> obras) {
    if (obras.isNotEmpty && obras.every(_esTomo)) {
      final leidos = obras
          .where((obra) =>
              _estadoObra(controller, obra) == LibraryItemStatus.completed)
          .length;
      return '${obras.length} tomos · $leidos leídos';
    }
    final tipos = obras.map((obra) => obra.type).toSet();
    final nombre = tipos.length == 1
        ? _libraryTypePluralLabel(tipos.first).toLowerCase()
        : 'obras';
    final enBiblioteca =
        obras.where((obra) => _estadoObra(controller, obra) != null).length;
    final completadas = obras
        .where((obra) =>
            _estadoObra(controller, obra) == LibraryItemStatus.completed)
        .length;
    return '${obras.length} $nombre · $enBiblioteca en tu Biblioteca · '
        '$completadas completadas';
  }

  List<LibraryItem> _filtrar(List<LibraryItem> obras) {
    final lista = _ocultarTengo
        ? obras.where((obra) => _estadoObra(controller, obra) == null)
        : obras;
    if (!_porAnio) return lista.toList();
    // Las que no tienen año todavía van al final.
    return lista.toList()
      ..sort(
          (a, b) => (a.releaseYear ?? 9999).compareTo(b.releaseYear ?? 9999));
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final coleccion = _coleccionEditada(controller, widget.coleccion);
    final quitadas = coleccion.obras.where(_quitada).toList();
    final verQuitadas = _verQuitadas && quitadas.isNotEmpty;
    // Por año, la saga entera se ve en un solo bloque cronológico.
    final grupos = [
      if (_porAnio)
        GrupoColeccion(
          nombre: 'Por año de salida',
          obras: _filtrar(coleccion.obras
              .where((obra) => _quitada(obra) == verQuitadas)
              .toList()),
        )
      else
        for (final grupo in coleccion.grupos)
          GrupoColeccion(
            nombre: grupo.nombre,
            obras: _filtrar(_ordenado(grupo)
                .where((obra) => _quitada(obra) == verQuitadas)
                .toList()),
          ),
    ].where((grupo) => grupo.obras.isNotEmpty).toList();
    final apartados = _porAnio ? grupos : _apartadosOrdenados(grupos);
    // Se arrastra para reordenar solo en la vista normal de la saga.
    final arrastrable = !_porAnio && !_seleccionando && !verQuitadas;
    final hayOrdenPropio =
        coleccion.grupos.any((g) => _ordenGuardado(g) != null) ||
            _ordenApartados != null;
    final obras = [for (final grupo in apartados) ...grupo.obras];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 6),
            IconButton(
              key: const ValueKey('coleccion-volver'),
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              constraints: const BoxConstraints.tightFor(width: 36, height: 40),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coleccion.nombre,
                    style: TextStyle(
                      color: visuals.textStrong,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _resumen(coleccion.obras
                        .where((obra) => !_quitada(obra))
                        .toList()),
                    style: TextStyle(
                      color: visuals.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ColeccionProgreso(
                    total:
                        coleccion.obras.where((obra) => !_quitada(obra)).length,
                    completadas: coleccion.obras
                        .where((obra) =>
                            !_quitada(obra) &&
                            _estadoObra(controller, obra) ==
                                LibraryItemStatus.completed)
                        .length,
                  ),
                ],
              ),
            ),
            MenuAnchor(
              menuChildren: [
                CheckboxMenuButton(
                  key: const ValueKey('coleccion-ver-por-anio'),
                  value: _porAnio,
                  onChanged: (valor) =>
                      setState(() => _porAnio = valor ?? false),
                  child: const Text('Ordenar por año'),
                ),
                CheckboxMenuButton(
                  key: const ValueKey('coleccion-ver-ocultar-tengo'),
                  value: _ocultarTengo,
                  onChanged: (valor) =>
                      setState(() => _ocultarTengo = valor ?? false),
                  child: const Text('Ocultar las que ya tengo'),
                ),
                if (hayOrdenPropio)
                  MenuItemButton(
                    key: const ValueKey('coleccion-ver-orden-original'),
                    leadingIcon:
                        const Icon(Icons.restart_alt_rounded, size: 18),
                    onPressed: () {
                      for (final grupo in coleccion.grupos) {
                        controller.setCollectionGroupOrder(
                            _claveOrden(grupo), const []);
                      }
                      controller.setCollectionGroupOrder(
                          _claveOrdenApartados, const []);
                    },
                    child: const Text('Volver al orden original'),
                  ),
              ],
              builder: (context, menu, _) => OutlinedButton.icon(
                key: const ValueKey('coleccion-ver'),
                onPressed: () => menu.isOpen ? menu.close() : menu.open(),
                icon: Icon(
                  _porAnio || _ocultarTengo
                      ? Icons.filter_alt_rounded
                      : Icons.tune_rounded,
                  size: 18,
                ),
                label: const Text('Ver'),
                style: _libraryDetailSecondaryButtonStyle(context),
              ),
            ),
            const SizedBox(width: 10),
            if (!verQuitadas && _seleccionando) ...[
              Text(
                '${_seleccion.length} seleccionadas',
                style: TextStyle(
                  color: visuals.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              _menuEstados(
                key: const ValueKey('coleccion-seleccion-anadir'),
                texto: 'Añadir seleccionadas',
                icono: Icons.library_add_outlined,
                activo: _seleccion.isNotEmpty,
                alElegir: (estado) => _enBloque(
                  obras.where((obra) => _seleccion.contains(obra.id)).toList(),
                  estado,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: const ValueKey('coleccion-seleccion-cancelar'),
                onPressed: _terminarSeleccion,
                style: _libraryDetailSecondaryButtonStyle(context),
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 10),
            ] else if (!verQuitadas) ...[
              _menuEstados(
                key: const ValueKey('coleccion-anadir-todas'),
                texto: obras.every(_esTomo) ? 'Marcar todos' : 'Añadir todas',
                icono: Icons.library_add_outlined,
                tomos: obras.every(_esTomo),
                activo: obras.every(_esTomo) ||
                    obras.any(
                        (obra) => _obraEnBiblioteca(controller, obra) == null),
                alElegir: (estado) => _enBloque(
                  obras
                      .where((obra) =>
                          _esTomo(obra) ||
                          _obraEnBiblioteca(controller, obra) == null)
                      .toList(),
                  estado,
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                key: const ValueKey('coleccion-seleccionar'),
                onPressed: () => setState(() => _seleccionando = true),
                icon: const Icon(Icons.checklist_rounded, size: 18),
                label: const Text('Seleccionar'),
                style: _libraryDetailSecondaryButtonStyle(context),
              ),
              const SizedBox(width: 10),
            ],
            if (quitadas.isNotEmpty)
              OutlinedButton.icon(
                key: const ValueKey('coleccion-ver-quitadas'),
                onPressed: () => setState(() => _verQuitadas = !verQuitadas),
                icon: Icon(
                  verQuitadas
                      ? Icons.collections_bookmark_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                ),
                label: Text(verQuitadas
                    ? 'Ver la colección'
                    : 'Quitadas (${quitadas.length})'),
                style: _libraryDetailSecondaryButtonStyle(context),
              ),
            const SizedBox(width: 6),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final maxExtent = constraints.maxWidth >= 980
                ? 194.0
                : constraints.maxWidth >= 720
                    ? 176.0
                    : 154.0;
            return CustomScrollView(
              slivers: [
                for (final (posicion, grupo) in apartados.indexed) ...[
                  SliverToBoxAdapter(
                    child: _cabeceraArrastrable(
                      grupo: grupo,
                      posicion: posicion,
                      apartados: apartados,
                      activo: arrastrable && apartados.length > 1,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Tooltip(
                          message: _plegado(grupo)
                              ? 'Desplegar ${grupo.nombre}'
                              : 'Plegar ${grupo.nombre}',
                          child: InkWell(
                            key: ValueKey('coleccion-grupo-${grupo.nombre}'),
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => controller.setCollectionWorkHidden(
                              _claveGrupo(grupo),
                              !_plegado(grupo),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _plegado(grupo)
                                        ? Icons.chevron_right_rounded
                                        : Icons.expand_more_rounded,
                                    size: 22,
                                    color: visuals.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${grupo.nombre} · ${grupo.obras.length}',
                                    style: TextStyle(
                                      color: visuals.textStrong,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Mientras se arrastra un apartado solo quedan las
                  // cabeceras, para poder soltarlo sin desplazarse.
                  if (_plegado(grupo) || _apartadoArrastrado != null)
                    const SliverToBoxAdapter(child: SizedBox(height: 10))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 26),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: maxExtent,
                          mainAxisSpacing: 24,
                          crossAxisSpacing: 20,
                          childAspectRatio: 0.66,
                        ),
                        itemCount: _vistaPrevia(grupo).length,
                        findChildIndexCallback: (clave) {
                          final i = _vistaPrevia(grupo).indexWhere(
                              (obra) => ValueKey(_clave(obra)) == clave);
                          return i < 0 ? null : i;
                        },
                        itemBuilder: (context, index) {
                          final vista = _vistaPrevia(grupo);
                          final obra = vista[index];
                          final tarjeta = _ColeccionObraTarjeta(
                            key: ValueKey(_clave(obra)),
                            obra: obra,
                            quitada: verQuitadas,
                            estado: _estadoObra(controller, obra),
                            seleccionando: _seleccionando && !verQuitadas,
                            seleccionada: _seleccion.contains(obra.id),
                            onTap: _seleccionando && !verQuitadas
                                ? () => setState(() {
                                      if (!_seleccion.add(obra.id)) {
                                        _seleccion.remove(obra.id);
                                      }
                                    })
                                : () => _mostrarObraColeccion(
                                      context,
                                      controller,
                                      obras,
                                      obra,
                                      verQuitadas,
                                      _anadir,
                                      _alternar,
                                      _estado,
                                      _editar,
                                    ),
                            onAdd: () => _anadirDesdeTarjeta(obra),
                            onToggle: () => _alternar(obra),
                            onMenu: (posicion) =>
                                _menuObra(context, obra, posicion),
                          );
                          if (!arrastrable) return tarjeta;
                          return _portadaArrastrable(
                            grupo: grupo,
                            obra: obra,
                            index: index,
                            vista: vista,
                            tarjeta: tarjeta,
                          );
                        },
                      ),
                    ),
                ],
              ],
            );
          }),
        ),
      ],
    );
  }
}

/// Portada que se puede arrastrar sobre otra del mismo apartado para
/// cambiar el orden de la saga.
/// Hueco que deja una portada mientras se arrastra: marca dónde quedará.
class _HuecoPortada extends StatelessWidget {
  const _HuecoPortada({required this.obra});

  final LibraryItem obra;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF9DCB7E), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Opacity(
            opacity: 0.25,
            child: _LibraryCoverImage(source: obra.coverUrl, type: obra.type),
          ),
        ),
      ),
    );
  }
}

class _ColeccionObraTarjeta extends StatefulWidget {
  const _ColeccionObraTarjeta({
    required super.key,
    required this.obra,
    required this.quitada,
    required this.estado,
    required this.seleccionando,
    required this.seleccionada,
    required this.onTap,
    required this.onAdd,
    required this.onToggle,
    required this.onMenu,
  });

  final LibraryItem obra;
  final bool quitada;
  final LibraryItemStatus? estado;

  /// Clic derecho o pulsación larga sobre la portada.
  final ValueChanged<Offset> onMenu;
  final bool seleccionando;
  final bool seleccionada;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onToggle;

  @override
  State<_ColeccionObraTarjeta> createState() => _ColeccionObraTarjetaState();
}

class _ColeccionObraTarjetaState extends State<_ColeccionObraTarjeta> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final obra = widget.obra;
    final estado = widget.estado;
    final tomo = _esTomo(obra);
    final borde = widget.seleccionada
        ? const Color(0xFF9DCB7E)
        : switch (estado) {
            LibraryItemStatus.completed => const Color(0xFF5F7F49),
            LibraryItemStatus.inProgress => const Color(0xFFC77721),
            LibraryItemStatus.pending => const Color(0xFF7D8CA3),
            null => null,
          };
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        onSecondaryTapDown: (details) => widget.onMenu(details.globalPosition),
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          key: ValueKey('coleccion-obra-${obra.id}'),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..scaleByDouble(
              _hovered ? 1.025 : 1.0,
              _hovered ? 1.025 : 1.0,
              1,
              1,
            ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF18202A),
            borderRadius: BorderRadius.circular(7),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.26 : 0.18),
                blurRadius: _hovered ? 22 : 16,
                offset: Offset(0, _hovered ? 11 : 8),
              ),
            ],
          ),
          foregroundDecoration: borde == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: borde, width: 4),
                ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _LibraryCoverImage(
                source: obra.coverUrl,
                type: obra.type,
                iconSize: 44,
              ),
              AnimatedOpacity(
                opacity: _hovered ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00000000),
                        Color(0x1A000000),
                        Color(0xB8000000),
                      ],
                      stops: [0.42, 0.72, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: estado != null && !tomo ? 44 : 14,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      obra.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        shadows: [
                          Shadow(color: Color(0xAA000000), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (estado != null && !tomo)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xE63B4654),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        obra.releaseYear?.toString() ?? 'Por confirmar',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.seleccionando)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    key: ValueKey('coleccion-casilla-${obra.id}'),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.seleccionada
                          ? const Color(0xFF607A4D)
                          : const Color(0xB3202732),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: widget.seleccionada
                        ? const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                )
              else if (_hovered)
                Positioned(
                  top: 6,
                  left: 6,
                  child: _ColeccionBotonCubierta(
                    key: ValueKey('coleccion-quitar-${obra.id}'),
                    tooltip: widget.quitada
                        ? 'Recuperar en la colección'
                        : 'Quitar de la colección',
                    icon: widget.quitada
                        ? Icons.undo_rounded
                        : Icons.close_rounded,
                    color: const Color(0xE63B4654),
                    onPressed: widget.onToggle,
                  ),
                ),
              if (estado != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _LibraryStatusBadge(
                    status: estado,
                    label: tomo ? _estadoTomo(estado) : null,
                  ),
                )
              else if (_hovered && !widget.quitada && !widget.seleccionando)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _ColeccionBotonCubierta(
                    key: ValueKey('coleccion-anadir-${obra.id}'),
                    tooltip: tomo ? 'Marcar como leído' : 'Añadir a Biblioteca',
                    icon: tomo ? Icons.check_rounded : Icons.add_rounded,
                    color: const Color(0xFF607A4D),
                    onPressed: widget.onAdd,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColeccionBotonCubierta extends StatelessWidget {
  const _ColeccionBotonCubierta({
    required super.key,
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
    );
  }
}

Future<void> _mostrarObraColeccion(
  BuildContext context,
  TodoWorkspace controller,
  List<LibraryItem> obras,
  LibraryItem obra,
  bool quitada,
  Future<void> Function(LibraryItem obra) onAdd,
  void Function(LibraryItem obra) onToggle,
  Future<void> Function(LibraryItem obra, LibraryItemStatus estado) onEstado,
  void Function(LibraryItem obra) onEditar,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => ListenableBuilder(
      listenable: controller,
      builder: (dialogContext, _) => _ColeccionObraDialog(
        controller: controller,
        obras: obras,
        inicial: obras.indexOf(obra),
        quitada: quitada,
        onAdd: onAdd,
        onToggle: onToggle,
        onEstado: onEstado,
        onEditar: onEditar,
        origen: context,
      ),
    ),
  );
}

/// Ficha de una obra del catálogo, con el mismo aspecto que la de Biblioteca.
class _ColeccionObraDialog extends StatefulWidget {
  const _ColeccionObraDialog({
    required this.controller,
    required this.obras,
    required this.inicial,
    required this.quitada,
    required this.onAdd,
    required this.onToggle,
    required this.onEstado,
    required this.onEditar,
    required this.origen,
  });

  /// Abre el editor de la obra.
  final void Function(LibraryItem obra) onEditar;

  final TodoWorkspace controller;
  final List<LibraryItem> obras;
  final int inicial;
  final bool quitada;
  final Future<void> Function(LibraryItem obra) onAdd;
  final void Function(LibraryItem obra) onToggle;
  final Future<void> Function(LibraryItem obra, LibraryItemStatus estado)
      onEstado;

  /// Contexto de la colección, para abrir la ficha tras cerrar este diálogo.
  final BuildContext origen;

  @override
  State<_ColeccionObraDialog> createState() => _ColeccionObraDialogState();
}

class _ColeccionObraDialogState extends State<_ColeccionObraDialog> {
  late int _indice = widget.inicial;

  /// Con las flechas del teclado, al pasar del último se vuelve al primero.
  void _moverCiclico(int paso) {
    final total = widget.obras.length;
    if (total < 2) return;
    setState(() => _indice = (_indice + paso) % total);
  }

  void _verEnBiblioteca(LibraryItem item) {
    Navigator.of(context).pop();
    unawaited(_showLibraryItemDetails(
      widget.origen,
      widget.controller,
      [item],
      item,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final obra = widget.obras[_indice];
    final enBiblioteca = _obraEnBiblioteca(widget.controller, obra);
    // Los mismos campos y en el mismo orden que la ficha de Biblioteca; el
    // progreso de lectura no aplica a una obra del catálogo.
    final fecha = _fechaPrevista(obra);
    final campos = [
      ..._detailFields(obra)
          .where((campo) => campo.$1 != 'Progreso' && campo.$1 != 'Capítulos'),
    ];
    final dia = fecha == null ? null : _diaDeSalida(fecha);
    final tituloAviso = 'Sale «${obra.title}»';
    final avisoCreado =
        widget.controller.tasks.any((tarea) => tarea.title == tituloAviso);
    return _NavegacionConFlechas(
        onAnterior: () => _moverCiclico(-1),
        onSiguiente: () => _moverCiclico(1),
        child: Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1040,
              maxHeight: min(640, MediaQuery.sizeOf(context).height - 60),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 22, 24, 18),
                  child: Row(
                    children: [
                      Icon(_libraryIcon(obra.type),
                          color: _libraryColor(obra.type), size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _TextoConAyudaSiRecortado(
                          texto: obra.title,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 23,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('coleccion-obra-editar'),
                        tooltip: 'Editar portada y datos',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onEditar(obra);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 244,
                          height: 366,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _LibraryCoverImage(
                              source: obra.coverUrl,
                              type: obra.type,
                              iconSize: 34,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final campo in campos) ...[
                                _LibraryDetailLine(
                                  label: campo.$1,
                                  value: campo.$2,
                                  valueWidget: campo.$1 == 'Estado'
                                      ? _ColeccionEstadoSelector(
                                          estado: _estadoObra(
                                              widget.controller, obra),
                                          tomo: _esTomo(obra),
                                          onSelected: (estado) =>
                                              widget.onEstado(obra, estado),
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (fecha != null)
                                _LibraryDetailLine(
                                  label: 'Fecha prevista de salida',
                                  value: fecha,
                                  valueWidget: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          fecha.isEmpty ? '-' : fecha,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (dia != null &&
                                          dia.isAfter(DateTime.now())) ...[
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          key: const ValueKey(
                                              'coleccion-obra-aviso'),
                                          onPressed: avisoCreado
                                              ? null
                                              : () =>
                                                  widget.controller.createTask(
                                                    title: tituloAviso,
                                                    description:
                                                        'Fecha prevista de salida '
                                                        'de ${obra.title}.',
                                                    scheduledAt: DateTime(
                                                      dia.year,
                                                      dia.month,
                                                      dia.day,
                                                      10,
                                                    ),
                                                  ),
                                          icon: Icon(
                                            avisoCreado
                                                ? Icons
                                                    .notifications_active_rounded
                                                : Icons
                                                    .notifications_none_rounded,
                                            size: 18,
                                          ),
                                          label: Text(avisoCreado
                                              ? 'Aviso creado'
                                              : 'Avisarme ese día'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 18),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: _libraryDetailSecondaryButtonStyle(context),
                        child: const Text('Cerrar'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        key: const ValueKey('coleccion-obra-quitar'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onToggle(obra);
                        },
                        icon: Icon(
                          widget.quitada
                              ? Icons.undo_rounded
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        label: Text(widget.quitada
                            ? 'Recuperar'
                            : 'Quitar de la colección'),
                        style: _libraryDetailSecondaryButtonStyle(context),
                      ),
                      if (_enlaceFicha(obra) != null) ...[
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          key: const ValueKey('coleccion-obra-enlace'),
                          onPressed: () => unawaited(
                            launchUrl(
                              _enlaceFicha(obra)!,
                              mode: LaunchMode.externalApplication,
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label:
                              Text('Abrir en ${nombreFichaExterna(obra.type)}'),
                          style: _libraryDetailSecondaryButtonStyle(context),
                        ),
                      ],
                      const Spacer(),
                      if (_indice > 0) ...[
                        _LibraryNavigationButton(
                          label: 'Anterior',
                          icon: Icons.chevron_left_rounded,
                          onPressed: () => setState(() => _indice--),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (_indice < widget.obras.length - 1) ...[
                        _LibraryNavigationButton(
                          label: 'Siguiente',
                          trailingIcon: Icons.chevron_right_rounded,
                          onPressed: () => setState(() => _indice++),
                        ),
                        const SizedBox(width: 10),
                      ],
                      FilledButton.icon(
                        key: const ValueKey('coleccion-obra-accion'),
                        onPressed: enBiblioteca != null
                            ? () => _verEnBiblioteca(enBiblioteca)
                            : () => widget.onAdd(obra),
                        icon: Icon(
                          enBiblioteca != null
                              ? Icons.local_library_rounded
                              : Icons.add_rounded,
                          size: 18,
                        ),
                        label: Text(enBiblioteca != null
                            ? 'Ver en Biblioteca'
                            : 'Añadir a Biblioteca'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(124, 48),
                          backgroundColor: const Color(0xFF607A4D),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}

/// Pasa al elemento anterior o siguiente con las flechas izquierda y derecha.
/// Los campos de texto conservan las flechas para mover el cursor.
class _NavegacionConFlechas extends StatelessWidget {
  const _NavegacionConFlechas({
    required this.onAnterior,
    required this.onSiguiente,
    required this.child,
  });

  final VoidCallback onAnterior;
  final VoidCallback onSiguiente;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): onAnterior,
        const SingleActivator(LogicalKeyboardKey.arrowRight): onSiguiente,
      },
      child: Focus(autofocus: true, child: child),
    );
  }
}

/// Estado de una obra de la colección: sin añadir, o su estado en Biblioteca.
/// Elegir uno añade la obra a la Biblioteca o cambia su estado.
class _ColeccionEstadoSelector extends StatelessWidget {
  const _ColeccionEstadoSelector({
    required this.estado,
    required this.onSelected,
    this.tomo = false,
  });

  final LibraryItemStatus? estado;

  /// Los tomos de un manga solo pueden estar sin leer, leyéndose o leídos.
  final bool tomo;
  final ValueChanged<LibraryItemStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final colores = switch (estado) {
      LibraryItemStatus.pending => (
          const Color(0xFFECEFF3),
          const Color(0xFF687384)
        ),
      LibraryItemStatus.inProgress => (
          const Color(0xFFFFEFD9),
          const Color(0xFFC77721)
        ),
      LibraryItemStatus.completed => (
          const Color(0xFFDCECCF),
          const Color(0xFF4E703B)
        ),
      null => (context.visuals.panel, context.visuals.textMuted),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: MenuAnchor(
        alignmentOffset: const Offset(0, 2),
        menuChildren: [
          for (final opcion in LibraryItemStatus.values)
            MenuItemButton(
              key: ValueKey('coleccion-estado-${opcion.name}'),
              onPressed: () => onSelected(opcion),
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(180, 40)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: opcion == estado
                        ? const Icon(Icons.check_rounded, size: 16)
                        : null,
                  ),
                  Text(tomo
                      ? _estadoTomo(opcion)
                      : _libraryStatusSingularLabel(opcion)),
                ],
              ),
            ),
        ],
        builder: (context, menu, child) => InkWell(
          key: const ValueKey('coleccion-estado-selector'),
          borderRadius: BorderRadius.circular(999),
          onTap: () => menu.isOpen ? menu.close() : menu.open(),
          child: child,
        ),
        child: Container(
          // Tan baja como el texto de las demás filas de la ficha.
          padding: const EdgeInsets.fromLTRB(10, 1, 4, 1),
          decoration: BoxDecoration(
            color: colores.$1,
            borderRadius: BorderRadius.circular(999),
            border: estado == null
                ? Border.all(color: context.visuals.panelBorder)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tomo
                    ? _estadoTomo(estado)
                    : estado == null
                        ? 'Sin añadir'
                        : _libraryStatusSingularLabel(estado!),
                style: TextStyle(
                  color: colores.$2,
                  fontSize: 13,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: colores.$2,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _mesesDelAnio = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Día de salida si la fecha prevista es exacta, como «18 de febrero de 2027».
DateTime? _diaDeSalida(String texto) {
  final m = RegExp(r'(\d{1,2}) de ([a-záéíóú]+) de (\d{4})')
      .firstMatch(texto.toLowerCase());
  if (m == null) return null;
  final mes = _mesesDelAnio.indexOf(m.group(2)!) + 1;
  if (mes == 0) return null;
  return DateTime(int.parse(m.group(3)!), mes, int.parse(m.group(1)!));
}

class _ColeccionProgreso extends StatelessWidget {
  const _ColeccionProgreso({required this.total, required this.completadas});

  final int total;
  final int completadas;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          key: const ValueKey('coleccion-progreso'),
          value: total == 0 ? 0 : completadas / total,
          minHeight: 6,
          backgroundColor: context.visuals.panelBorder,
          color: const Color(0xFF5F7F49),
        ),
      ),
    );
  }
}

/// Colección con solo las obras de un tipo. Reutiliza las mismas obras para
/// que sus claves, estados y fechas previstas sigan siendo los de la saga.
Coleccion _coleccionDeTipo(Coleccion coleccion, LibraryItemType? tipo) {
  if (tipo == null) return coleccion;
  return Coleccion(
    id: coleccion.id,
    nombre: coleccion.nombre,
    alias: coleccion.alias,
    fondo: coleccion.fondo,
    fechasPrevistas: coleccion.fechasPrevistas,
    grupos: [
      for (final grupo in coleccion.grupos)
        if (grupo.obras.any((obra) => obra.type == tipo))
          GrupoColeccion(
            nombre: grupo.nombre,
            obras: grupo.obras.where((obra) => obra.type == tipo).toList(),
          ),
    ],
  );
}

/// Pestaña Colecciones de Biblioteca: las sagas del catálogo agrupadas por
/// tipo. Con un tipo elegido, cada saga muestra solo sus obras de ese tipo.
class _ColeccionesVista extends StatefulWidget {
  const _ColeccionesVista({
    required this.controller,
    required this.tipo,
    required this.onTipo,
  });

  final TodoWorkspace controller;
  final LibraryItemType? tipo;
  final ValueChanged<LibraryItemType?> onTipo;

  @override
  State<_ColeccionesVista> createState() => _ColeccionesVistaState();
}

class _ColeccionesVistaState extends State<_ColeccionesVista> {
  String _texto = '';

  /// Las secciones plegadas (Juegos, Libros…) se guardan junto a las obras
  /// quitadas, con su propia clave, para conservarlas al reiniciar.
  String _claveSeccion(String nombre) => 'colecciones/seccion:$nombre';

  bool _plegada(String nombre) =>
      widget.controller.visibilitySettings.hiddenCollectionWorks
          .contains(_claveSeccion(nombre));

  /// Clic derecho sobre una colección.
  Future<void> _menuColeccion(
    BuildContext context,
    Coleccion coleccion,
    Offset posicion,
  ) async {
    final overlay =
        Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final elegido = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        posicion & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'abrir',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.collections_bookmark_outlined),
            title: Text('Abrir'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'borrar',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Borrar colección'),
          ),
        ),
      ],
    );
    if (!context.mounted) return;
    if (elegido == 'abrir') {
      await _abrirColeccion(context, widget.controller, coleccion);
    } else if (elegido == 'borrar') {
      await _borrarColeccion(context, widget.controller, coleccion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final controller = widget.controller;
    final tipo = widget.tipo;
    final buscado = _texto.paraBuscar;
    final colecciones = [
      for (final coleccion in _colecciones ?? const <Coleccion>[])
        if (buscado.isEmpty ||
            coleccion.nombres.any((n) => n.paraBuscar.contains(buscado)) ||
            coleccion.obras.any((o) => o.title.paraBuscar.contains(buscado)))
          if (_coleccionVigente(controller, coleccion))
            _coleccionDeTipo(_coleccionEditada(controller, coleccion), tipo),
    ].where((coleccion) => coleccion.obras.isNotEmpty).toList();
    // Con «Todas», cada saga va a la sección de su tipo; las que mezclan
    // tipos van juntas al final.
    final secciones = <(String, List<Coleccion>)>[
      if (tipo != null)
        (_libraryTypePluralLabel(tipo), colecciones)
      else ...[
        for (final t in LibraryItemType.values)
          (
            _libraryTypePluralLabel(t),
            colecciones
                .where((c) => c.obras.every((obra) => obra.type == t))
                .toList(),
          ),
        (
          'De varios tipos',
          colecciones
              .where((c) => c.obras.map((obra) => obra.type).toSet().length > 1)
              .toList(),
        ),
      ],
    ].where((seccion) => seccion.$2.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            _LibraryTypeFilters(selected: tipo, onChanged: widget.onTipo),
            SizedBox(
              width: 280,
              child: TextField(
                key: const ValueKey('colecciones-buscar'),
                onChanged: (valor) => setState(() => _texto = valor),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Buscar saga u obra',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: secciones.isEmpty
              ? Center(
                  child: Text(
                    'No hay ninguna colección con ese nombre.',
                    style: TextStyle(color: visuals.textMuted),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => CustomScrollView(
                    slivers: [
                      for (final (nombre, lista) in secciones) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Tooltip(
                                message: _plegada(nombre)
                                    ? 'Mostrar $nombre'
                                    : 'Ocultar $nombre',
                                child: InkWell(
                                  key: ValueKey('colecciones-seccion-$nombre'),
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () =>
                                      controller.setCollectionWorkHidden(
                                    _claveSeccion(nombre),
                                    !_plegada(nombre),
                                  ),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(2, 4, 10, 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _plegada(nombre)
                                              ? Icons.chevron_right_rounded
                                              : Icons.expand_more_rounded,
                                          size: 24,
                                          color: visuals.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$nombre · ${lista.length}',
                                          style: TextStyle(
                                            color: visuals.textStrong,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_plegada(nombre))
                          const SliverToBoxAdapter(child: SizedBox(height: 14))
                        else
                          SliverPadding(
                            padding: const EdgeInsets.only(bottom: 28),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent:
                                    constraints.maxWidth >= 980 ? 210 : 180,
                                mainAxisSpacing: 22,
                                crossAxisSpacing: 20,
                                childAspectRatio: 0.56,
                              ),
                              itemCount: lista.length,
                              itemBuilder: (context, i) => _ColeccionTarjeta(
                                controller: controller,
                                coleccion: lista[i],
                                onTap: () => _abrirColeccion(
                                    context, controller, lista[i]),
                                onMenu: (posicion) =>
                                    _menuColeccion(context, lista[i], posicion),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Tarjeta de una saga con un mosaico de sus portadas y su progreso.
class _ColeccionTarjeta extends StatefulWidget {
  const _ColeccionTarjeta({
    required this.controller,
    required this.coleccion,
    required this.onTap,
    required this.onMenu,
  });

  final TodoWorkspace controller;
  final Coleccion coleccion;
  final VoidCallback onTap;

  /// Clic derecho sobre la tarjeta.
  final ValueChanged<Offset> onMenu;

  @override
  State<_ColeccionTarjeta> createState() => _ColeccionTarjetaState();
}

class _ColeccionTarjetaState extends State<_ColeccionTarjeta> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final controller = widget.controller;
    final coleccion = widget.coleccion;
    final quitadas = controller.visibilitySettings.hiddenCollectionWorks;
    final obras = coleccion.obras
        .where((obra) => !quitadas.contains(_claveObra(coleccion, obra)))
        .toList();
    final estados = [for (final obra in obras) _estadoObra(controller, obra)];
    final enBiblioteca = estados.whereType<LibraryItemStatus>().toList();
    final completadas = enBiblioteca
        .where((estado) => estado == LibraryItemStatus.completed)
        .length;
    final tipos = obras.map((obra) => obra.type).toSet();
    final tomos = obras.isNotEmpty && obras.every(_esTomo);
    final unidad = tomos
        ? 'tomos'
        : tipos.length == 1
            ? _libraryTypePluralLabel(tipos.first).toLowerCase()
            : 'obras';
    final portadas = (obras.isEmpty ? coleccion.obras : obras).take(4).toList();
    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey('colecciones-${coleccion.id}'),
        onTap: widget.onTap,
        onSecondaryTapDown: (details) => widget.onMenu(details.globalPosition),
        onLongPressStart: (details) => widget.onMenu(details.globalPosition),
        child: AnimatedScale(
          scale: _encima ? 1.03 : 1,
          duration: const Duration(milliseconds: 140),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _encima
                          ? const Color(0xFF5F7F49)
                          : visuals.panelBorder,
                      width: _encima ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: portadas.length < 4
                      ? _LibraryCoverImage(
                          source: portadas.first.coverUrl,
                          type: portadas.first.type,
                        )
                      : Column(
                          children: [
                            for (final fila in [
                              portadas.sublist(0, 2),
                              portadas.sublist(2, 4),
                            ])
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final obra in fila)
                                      Expanded(
                                        child: _LibraryCoverImage(
                                          source: obra.coverUrl,
                                          type: obra.type,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                coleccion.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: visuals.textStrong,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tomos
                    ? '${obras.length} $unidad · $completadas leídos'
                    : '${obras.length} $unidad · ${enBiblioteca.length} en tu '
                        'Biblioteca',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: visuals.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: obras.isEmpty ? 0 : completadas / obras.length,
                  minHeight: 5,
                  backgroundColor: visuals.panelBorder,
                  color: const Color(0xFF5F7F49),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
