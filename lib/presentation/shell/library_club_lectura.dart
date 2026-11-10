part of 'app_shell.dart';

/// Abre el club de lectura: los libros de cada club con la fecha de su sesión.
Future<void> _showReadingClubDialog(
    BuildContext context, TodoWorkspace controller) {
  return showDialog<void>(
    context: context,
    builder: (_) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _ReadingClubDialog(controller: controller),
    ),
  );
}

DateTime _soloDia(DateTime fecha) =>
    DateTime(fecha.year, fecha.month, fecha.day);

/// «jueves, 14 de enero de 2027».
String _fechaSesionClub(DateTime fecha) =>
    '${_fechaConDia(fecha)} de ${fecha.year}';

/// Clubs con sus sesiones ordenadas por fecha; los clubs, por su primera
/// sesión.
List<({String club, List<ReadingClubMeeting> sesiones})> _clubsOrdenados(
    List<ReadingClubMeeting> sesiones) {
  final porClub = <String, List<ReadingClubMeeting>>{};
  for (final sesion in sesiones) {
    porClub.putIfAbsent(sesion.club, () => []).add(sesion);
  }
  final clubs = [
    for (final entrada in porClub.entries)
      (
        club: entrada.key,
        sesiones: entrada.value..sort((a, b) => a.date.compareTo(b.date)),
      ),
  ]..sort((a, b) {
      final porFecha = a.sesiones.first.date.compareTo(b.sesiones.first.date);
      return porFecha != 0
          ? porFecha
          : a.club.paraBuscar.compareTo(b.club.paraBuscar);
    });
  return clubs;
}

/// Libro de la sesión: la ficha de Biblioteca si ya se añadió y, si no, la
/// guardada en el propio club.
LibraryItem? _libroDeSesion(
    ReadingClubMeeting sesion, Map<String, LibraryItem> libros) {
  final enBiblioteca = libros[sesion.bookId];
  if (enBiblioteca != null) return enBiblioteca;
  final ficha = sesion.book;
  if (ficha == null) return null;
  try {
    return LibraryItem.fromJson({...ficha, 'id': sesion.bookId});
  } catch (_) {
    return null;
  }
}

class _ReadingClubDialog extends StatelessWidget {
  const _ReadingClubDialog({required this.controller});

