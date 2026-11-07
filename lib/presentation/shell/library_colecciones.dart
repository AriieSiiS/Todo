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
  LibraryItem obra,
) async {
  final portada = await rootBundle.load(obra.coverUrl!);
  final coverUrl = await _copyLibraryCoverBytes(portada.buffer.asUint8List());
  if (_obraEnBiblioteca(controller, obra) != null) return;
  controller.createLibraryItem(
    type: obra.type,
    title: obra.title,
    status: LibraryItemStatus.pending,
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

  Future<void> _anadir(LibraryItem obra) async {
    if (!_anadiendo.add(obra.id)) return;
    try {
      await _anadirObraABiblioteca(controller, obra);
    } finally {
      _anadiendo.remove(obra.id);
    }
  }

  String _resumen(List<LibraryItem> obras) {
    final tipos = obras.map((obra) => obra.type).toSet();
    final nombre = tipos.length == 1
        ? _libraryTypePluralLabel(tipos.first).toLowerCase()
        : 'obras';
    final enBiblioteca = obras
        .where((obra) => _obraEnBiblioteca(controller, obra) != null)
        .length;
    return '${obras.length} $nombre · $enBiblioteca en tu Biblioteca';
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final coleccion = widget.coleccion;
    final quitadas = coleccion.obras.where(_quitada).toList();
    final verQuitadas = _verQuitadas && quitadas.isNotEmpty;
    final grupos = [
      for (final grupo in coleccion.grupos)
        GrupoColeccion(
          nombre: grupo.nombre,
          obras: grupo.obras
              .where((obra) => _quitada(obra) == verQuitadas)
              .toList(),
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
                ],
              ),
            ),
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
                            onTap: () => _mostrarObraColeccion(
                              context,
                              controller,
                              obras,
                              obra,
                              verQuitadas,
                              _anadir,
                              _alternar,
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
    required this.onTap,
    required this.onAdd,
    required this.onToggle,
  });

  final LibraryItem obra;
  final bool quitada;
  final LibraryItem? enBiblioteca;
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
    final completada = enBiblioteca?.status == LibraryItemStatus.completed;
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
          foregroundDecoration: completada
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFF5F7F49), width: 4),
                )
              : null,
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
              if (_hovered)
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
              else if (_hovered && !widget.quitada)
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
    required this.origen,
  });

  final TodoWorkspace controller;
  final List<LibraryItem> obras;
  final int inicial;
  final bool quitada;
  final Future<void> Function(LibraryItem obra) onAdd;
  final void Function(LibraryItem obra) onToggle;

  /// Contexto de la colección, para abrir la ficha tras cerrar este diálogo.
  final BuildContext origen;

  @override
  State<_ColeccionObraDialog> createState() => _ColeccionObraDialogState();
}

class _ColeccionObraDialogState extends State<_ColeccionObraDialog> {
  late int _indice = widget.inicial;

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
    final campos =
        _detailFields(obra).where((campo) => !sinCampo.contains(campo.$1));
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                              key: const ValueKey('coleccion-obra-sinopsis'),
                              style: TextStyle(
                                color: visuals.textStrong,
                                fontSize: 15,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          for (final campo in campos) ...[
                            _LibraryDetailLine(
                              label: campo.$1,
                              value: campo.$2,
                            ),
                            const SizedBox(height: 6),
                          ],
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
    );
  }
}
