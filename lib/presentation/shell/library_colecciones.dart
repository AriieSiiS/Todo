part of 'app_shell.dart';

const _rutaCatalogoColecciones = 'assets/colecciones/colecciones.json';

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

String _resumenColeccion(TodoWorkspace controller, Coleccion coleccion) {
  final obras = coleccion.obras;
  final tipos = obras.map((obra) => obra.type).toSet();
  final nombre = tipos.length == 1
      ? _libraryTypePluralLabel(tipos.first).toLowerCase()
      : 'obras';
  final enBiblioteca =
      obras.where((obra) => _obraEnBiblioteca(controller, obra) != null).length;
  return '${obras.length} $nombre · $enBiblioteca en tu Biblioteca';
}

/// Sagas del catálogo. Sus obras solo entran en la Biblioteca al añadirlas.
class _LibraryCollectionsView extends StatefulWidget {
  const _LibraryCollectionsView({required this.controller});

  final TodoWorkspace controller;

  @override
  State<_LibraryCollectionsView> createState() =>
      _LibraryCollectionsViewState();
}

class _LibraryCollectionsViewState extends State<_LibraryCollectionsView> {
  List<Coleccion>? _colecciones;
  Coleccion? _abierta;

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
  }

  Future<void> _cargar() async {
    final texto = await rootBundle.loadString(_rutaCatalogoColecciones);
    if (mounted) setState(() => _colecciones = Coleccion.desdeJson(texto));
  }

  @override
  Widget build(BuildContext context) {
    final colecciones = _colecciones;
    if (colecciones == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final abierta = _abierta;
        if (abierta != null) {
          return _ColeccionDetalle(
            controller: widget.controller,
            coleccion: abierta,
            onBack: () => setState(() => _abierta = null),
          );
        }
        return SingleChildScrollView(
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              for (final coleccion in colecciones)
                _ColeccionTarjeta(
                  coleccion: coleccion,
                  resumen: _resumenColeccion(widget.controller, coleccion),
                  onTap: () => setState(() => _abierta = coleccion),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ColeccionTarjeta extends StatelessWidget {
  const _ColeccionTarjeta({
    required this.coleccion,
    required this.resumen,
    required this.onTap,
  });

  final Coleccion coleccion;
  final String resumen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return SizedBox(
      key: ValueKey('coleccion-${coleccion.id}'),
      width: 470,
      child: Material(
        color: visuals.panel,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: visuals.panelBorder),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 141,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final portada in coleccion.portadas)
                      Expanded(
                        child: _LibraryCoverImage(
                          source: portada,
                          type: coleccion.obras.first.type,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coleccion.nombre,
                      style: TextStyle(
                        color: visuals.textStrong,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resumen,
                      style: TextStyle(
                        color: visuals.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColeccionDetalle extends StatefulWidget {
  const _ColeccionDetalle({
    required this.controller,
    required this.coleccion,
    required this.onBack,
  });

  final TodoWorkspace controller;
  final Coleccion coleccion;
  final VoidCallback onBack;

  @override
  State<_ColeccionDetalle> createState() => _ColeccionDetalleState();
}

class _ColeccionDetalleState extends State<_ColeccionDetalle> {
  final _anadiendo = <String>{};

  Future<void> _anadir(LibraryItem obra) async {
    if (!_anadiendo.add(obra.id)) return;
    try {
      await _anadirObraABiblioteca(widget.controller, obra);
    } finally {
      _anadiendo.remove(obra.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final coleccion = widget.coleccion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 6),
            IconButton(
              key: const ValueKey('coleccion-volver'),
              tooltip: 'Volver a Colecciones',
              onPressed: widget.onBack,
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
                    _resumenColeccion(widget.controller, coleccion),
                    style: TextStyle(
                      color: visuals.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
                for (final grupo in coleccion.grupos) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
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
                          obra: obra,
                          enBiblioteca:
                              _obraEnBiblioteca(widget.controller, obra),
                          onTap: () => _mostrarObraColeccion(
                            context,
                            widget.controller,
                            coleccion.obras,
                            obra,
                            _anadir,
                          ),
                          onAdd: () => _anadir(obra),
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
    required this.obra,
    required this.enBiblioteca,
    required this.onTap,
    required this.onAdd,
  });

  final LibraryItem obra;
  final LibraryItem? enBiblioteca;
  final VoidCallback onTap;
  final VoidCallback onAdd;

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
                bottom: 44,
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
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
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
              if (enBiblioteca != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _LibraryStatusBadge(status: enBiblioteca.status),
                )
              else if (_hovered)
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filled(
                    key: ValueKey('coleccion-anadir-${obra.id}'),
                    tooltip: 'Añadir a Biblioteca',
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF607A4D),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _mostrarObraColeccion(
  BuildContext context,
  TodoWorkspace controller,
  List<LibraryItem> obras,
  LibraryItem obra,
  Future<void> Function(LibraryItem obra) onAdd,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => ListenableBuilder(
      listenable: controller,
      builder: (dialogContext, _) => _ColeccionObraDialog(
        controller: controller,
        obras: obras,
        inicial: obras.indexOf(obra),
        onAdd: onAdd,
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
    required this.onAdd,
    required this.origen,
  });

  final TodoWorkspace controller;
  final List<LibraryItem> obras;
  final int inicial;
  final Future<void> Function(LibraryItem obra) onAdd;

  /// Contexto de la página, para abrir la ficha tras cerrar este diálogo.
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
    final campos = _detailFields(obra)
        .where((campo) => campo.$1 != 'Estado' && campo.$1 != 'Notas')
        .toList();
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
