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

/// Fecha prevista de salida de una obra que aún no ha salido; vacía si no se
/// conoce y nula si la obra ya está publicada.
String? _fechaPrevista(LibraryItem obra) {
  for (final coleccion in _colecciones ?? const <Coleccion>[]) {
    if (coleccion.obras.any((otra) => identical(otra, obra))) {
      return coleccion.fechasPrevistas[obra.id];
    }
  }
  return null;
}

/// Elemento de la Biblioteca que corresponde a una obra del catálogo, si existe.
LibraryItem? _obraEnBiblioteca(TodoWorkspace controller, LibraryItem obra) {
  final titulo = obra.title.paraBuscar;
  for (final item in controller.libraryItems) {
    if (item.type == obra.type && item.title.paraBuscar == titulo) return item;
  }
  return null;
}

/// Copia la portada del catálogo y crea el elemento como pendiente.
Future<void> _anadirObraABiblioteca(
  TodoWorkspace controller,
  LibraryItem obra, {
  LibraryItemStatus status = LibraryItemStatus.pending,
}) async {
  final portada = await rootBundle.load(obra.coverUrl!);
  final coverUrl = await _copyLibraryCoverBytes(portada.buffer.asUint8List());
  if (_obraEnBiblioteca(controller, obra) != null) return;
  controller.createLibraryItem(
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
}

/// Añade una obra del catálogo a la Biblioteca con ese estado, o cambia su
/// estado si ya estaba.
Future<void> _ponerEstadoObra(
  TodoWorkspace controller,
  LibraryItem obra,
  LibraryItemStatus estado,
) async {
  final existente = _obraEnBiblioteca(controller, obra);
  if (existente != null) {
    controller.updateLibraryItemStatus(existente.id, estado);
  } else {
    await _anadirObraABiblioteca(controller, obra, status: estado);
  }
}

String _estadoEnPlural(LibraryItemStatus estado) => switch (estado) {
      LibraryItemStatus.pending => 'pendientes',
      LibraryItemStatus.inProgress => 'en curso',
      LibraryItemStatus.completed => 'completadas',
    };

/// Abre la saga sobre la vista actual. Colecciones no tiene entrada propia:
/// solo se llega pulsando la chapa de una saga.
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _ColeccionDetalle(
            controller: controller,
            coleccion: coleccion,
          ),
        ),
      ),
    ),
  );
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

  String _clave(LibraryItem obra) => '${widget.coleccion.id}/${obra.id}';

  bool _quitada(LibraryItem obra) =>
      controller.visibilitySettings.hiddenCollectionWorks
          .contains(_clave(obra));

  void _alternar(LibraryItem obra) =>
      controller.setCollectionWorkHidden(_clave(obra), !_quitada(obra));

  /// Los apartados plegados se guardan junto a las obras quitadas, con su
  /// propia clave, para conservarlos al reiniciar.
  String _claveGrupo(GrupoColeccion grupo) =>
      '${widget.coleccion.id}/grupo:${grupo.nombre}';

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
    final nuevas =
        obras.where((obra) => _obraEnBiblioteca(controller, obra) == null);
    final cambian = obras.length - nuevas.length;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Marcar ${obras.length} como ${_estadoEnPlural(estado)}'),
        content: Text([
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
  }) {
    return MenuAnchor(
      menuChildren: [
        for (final estado in LibraryItemStatus.values)
          MenuItemButton(
            key: ValueKey('$key-${estado.name}'),
            onPressed: () => alElegir(estado),
            child: Text('Como ${_estadoEnPlural(estado)}'),
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
    final tipos = obras.map((obra) => obra.type).toSet();
    final nombre = tipos.length == 1
        ? _libraryTypePluralLabel(tipos.first).toLowerCase()
        : 'obras';
    final enBiblioteca = obras
        .where((obra) => _obraEnBiblioteca(controller, obra) != null)
        .length;
    final completadas = obras
        .where((obra) =>
            _obraEnBiblioteca(controller, obra)?.status ==
            LibraryItemStatus.completed)
        .length;
    return '${obras.length} $nombre · $enBiblioteca en tu Biblioteca · '
        '$completadas completadas';
  }

  List<LibraryItem> _filtrar(List<LibraryItem> obras) {
    final lista = _ocultarTengo
        ? obras.where((obra) => _obraEnBiblioteca(controller, obra) == null)
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
    final coleccion = widget.coleccion;
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
            obras: _filtrar(grupo.obras
                .where((obra) => _quitada(obra) == verQuitadas)
                .toList()),
          ),
    ].where((grupo) => grupo.obras.isNotEmpty).toList();
    final obras = [for (final grupo in grupos) ...grupo.obras];
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
                            _obraEnBiblioteca(controller, obra)?.status ==
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
                texto: 'Añadir todas',
                icono: Icons.library_add_outlined,
                activo: obras
                    .any((obra) => _obraEnBiblioteca(controller, obra) == null),
                alElegir: (estado) => _enBloque(
                  obras
                      .where(
                          (obra) => _obraEnBiblioteca(controller, obra) == null)
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
                for (final grupo in grupos) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 6, 6),
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
                  if (_plegado(grupo))
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
                        itemCount: grupo.obras.length,
                        itemBuilder: (context, index) {
                          final obra = grupo.obras[index];
                          return _ColeccionObraTarjeta(
                            key: ValueKey(_clave(obra)),
                            obra: obra,
                            quitada: verQuitadas,
                            enBiblioteca: _obraEnBiblioteca(controller, obra),
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
                                    ),
                            onAdd: () => _anadir(obra),
                            onToggle: () => _alternar(obra),
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

class _ColeccionObraTarjeta extends StatefulWidget {
  const _ColeccionObraTarjeta({
    required super.key,
    required this.obra,
    required this.quitada,
    required this.enBiblioteca,
    required this.seleccionando,
    required this.seleccionada,
    required this.onTap,
    required this.onAdd,
    required this.onToggle,
  });

  final LibraryItem obra;
  final bool quitada;
  final LibraryItem? enBiblioteca;
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
    final enBiblioteca = widget.enBiblioteca;
    final borde = widget.seleccionada
        ? const Color(0xFF9DCB7E)
        : switch (enBiblioteca?.status) {
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
                bottom: enBiblioteca != null ? 44 : 14,
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
              if (enBiblioteca != null)
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
              if (enBiblioteca != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _LibraryStatusBadge(status: enBiblioteca.status),
                )
              else if (_hovered && !widget.quitada && !widget.seleccionando)
                Positioned(
                  top: 6,
                  right: 6,
                  child: _ColeccionBotonCubierta(
                    key: ValueKey('coleccion-anadir-${obra.id}'),
                    tooltip: 'Añadir a Biblioteca',
                    icon: Icons.add_rounded,
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
    required this.origen,
  });

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
    final visuals = context.visuals;
    final obra = widget.obras[_indice];
    final enBiblioteca = _obraEnBiblioteca(widget.controller, obra);
    const sinCampo = {'Estado', 'Notas', 'Progreso'};
    final fecha = _fechaPrevista(obra);
    final campos = [
      ..._detailFields(obra).where((campo) => !sinCampo.contains(campo.$1)),
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
                              if (obra.note?.isNotEmpty == true) ...[
                                Text(
                                  obra.note!,
                                  key:
                                      const ValueKey('coleccion-obra-sinopsis'),
                                  style: TextStyle(
                                    color: visuals.textStrong,
                                    fontSize: 15,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                              _LibraryDetailLine(
                                label: 'Estado',
                                value: '',
                                valueWidget: _ColeccionEstadoSelector(
                                  estado: enBiblioteca?.status,
                                  onSelected: (estado) =>
                                      widget.onEstado(obra, estado),
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final campo in campos) ...[
                                _LibraryDetailLine(
                                  label: campo.$1,
                                  value: campo.$2,
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
  });

  final LibraryItemStatus? estado;
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
                  Text(_libraryStatusSingularLabel(opcion)),
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
          padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
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
                estado == null
                    ? 'Sin añadir'
                    : _libraryStatusSingularLabel(estado!),
                style: TextStyle(
                  color: colores.$2,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(Icons.arrow_drop_down_rounded, color: colores.$2),
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

/// Lista de todas las colecciones, también las que no tienen nada en la
/// Biblioteca y por eso no tienen chapa desde la que abrirlas.
Future<void> _mostrarBuscadorColecciones(
  BuildContext context,
  TodoWorkspace controller,
) async {
  await _cargarColecciones();
  if (!context.mounted) return;
  final elegida = await showDialog<Coleccion>(
    context: context,
    builder: (context) => _BuscadorColecciones(controller: controller),
  );
  if (elegida != null && context.mounted) {
    await _abrirColeccion(context, controller, elegida);
  }
}

class _BuscadorColecciones extends StatefulWidget {
  const _BuscadorColecciones({required this.controller});

  final TodoWorkspace controller;

  @override
  State<_BuscadorColecciones> createState() => _BuscadorColeccionesState();
}

class _BuscadorColeccionesState extends State<_BuscadorColecciones> {
  String _texto = '';

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final buscado = _texto.paraBuscar;
    final lista = (_colecciones ?? const <Coleccion>[])
        .where((c) =>
            buscado.isEmpty ||
            c.nombres.any((n) => n.paraBuscar.contains(buscado)) ||
            c.obras.any((o) => o.title.paraBuscar.contains(buscado)))
        .toList();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: min(760, MediaQuery.sizeOf(context).height - 60),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Colecciones',
                style: TextStyle(
                  color: visuals.textStrong,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('colecciones-buscar'),
                autofocus: true,
                onChanged: (valor) => setState(() => _texto = valor),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Buscar saga u obra',
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final coleccion = lista[i];
                    final obras = coleccion.obras;
                    final tengo = obras
                        .where((o) =>
                            _obraEnBiblioteca(widget.controller, o) != null)
                        .length;
                    return Material(
                      color: visuals.panel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: visuals.panelBorder),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('colecciones-${coleccion.id}'),
                        onTap: () => Navigator.of(context).pop(coleccion),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              for (final obra in obras.take(4)) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    width: 34,
                                    height: 50,
                                    child: _LibraryCoverImage(
                                      source: obra.coverUrl,
                                      type: obra.type,
                                      iconSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      coleccion.nombre,
                                      style: TextStyle(
                                        color: visuals.textStrong,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${obras.length} obras · $tengo en tu Biblioteca',
                                      style: TextStyle(
                                        color: visuals.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: visuals.textMuted),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