  final TodoWorkspace controller;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final theme = Theme.of(context);
    final sesiones = controller.visibilitySettings.readingClubMeetings;
    final clubs = _clubsOrdenados(sesiones);
    final libros = {
      for (final item in controller.libraryItems)
        if (item.type == LibraryItemType.book) item.id: item,
    };
    final hoy = _soloDia(DateTime.now());
    final proximas = sesiones.where((s) => !s.date.isBefore(hoy)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final proxima = proximas.isEmpty ? null : proximas.first;
    final libroProximo =
        proxima == null ? null : _libroDeSesion(proxima, libros);
    final porFecha = controller.visibilitySettings.readingClubByDate;
    final cronologicas = [...sesiones]
      ..sort((a, b) => a.date.compareTo(b.date));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      // Alto fijo: la ventana no cambia de tamaño al pasar de la vista por
      // clubes a la vista por fecha.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1260,
          minHeight: min(990, MediaQuery.sizeOf(context).height - 48),
          maxHeight: min(990, MediaQuery.sizeOf(context).height - 48),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.groups_outlined, color: visuals.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Club de lectura',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      if (proxima != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Próxima sesión: ${_fechaSesionClub(proxima.date)}'
                            ' · ${libroProximo?.title ?? 'Libro no encontrado'}'
                            ' · ${proxima.club}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: visuals.textMuted, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<bool>(
                  key: const ValueKey('club-orden'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.grid_view_rounded, size: 18),
                      label: Text('Por clubes'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.event_note_outlined, size: 18),
                      label: Text('Por fecha'),
                    ),
                  ],
                  selected: {porFecha},
                  onSelectionChanged: (valor) =>
                      controller.setReadingClubByDate(valor.first),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  key: const ValueKey('club-anadir'),
                  onPressed: () => _editarSesionClub(context, controller),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Añadir libro'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Cerrar club de lectura',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
              const SizedBox(height: 18),
              Expanded(
                child: clubs.isEmpty
                    ? Center(
                        child: Text(
                          'Todavía no hay libros en el club de lectura.',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: visuals.textMuted),
                        ),
                      )
                    : porFecha
                        ? LayoutBuilder(builder: (context, constraints) {
                            // Todos los libros en orden de fecha, con el mismo
                            // tamaño de tarjeta que en la vista por clubes.
                            const separacion = 12.0;
                            final columnas = (constraints.maxWidth / 190)
                                .floor()
                                .clamp(1, 6);
                            final ancho = (constraints.maxWidth -
                                    separacion * (columnas - 1)) /
                                columnas;
                            return SingleChildScrollView(
                              child: Wrap(
                                spacing: separacion,
                                runSpacing: separacion,
                                children: [
                                  for (final sesion in cronologicas)
                                    SizedBox(
                                      width: ancho,
                                      child: _ReadingClubSessionCard(
                                        controller: controller,
                                        sesion: sesion,
                                        libro: _libroDeSesion(sesion, libros),
                                        enBiblioteca:
                                            libros.containsKey(sesion.bookId),
                                        libros: libros.values.toList(),
                                        pasada: sesion.date.isBefore(hoy),
                                        proxima: sesion.id == proxima?.id,
                                        mostrarClub: true,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          })
                        : LayoutBuilder(builder: (context, constraints) {
                            // Dos clubs por fila: cada uno tiene ancho para
                            // poner sus libros en paralelo con portadas grandes.
                            const separacion = 14.0;
                            final columnas =
                                constraints.maxWidth >= 900 ? 2 : 1;
                            final ancho = (constraints.maxWidth -
                                    separacion * (columnas - 1)) /
                                columnas;
                            return SingleChildScrollView(
                              child: Wrap(
                                spacing: separacion,
                                runSpacing: separacion,
                                children: [
                                  for (final club in clubs)
                                    SizedBox(
                                      width: ancho,
                                      child: _ReadingClubColumn(
                                        controller: controller,
                                        club: club.club,
                                        sesiones: club.sesiones,
                                        libros: libros,
                                        hoy: hoy,
                                        proximaId: proxima?.id,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingClubColumn extends StatelessWidget {
  const _ReadingClubColumn({
    required this.controller,
    required this.club,
    required this.sesiones,
    required this.libros,
    required this.hoy,
    required this.proximaId,
  });

  final TodoWorkspace controller;
  final String club;
  final List<ReadingClubMeeting> sesiones;
  final Map<String, LibraryItem> libros;
  final DateTime hoy;
  final String? proximaId;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: visuals.accent.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: visuals.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 28,
            child: Row(children: [
              Expanded(
                child: Text(
                  club,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: visuals.textStrong,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${sesiones.length} ${sesiones.length == 1 ? 'libro' : 'libros'}',
                style: TextStyle(color: visuals.textMuted, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          // Los libros del club van en paralelo, de tres en tres, en orden
          // de fecha de izquierda a derecha.
          for (var inicio = 0; inicio < sesiones.length; inicio += 3) ...[
            if (inicio > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var hueco = 0; hueco < 3; hueco++) ...[
                  if (hueco > 0) const SizedBox(width: 12),
                  Expanded(
                    child: inicio + hueco < sesiones.length
                        ? _ReadingClubSessionCard(
                            controller: controller,
                            sesion: sesiones[inicio + hueco],
                            libro: _libroDeSesion(
                                sesiones[inicio + hueco], libros),
                            enBiblioteca: libros
                                .containsKey(sesiones[inicio + hueco].bookId),
                            libros: libros.values.toList(),
                            pasada: sesiones[inicio + hueco].date.isBefore(hoy),
                            proxima: sesiones[inicio + hueco].id == proximaId,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadingClubSessionCard extends StatelessWidget {
  const _ReadingClubSessionCard({
    required this.controller,
    required this.sesion,
    required this.libro,
    required this.enBiblioteca,
    required this.libros,
    required this.pasada,
    required this.proxima,
    this.mostrarClub = false,
  });

  /// En la vista por fecha, cada tarjeta dice a qué club pertenece.
  final bool mostrarClub;
  final TodoWorkspace controller;
  final ReadingClubMeeting sesion;
  final LibraryItem? libro;

  /// El libro ya se añadió a Biblioteca con algún estado.
  final bool enBiblioteca;
  final List<LibraryItem> libros;
  final bool pasada;
  final bool proxima;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    final colors = Theme.of(context).colorScheme;
    final libro = this.libro;
    Future<void> abrirMenu(Offset posicion) => _menuSesionClub(
        context, controller, sesion, libro, enBiblioteca, libros, posicion);
    final menu = Builder(
      builder: (contextoBoton) => InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          final caja = contextoBoton.findRenderObject() as RenderBox;
          abrirMenu(caja.localToGlobal(caja.size.bottomLeft(Offset.zero)));
        },
        child: Tooltip(
          message: 'Opciones del libro',
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(Icons.more_vert_rounded,
                size: 20, color: visuals.textMuted),
          ),
        ),
      ),
    );
    final tarjeta = Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        color: visuals.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: proxima ? visuals.accent : visuals.panelBorder,
          width: proxima ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fecha grande, como la hoja de un calendario: se lee de un vistazo.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${sesion.date.day}',
                style: TextStyle(
                  color: visuals.accent,
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _mesesCompletos[sesion.date.month - 1].toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: visuals.accent,
                        fontSize: 12,
                        letterSpacing: .8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _capitalizar(_diasCompletos[sesion.date.weekday - 1]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: visuals.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              menu,
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 128,
                height: 192,
                child: _LibraryCoverImage(
                  source: libro?.coverUrl,
                  type: LibraryItemType.book,
                  iconSize: 30,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (mostrarClub) ...[
            Text(
              sesion.club.toUpperCase(),
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: visuals.accent,
                fontSize: 11,
                letterSpacing: .6,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
          ],
          SizedBox(
            height: 36,
            child: Text(
              libro?.title ?? 'Libro no encontrado',
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: visuals.textStrong,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          Text(
            libro?.author ?? '',
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: visuals.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 20,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              children: [
                if (proxima)
                  _ReadingClubTag(label: 'Próxima', color: visuals.accent),
                if (sesion.pendingConfirmation)
                  _ReadingClubTag(
                      label: 'Por confirmar', color: colors.tertiary),
                // Solo los libros añadidos a Biblioteca tienen estado.
                if (enBiblioteca && libro != null)
                  _ReadingClubTag(
                    label: _estadoLibroClub(libro.status),
                    color: libro.status == LibraryItemStatus.completed
                        ? visuals.success
                        : visuals.textMuted,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return Opacity(
      opacity: pasada ? .6 : 1,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onSecondaryTapDown: (detalles) => abrirMenu(detalles.globalPosition),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            // En Biblioteca abre su ficha; fuera de ella, las opciones para
            // añadirlo.
            onTapUp: enBiblioteca
                ? null
                : (detalles) => abrirMenu(detalles.globalPosition),
            onTap: libro == null
                ? null
                : enBiblioteca
                    ? () => _showLibraryItemDetails(
                        context, controller, libros, libro)
                    : () {},
            child: tarjeta,
          ),
        ),
      ),
    );
  }
}

String _estadoLibroClub(LibraryItemStatus estado) => switch (estado) {
      LibraryItemStatus.pending => 'Pendiente',
      LibraryItemStatus.inProgress => 'En curso',
      LibraryItemStatus.completed => 'Leído',
    };

/// Menú de un libro del club, con clic derecho o con los tres puntos.
Future<void> _menuSesionClub(
  BuildContext context,
  TodoWorkspace controller,
  ReadingClubMeeting sesion,
  LibraryItem? libro,
  bool enBiblioteca,
  List<LibraryItem> libros,
  Offset posicion,
) async {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  PopupMenuItem<Object> opcion(Object valor, IconData icono, String texto) =>
      PopupMenuItem<Object>(
        value: valor,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icono),
          title: Text(texto),
        ),
      );
  final enlace = libro?.externalUrl;
  final elegido = await showMenu<Object>(
    context: context,
    position: RelativeRect.fromRect(
      posicion & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      if (libro != null && !enBiblioteca) ...[
        opcion(LibraryItemStatus.pending, Icons.bookmark_outline_rounded,
            'Añadir a pendientes'),
        opcion(LibraryItemStatus.inProgress, Icons.play_arrow_rounded,
            'Añadir a en curso'),
        opcion(LibraryItemStatus.completed, Icons.check_circle_outline_rounded,
            'Añadir como leído'),
        const PopupMenuDivider(),
      ],
      if (libro != null && enBiblioteca) ...[
        opcion('ficha', Icons.local_library_outlined, 'Ver en Biblioteca'),
        const PopupMenuDivider(),
      ],
      if (enlace != null && enlace.isNotEmpty)
        opcion('enlace', Icons.open_in_new_rounded, 'Abrir en Goodreads'),
      opcion('editar', Icons.edit_outlined, 'Editar sesión'),
      opcion('quitar', Icons.remove_circle_outline_rounded, 'Quitar del club'),
    ],
  );
  if (elegido == null || !context.mounted) return;
  if (elegido is LibraryItemStatus && libro != null) {
    _anadirLibroClubABiblioteca(controller, sesion, libro, elegido);
  } else if (elegido == 'ficha' && libro != null) {
    await _showLibraryItemDetails(context, controller, libros, libro);
  } else if (elegido == 'enlace' && enlace != null) {
    await launchUrl(Uri.parse(enlace), mode: LaunchMode.externalApplication);
  } else if (elegido == 'editar') {
    await _editarSesionClub(context, controller, sesion: sesion);
  } else if (elegido == 'quitar') {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar del club'),
        content: Text('¿Quieres quitar «${libro?.title ?? 'este libro'}» de '
            '${sesion.club}?${enBiblioteca ? ' La ficha seguirá en Biblioteca.' : ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmado == true) controller.deleteReadingClubMeeting(sesion.id);
  }
}

/// Crea en Biblioteca la ficha de un libro del club con el estado elegido y
/// enlaza la sesión con ella. La ficha del club se conserva por si luego se
/// borra de Biblioteca.
void _anadirLibroClubABiblioteca(
  TodoWorkspace controller,
  ReadingClubMeeting sesion,
  LibraryItem libro,
  LibraryItemStatus estado,
) {
  final creado = controller.createLibraryItem(
    type: LibraryItemType.book,
    title: libro.title,
    status: estado,
    coverUrl: libro.coverUrl,
    externalUrl: libro.externalUrl,
    note: libro.note,
    author: libro.author,
    releaseYear: libro.releaseYear,
    creatorOrDirector: libro.creatorOrDirector,
    genre: libro.genre,
    format: libro.format,
    pages: libro.pages,
    country: libro.country,
    universeName: libro.universeName,
    collectionName: libro.collectionName,
    collectionNumber: libro.collectionNumber,
    showCollectionNumber: libro.showCollectionNumber,
  );
  controller.saveReadingClubMeeting(sesion.copyWith(
    bookId: creado.id,
    book: sesion.book ?? libro.toJson(),
  ));
}

class _ReadingClubTag extends StatelessWidget {
  const _ReadingClubTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Añade un libro de Biblioteca a un club, o cambia una sesión existente.
Future<void> _editarSesionClub(BuildContext context, TodoWorkspace controller,
    {ReadingClubMeeting? sesion}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _ReadingClubMeetingDialog(controller: controller, sesion: sesion),
  );
}

class _ReadingClubMeetingDialog extends StatefulWidget {
  const _ReadingClubMeetingDialog({required this.controller, this.sesion});

  final TodoWorkspace controller;
  final ReadingClubMeeting? sesion;

  @override
  State<_ReadingClubMeetingDialog> createState() =>
      _ReadingClubMeetingDialogState();
}

class _ReadingClubMeetingDialogState extends State<_ReadingClubMeetingDialog> {
  late final TextEditingController _club;
  LibraryItem? _libro;
  DateTime? _fecha;
  bool _pendiente = false;

  @override
  void initState() {
    super.initState();
    final sesion = widget.sesion;
    _club = TextEditingController(text: sesion?.club ?? '');
    _fecha = sesion?.date;
    _pendiente = sesion?.pendingConfirmation ?? false;
    _libro = sesion == null
        ? null
        : _libroDeSesion(sesion, {
            for (final item in widget.controller.libraryItems) item.id: item,
          });
  }

  @override
  void dispose() {
    _club.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libros = widget.controller.libraryItems
        .where((item) => item.type == LibraryItemType.book)
        .toList()
      ..sort((a, b) => a.title.paraBuscar.compareTo(b.title.paraBuscar));
    final clubs = {
      for (final sesion
          in widget.controller.visibilitySettings.readingClubMeetings)
        sesion.club,
    }.toList()
      ..sort((a, b) => a.paraBuscar.compareTo(b.paraBuscar));
    final valido =
        _libro != null && _club.text.trim().isNotEmpty && _fecha != null;

    return AlertDialog(
      title: Text(widget.sesion == null ? 'Añadir al club' : 'Editar sesión'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Autocomplete<LibraryItem>(
              initialValue: TextEditingValue(text: _libro?.title ?? ''),
              displayStringForOption: (item) => item.title,
              optionsBuilder: (valor) {
                final consulta = valor.text.trim().paraBuscar;
                return libros.where((item) =>
                    consulta.isEmpty ||
                    '${item.title} ${item.author ?? ''}'
                        .paraBuscar
                        .contains(consulta));
              },
              onSelected: (item) => setState(() => _libro = item),
              fieldViewBuilder: (context, texto, foco, enviar) => TextField(
                controller: texto,
                focusNode: foco,
                decoration: const InputDecoration(
                  labelText: 'Libro de Biblioteca',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
                onChanged: (valor) {
                  if (_libro != null && valor != _libro!.title) {
                    setState(() => _libro = null);
                  }
                },
              ),
            ),
            const SizedBox(height: 14),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _club.text),
              optionsBuilder: (valor) => clubs.where((club) =>
                  club.paraBuscar.contains(valor.text.trim().paraBuscar)),
              onSelected: (club) => setState(() => _club.text = club),
              fieldViewBuilder: (context, texto, foco, enviar) => TextField(
                controller: texto,
                focusNode: foco,
                decoration: const InputDecoration(
                  labelText: 'Club',
                  hintText: 'Por ejemplo, Novela negra',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                onChanged: (valor) => setState(() => _club.text = valor),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.event_outlined),
              label: Text(_fecha == null
                  ? 'Elegir fecha de la sesión'
                  : _fechaSesionClub(_fecha!)),
              onPressed: () async {
                final ahora = DateTime.now();
                final elegida = await showDatePicker(
                  context: context,
                  initialDate: _fecha ?? ahora,
                  firstDate: DateTime(ahora.year - 5),
                  lastDate: DateTime(ahora.year + 5, 12, 31),
                );
                if (elegida != null) setState(() => _fecha = elegida);
              },
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Pendiente de confirmar'),
              value: _pendiente,
              onChanged: (valor) => setState(() => _pendiente = valor ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: !valido
              ? null
              : () {
                  final base = widget.sesion ??
                      ReadingClubMeeting(
                        id: 'club-${DateTime.now().microsecondsSinceEpoch}',
                        bookId: _libro!.id,
                        club: _club.text.trim(),
                        date: _soloDia(_fecha!),
                      );
                  widget.controller.saveReadingClubMeeting(base.copyWith(
                    bookId: _libro!.id,
                    club: _club.text.trim(),
                    date: _soloDia(_fecha!),
                    pendingConfirmation: _pendiente,
                  ));
                  Navigator.of(context).pop();
                },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
