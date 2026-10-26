part of 'app_shell.dart';

class _LibraryTypeListDialog extends StatelessWidget {
  const _LibraryTypeListDialog({
    required this.controller,
    required this.type,
    required this.items,
    required this.status,
    required this.showStatus,
  });

  final TodoWorkspace controller;
  final LibraryItemType type;
  final List<LibraryItem> items;
  final LibraryItemStatus? status;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((left, right) => _compareLibraryItems(
          left,
          right,
          status == LibraryItemStatus.completed
              ? LibrarySortOrder.newestFirst
              : LibrarySortOrder.titleAsc,
        ));
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 18, 16),
              child: Row(
                children: [
                  Icon(_libraryIcon(type), color: _libraryColor(type)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _libraryTypePluralLabel(type),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _miniBadge(
                    '${sorted.length} ${_libraryStatusCountLabel(status, sorted.length)}',
                    _libraryColor(type).withValues(alpha: 0.12),
                    _libraryColor(type),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: sorted.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          _libraryEmptyStatusText(status),
                          style: TextStyle(color: context.visuals.textMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sorted.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = sorted[index];
                        return _LibraryItemRow(
                          item: item,
                          controller: controller,
                          showStatus: showStatus,
                          onTap: () async {
                            await _showLibraryItemDetails(
                              context,
                              controller,
                              items,
                              item,
                            );
                          },
                          onEdit: () => showDialog<void>(
                            context: context,
                            builder: (context) => _LibraryItemDialog(
                              controller: controller,
                              item: item,
                            ),
                          ),
                          onDelete: () => _deleteItem(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, LibraryItem item) async {
    final confirmed = await _confirmLibraryDelete(
      context,
      title: 'Borrar de la biblioteca',
      message: _libraryDeleteMessage(controller, item),
    );
    if (confirmed) {
      controller.deleteLibraryItem(item.id);
    }
  }
}

class _LibrarySidePanel extends StatefulWidget {
  const _LibrarySidePanel({
    required this.controller,
    required this.items,
    required this.year,
  });

  final TodoWorkspace controller;
  final List<LibraryItem> items;
  final int year;

  @override
  State<_LibrarySidePanel> createState() => _LibrarySidePanelState();
}

class _LibrarySidePanelState extends State<_LibrarySidePanel> {
  bool _showAllRecent = false;
  bool _showAllYears = false;
  TodoWorkspace get controller => widget.controller;
  List<LibraryItem> get items => widget.items;
  int get year => widget.year;

  @override
  Widget build(BuildContext context) {
    final recent = [...items]..sort((left, right) =>
        (right.completedDate ?? right.updatedAt)
            .compareTo(left.completedDate ?? left.updatedAt));
    final yearCounts = <int, int>{};
    for (final item in items) {
      final itemYear = item.yearGroup;
      if (itemYear != null) {
        yearCounts[itemYear] = (yearCounts[itemYear] ?? 0) + 1;
      }
    }
    final years = yearCounts.keys.toList()..sort((a, b) => b.compareTo(a));
    final yearItems = items.where((item) => item.yearGroup == year).toList();

    return Column(
      children: [
        _SurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                Text(
                  'No hay elementos recientes.',
                  style: TextStyle(color: context.visuals.textMuted),
                )
              else
                for (final item
                    in recent.take(_showAllRecent ? recent.length : 4))
                  GestureDetector(
                    onSecondaryTapDown: (details) => _showLibraryContextMenu(
                      context: context,
                      position: details.globalPosition,
                      onPages: () =>
                          _openKnowledgeWorkspace(context, controller, item),
                      onRating: item.status != LibraryItemStatus.completed
                          ? null
                          : () => _editLibraryRating(context, controller, item),
                      onEdit: () => _editItem(context, item),
                      onDelete: () => _deleteItem(context, item),
                    ),
                    child: InkWell(
                      onTap: () => _showLibraryItemDetails(
                        context,
                        controller,
                        items,
                        item,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LibraryThumbnail(item: item, small: true),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Text(_libraryTypeSingularLabel(item),
                                          style: TextStyle(
                                              color: context.visuals.textMuted,
                                              fontSize: 12)),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: _libraryColor(item.type),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.reading == null
                                              ? _libraryItemStatusMeta(item)
                                              : '${item.reading!.percent} % · ${_libraryItemStatusMeta(item)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            color: context.visuals.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              if (recent.length > 4)
                _LibrarySideLink(
                  label: _showAllRecent
                      ? 'Ver menos recientes'
                      : 'Ver todos los recientes',
                  onTap: () => setState(() => _showAllRecent = !_showAllRecent),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Años',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Explora tu biblioteca por año',
                  style: TextStyle(color: context.visuals.textMuted)),
              const SizedBox(height: 8),
              if (years.isEmpty)
                Text(
                  'Aún no hay años registrados.',
                  style: TextStyle(color: context.visuals.textMuted),
                )
              else
                for (final value
                    in years.take(_showAllYears ? years.length : 3))
                  Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: value == year
                          ? const Color(0xFFE8F1DD)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text('$value')),
                        Text('${yearCounts[value]}'),
                      ],
                    ),
                  ),
              if (years.length > 3)
                _LibrarySideLink(
                  label:
                      _showAllYears ? 'Ver menos años' : 'Ver todos los años',
                  onTap: () => setState(() => _showAllYears = !_showAllYears),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _LibraryTotalsSideCard(items: yearItems, year: year),
      ],
    );
  }

  Future<void> _editItem(BuildContext context, LibraryItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _LibraryItemDialog(
        controller: controller,
        item: item,
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, LibraryItem item) async {
    final confirmed = await _confirmLibraryDelete(
      context,
      title: 'Borrar de la biblioteca',
      message: _libraryDeleteMessage(controller, item),
    );
    if (confirmed) {
      controller.deleteLibraryItem(item.id);
    }
  }
}

class _LibraryTotalsSideCard extends StatelessWidget {
  const _LibraryTotalsSideCard({required this.items, required this.year});

  final List<LibraryItem> items;
  final int year;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Totales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Resumen de completados en $year',
              style: TextStyle(color: context.visuals.textMuted)),
          const SizedBox(height: 10),
          _LibraryTotalRow(
            icon: Icons.bookmarks_outlined,
            color: const Color(0xFF7E9BB4),
            label: 'Total completados',
            value: items.length,
          ),
          const Divider(height: 12),
          for (final type in LibraryItemType.values)
            _LibraryTotalRow(
              icon: _libraryIcon(type),
              color: _libraryColor(type),
              label: _libraryTypePluralLabel(type),
              value: items.where((item) => item.type == type).length,
            ),
        ],
      ),
    );
  }
}

class _LibraryTotalRow extends StatelessWidget {
  const _LibraryTotalRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LibrarySideLink extends StatelessWidget {
  const _LibrarySideLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(color: context.visuals.textMuted)),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

Future<void> _openKnowledgeWorkspace(
  BuildContext context,
  TodoWorkspace controller,
  LibraryItem item,
) {
  controller.openKnowledgeWorkspace(item);
  return Future<void>.value();
}

/// Opciones de «Añadir…» de la vista de Biblioteca actual. El menú de un
/// elemento las muestra después de sus propias acciones, en un único menú.
class _LibraryAddMenuRequest {
  const _LibraryAddMenuRequest({
    required this.controller,
    required this.types,
    required this.status,
  });

  final TodoWorkspace controller;
  final List<LibraryItemType> types;
  final LibraryItemStatus? status;
}

_LibraryAddMenuRequest? _libraryAddMenuContext;

/// Instante del último menú de elemento, para que el fondo no abra otro encima.
DateTime _libraryItemMenuAt = DateTime.fromMillisecondsSinceEpoch(0);

_LibraryAddMenuRequest _libraryAddMenuRequest({
  required TodoWorkspace controller,
  required LibraryItemType? selectedType,
  required LibraryItemStatus? status,
}) {
  return _LibraryAddMenuRequest(
    controller: controller,
    types: selectedType == null
        ? LibraryItemType.values
        : <LibraryItemType>[selectedType],
    status: status,
  );
}

Future<void> _editLibraryRating(
  BuildContext context,
  TodoWorkspace controller,
  LibraryItem item,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LibraryItemDialog(
      controller: controller,
      item: item,
      focusRating: true,
    ),
  );
}

Future<void> _promptCompletedBookRating(
  BuildContext context,
  TodoWorkspace controller,
  String itemId,
) async {
  LibraryItem? currentItem() {
    for (final item in controller.libraryItems) {
      if (item.id == itemId) return item;
    }
    return null;
  }

  final item = currentItem();
  if (!context.mounted ||
      item == null ||
      item.type != LibraryItemType.book ||
      item.status != LibraryItemStatus.completed ||
      item.rating != null) {
    return;
  }
  final rating = await showDialog<double>(
    context: context,
    builder: (context) => _BookRatingDialog(title: item.title),
  );
  if (rating == null) return;
  final current = currentItem();
  if (current != null &&
      current.status == LibraryItemStatus.completed &&
      current.rating == null) {
    controller.updateLibraryItem(current.copyWith(rating: rating));
  }
}

void _toggleLibraryGoalCompleted(
  BuildContext context,
  TodoWorkspace controller,
  String goalId,
) {
  final goal = controller.libraryGoals.firstWhere((goal) => goal.id == goalId);
  controller.toggleLibraryGoalCompleted(goalId);
  if (goal.isCompleted) return;
  for (final item in controller.libraryItems) {
    if (item.linkedGoalId == goalId) {
      unawaited(_promptCompletedBookRating(context, controller, item.id));
      break;
    }
  }
}

List<PopupMenuEntry<Object>> _libraryAddMenuEntries(
  _LibraryAddMenuRequest request,
) {
  return [
    for (final type in request.types)
      PopupMenuItem<Object>(
        value: type,
        child: ListTile(
          dense: true,
          leading: Icon(_libraryIcon(type), color: _libraryColor(type)),
          title: Text(
              'Añadir ${_libraryTypeSingularLabelForType(type).toLowerCase()}'),
        ),
      ),
  ];
}

Future<void> _openLibraryAddDialog(
  BuildContext context,
  _LibraryAddMenuRequest request,
  LibraryItemType type,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LibraryItemDialog(
      controller: request.controller,
      initialType: type,
      initialStatus: request.status ?? LibraryItemStatus.pending,
    ),
  );
}

Future<void> _showLibraryContextMenu({
  required BuildContext context,
  required Offset position,
  VoidCallback? onPages,
  VoidCallback? onComplete,
  VoidCallback? onRating,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) async {
  _libraryItemMenuAt = DateTime.now();
  final addRequest = _libraryAddMenuContext;
  final overlay =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  if (overlay == null) {
    return;
  }
  final action = await showMenu<Object>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      if (onPages != null)
        const PopupMenuItem<Object>(
          value: _LibraryContextAction.pages,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.description_outlined),
            title: Text('Abrir páginas'),
          ),
        ),
      if (onComplete != null)
        const PopupMenuItem<Object>(
          value: _LibraryContextAction.complete,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.check_circle_outline_rounded),
            title: Text('Marcar como completado'),
          ),
        ),
      if (onRating != null)
        const PopupMenuItem<Object>(
          value: _LibraryContextAction.rating,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.star_outline_rounded),
            title: Text('Cambiar/añadir valoración'),
          ),
        ),
      const PopupMenuItem<Object>(
        value: _LibraryContextAction.edit,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.edit_outlined),
          title: Text('Editar'),
        ),
      ),
      const PopupMenuItem<Object>(
        value: _LibraryContextAction.delete,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.delete_outline_rounded),
          title: Text('Borrar'),
        ),
      ),
      if (addRequest != null) ...[
        const PopupMenuDivider(),
        ..._libraryAddMenuEntries(addRequest),
      ],
    ],
  );
  if (action == _LibraryContextAction.pages) {
    onPages?.call();
  } else if (action == _LibraryContextAction.complete) {
    onComplete?.call();
  } else if (action == _LibraryContextAction.rating) {
    onRating?.call();
  } else if (action == _LibraryContextAction.edit) {
    onEdit();
  } else if (action == _LibraryContextAction.delete) {
    onDelete();
  } else if (action is LibraryItemType && addRequest != null) {
    if (!context.mounted) {
      return;
    }
    await _openLibraryAddDialog(context, addRequest, action);
  }
}

Future<void> _showLibraryAddContextMenu({
  required BuildContext context,
  required Offset position,
  required TodoWorkspace controller,
  required LibraryItemType? selectedType,
  required LibraryItemStatus? status,
}) async {
  final request = _libraryAddMenuRequest(
    controller: controller,
    selectedType: selectedType,
    status: status,
  );
  final overlay =
      Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  if (overlay == null) {
    return;
  }
  // Un clic lento sobre un elemento también llega al fondo: si el menú del
  // elemento acaba de abrirse, ya incluye estas opciones.
  await Future<void>.delayed(const Duration(milliseconds: 40));
  if (DateTime.now().difference(_libraryItemMenuAt) <
      const Duration(milliseconds: 400)) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  final type = await showMenu<Object>(
    context: context,
    position: RelativeRect.fromRect(
      position & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: _libraryAddMenuEntries(request),
  );
  if (type is! LibraryItemType || !context.mounted) {
    return;
  }
  await _openLibraryAddDialog(context, request, type);
}

void _completeLibraryItem(
  BuildContext context,
  TodoWorkspace controller,
  LibraryItem item,
) {
  final previousStatus = item.status;
  if (previousStatus == LibraryItemStatus.completed) {
    return;
  }
  controller.updateLibraryItemStatus(item.id, LibraryItemStatus.completed);
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('“${item.title}” marcado como completado.'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => controller.updateLibraryItemStatus(
            item.id,
            previousStatus,
          ),
        ),
      ),
    );
  unawaited(_promptCompletedBookRating(context, controller, item.id));
}

Future<bool> _confirmLibraryDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8F3D35),
                foregroundColor: Colors.white,
              ),
              child: const Text('Borrar'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _showLibraryItemDetails(
  BuildContext context,
  TodoWorkspace controller,
  List<LibraryItem> items,
  LibraryItem item,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _LibraryItemDetailsDialog(
              controller: controller,
              items: items,
              item: item,
            )),
  );
}

class _LibraryItemDetailsDialog extends StatefulWidget {
  const _LibraryItemDetailsDialog({
    required this.controller,
    required this.items,
    required this.item,
  });

  final TodoWorkspace controller;
  final List<LibraryItem> items;
  final LibraryItem item;

  @override
  State<_LibraryItemDetailsDialog> createState() =>
      _LibraryItemDetailsDialogState();
}

class _LibraryItemDetailsDialogState extends State<_LibraryItemDetailsDialog> {
  late int _index;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.items.indexWhere((item) => item.id == widget.item.id);
    if (_index < 0) {
      _index = 0;
    }
  }

  LibraryItem get item {
    if (widget.items.isEmpty) {
      return widget.item;
    }
    final selected = widget.items[_index.clamp(0, widget.items.length - 1)];
    return widget.controller.libraryItems.firstWhere(
      (item) => item.id == selected.id,
      orElse: () => selected,
    );
  }

  static int _lastTab(LibraryItemType type) => switch (type) {
        LibraryItemType.book => 2,
        LibraryItemType.game => 1,
        _ => 0,
      };

  bool get _hasPrevious => widget.items.isNotEmpty && _index > 0;
  bool get _hasNext =>
      widget.items.isNotEmpty && _index < widget.items.length - 1;

  void _moveItem(int delta) => setState(() {
        _index += delta;
        // Conserva la pestaña si el nuevo elemento también la tiene.
        _tab = min(_tab, _lastTab(item.type));
      });

  Future<void> _editQuote(LibraryItem item, Map<String, dynamic> quote) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _BookQuoteEditDialog(
        controller: widget.controller,
        itemId: item.id,
        quote: quote,
      ),
    );
    if (mounted) setState(() {});
  }

  void _changeStatus(LibraryItem item, LibraryItemStatus status) {
    if (item.status == status) return;
    if (status == LibraryItemStatus.completed) {
      _completeLibraryItem(context, widget.controller, item);
    } else {
      widget.controller.updateLibraryItemStatus(item.id, status);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final fields = _detailFields(item);
    final collectionLabels = _libraryCollectionLabels(widget.controller, item);
    return DefaultTabController(
        key: ValueKey(item.type),
        initialIndex: _tab,
        length: item.type == LibraryItemType.book
            ? 3
            : item.type == LibraryItemType.game
                ? 2
                : 1,
        child: Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: 1040,
                maxHeight: min(800, MediaQuery.sizeOf(context).height - 60)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  LayoutBuilder(builder: (context, constraints) {
                    final isBook = item.type == LibraryItemType.book;
                    final isGame = item.type == LibraryItemType.game;
                    final hasTabs = isBook || isGame;
                    final inlineTabs = constraints.maxWidth >= 900;
                    Widget tabs() => _LibraryBookDetailTabs(
                        isGame: isGame,
                        count: item.reading?.quotes.length ?? 0,
                        onTap: (index) => setState(() => _tab = index));
                    return SizedBox(
                      height: inlineTabs ? 96 : 140,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 16, 24, 16),
                        child: Column(children: [
                          Expanded(
                              child: Row(
                            children: [
                              Icon(_libraryIcon(item.type),
                                  color: _libraryColor(item.type), size: 30),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _TextoConAyudaSiRecortado(
                                  texto: item.title,
                                  maxLines: 2,
                                  style: const TextStyle(
                                      fontSize: 23,
                                      height: 1.2,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                              if (collectionLabels != null) ...[
                                const SizedBox(width: 16),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth *
                                        (isBook && inlineTabs ? .18 : .30),
                                  ),
                                  child: Tooltip(
                                    message: collectionLabels.saga,
                                    child: _LibraryCollectionChips(
                                      controller: widget.controller,
                                      item: item,
                                      singleLine: true,
                                    ),
                                  ),
                                ),
                              ],
                              if (hasTabs && inlineTabs) ...[
                                const SizedBox(width: 20),
                                tabs(),
                              ],
                            ],
                          )),
                          if (!inlineTabs) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                                height: 44,
                                child: hasTabs
                                    ? Align(
                                        alignment: Alignment.centerLeft,
                                        child: tabs())
                                    : null),
                          ],
                        ]),
                      ),
                    );
                  }),
                  const Divider(height: 1),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 14, 28, 14),
                      child: LayoutBuilder(
                        builder: (context, constraints) => item.type ==
                                    LibraryItemType.book &&
                                _tab == 1
                            ? BookQuotesPanel(
                                key: ValueKey('library-quotes-${item.id}'),
                                reading: item.reading,
                                onEdit: (quote) => _editQuote(item, quote),
                              )
                            : item.type == LibraryItemType.game && _tab == 1
                                ? SteamGamePanel(
                                    key: ValueKey('library-steam-${item.id}'),
                                    service: widget.controller.steam,
                                    itemId: item.id,
                                    title: item.title,
                                    allowChangeGame: false,
                                  )
                                : item.type == LibraryItemType.book && _tab == 2
                                    ? BookStatisticsPanel(reading: item.reading)
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.center,
                                        child: SizedBox(
                                          width: constraints.maxWidth,
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              _LibraryDetailCover(item: item),
                                              const SizedBox(width: 24),
                                              Expanded(
                                                child:
                                                    _LibraryDetailFieldsColumn(
                                                  fields: fields,
                                                  status: item.status,
                                                  onStatusSelected: (status) =>
                                                      _changeStatus(
                                                          item, status),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
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
                          onPressed: () {
                            Navigator.of(context).pop();
                            unawaited(_openKnowledgeWorkspace(
                              context,
                              widget.controller,
                              item,
                            ));
                          },
                          icon:
                              const Icon(Icons.description_outlined, size: 18),
                          label: const Text('Abrir páginas'),
                          style: _libraryDetailSecondaryButtonStyle(context),
                        ),
                        if (_enlaceFicha(item) != null) ...[
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            key: const ValueKey('library-item-external-link'),
                            onPressed: () => unawaited(
                              launchUrl(
                                _enlaceFicha(item)!,
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                            icon:
                                const Icon(Icons.open_in_new_rounded, size: 18),
                            label: Text(
                                'Abrir en ${nombreFichaExterna(item.type)}'),
                            style: _libraryDetailSecondaryButtonStyle(context),
                          ),
                        ],
                        const Spacer(),
                        if (_hasPrevious) ...[
                          _LibraryNavigationButton(
                            label: 'Anterior',
                            icon: Icons.chevron_left_rounded,
                            onPressed: () => _moveItem(-1),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (_hasNext) ...[
                          _LibraryNavigationButton(
                            label: 'Siguiente',
                            trailingIcon: Icons.chevron_right_rounded,
                            onPressed: () => _moveItem(1),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (item.type != LibraryItemType.book || _tab != 1)
                          FilledButton.icon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await showDialog<void>(
                                context: context,
                                builder: (context) => _LibraryItemDialog(
                                  controller: widget.controller,
                                  item: item,
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Editar'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(124, 48),
                              backgroundColor: const Color(0xFF607A4D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}

/// Enlace a la ficha de Goodreads o Letterboxd, si el elemento lo tiene.
Uri? _enlaceFicha(LibraryItem item) {
  final enlace = normalizarEnlaceExterno(item.externalUrl);
  return enlace == null || nombreFichaExterna(item.type) == null
      ? null
      : Uri.parse(enlace);
}

class _LibraryDetailFieldsColumn extends StatelessWidget {
  const _LibraryDetailFieldsColumn({
    required this.fields,
    required this.status,
    required this.onStatusSelected,
  });

  final List<(String, String)> fields;
  final LibraryItemStatus status;
  final ValueChanged<LibraryItemStatus> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          if (index > 0) const SizedBox(height: 6),
          _LibraryDetailLine(
            label: fields[index].$1,
            value: fields[index].$2,
            valueWidget: fields[index].$1 == 'Estado'
                ? _LibraryDetailStatusSelector(
                    status: status,
                    onSelected: onStatusSelected,
                  )
                : null,
          ),
        ],
      ],
    );
  }
}

class _LibraryDetailStatusSelector extends StatelessWidget {
  const _LibraryDetailStatusSelector({
    required this.status,
    required this.onSelected,
  });

  final LibraryItemStatus status;
  final ValueChanged<LibraryItemStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      LibraryItemStatus.pending => (
          background: const Color(0xFFECEFF3),
          foreground: const Color(0xFF687384),
        ),
      LibraryItemStatus.inProgress => (
          background: const Color(0xFFE4EFDF),
          foreground: const Color(0xFF526A45),
        ),
      LibraryItemStatus.completed => (
          background: const Color(0xFFDCECCF),
          foreground: const Color(0xFF4E703B),
        ),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: MenuAnchor(
        alignmentOffset: const Offset(0, 2),
        style: MenuStyle(
          alignment: AlignmentDirectional.bottomStart,
          backgroundColor: const WidgetStatePropertyAll(Color(0xFFFFFCF8)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          minimumSize: const WidgetStatePropertyAll(Size(180, 0)),
          maximumSize: const WidgetStatePropertyAll(Size(200, 160)),
        ),
        menuChildren: [
          for (final option in LibraryItemStatus.values)
            MenuItemButton(
              onPressed: () => onSelected(option),
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(180, 40)),
                padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: option == status
                        ? const Icon(Icons.check_rounded, size: 16)
                        : null,
                  ),
                  Text(_libraryStatusSingularLabel(option),
                      style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
        ],
        builder: (context, controller, child) => Tooltip(
          message: 'Cambiar estado',
          child: InkWell(
            key: const ValueKey('library-detail-status-selector'),
            borderRadius: BorderRadius.circular(999),
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: child,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _libraryStatusSingularLabel(status),
                  style: TextStyle(
                    color: colors.foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: colors.foreground),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookQuoteEditDialog extends StatefulWidget {
  const _BookQuoteEditDialog({
    required this.controller,
    required this.itemId,
    required this.quote,
  });

  final TodoWorkspace controller;
  final String itemId;
  final Map<String, dynamic> quote;

  @override
  State<_BookQuoteEditDialog> createState() => _BookQuoteEditDialogState();
}

class _BookQuoteEditDialogState extends State<_BookQuoteEditDialog> {
  late final TextEditingController _text;
  late final TextEditingController _page;
  late final TextEditingController _chapter;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.quote['text'] as String? ?? '');
    _page = TextEditingController(text: widget.quote['page'] as String? ?? '');
    _chapter =
        TextEditingController(text: widget.quote['chapter'] as String? ?? '');
    _note = TextEditingController(text: widget.quote['note'] as String? ?? '');
  }

  @override
  void dispose() {
    _text.dispose();
    _page.dispose();
    _chapter.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final quoteId = widget.quote['id'] as String?;
    if (quoteId == null ||
        !widget.controller.updateBookQuote(
          widget.itemId,
          quoteId,
          text: _text.text,
          page: _page.text,
          chapter: _chapter.text,
          note: _note.text,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La cita necesita texto para guardarse.')));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Editar cita'),
        content: SizedBox(
          width: 560,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const ValueKey('book-quote-text-editor'),
              controller: _text,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Texto de la cita'),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('book-quote-page-editor'),
                  controller: _page,
                  decoration: const InputDecoration(labelText: 'Página'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _chapter,
                  decoration: const InputDecoration(labelText: 'Capítulo'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Nota personal'),
            ),
          ]),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: _libraryDetailSecondaryButtonStyle(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('Guardar cita'),
          ),
        ],
      );
}

class _LibraryDetailCover extends StatelessWidget {
  const _LibraryDetailCover({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final source = item.coverUrl?.trim();
    return SizedBox(
      key: const ValueKey('library-item-detail-cover'),
      width: 244,
      height: 416,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260F1B0C),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE3D8CB)),
            ),
            child: Stack(fit: StackFit.expand, children: [
              _LibraryCoverImage(
                source: source,
                type: item.type,
                iconSize: 34,
              ),
              if (item.type == LibraryItemType.book && item.reading != null)
                Positioned(
                    top: 12,
                    right: 12,
                    child: BookReadingBadge(
                        reading: item.reading!,
                        totalPages: bookPageTotal(item.pages, item.reading))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LibraryBookDetailTabs extends StatelessWidget {
  const _LibraryBookDetailTabs(
      {required this.count, required this.onTap, this.isGame = false});

  final bool isGame;
  final int count;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final visuals = context.visuals;
    return Container(
        width: isGame ? 290 : 422,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: visuals.accent.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(10)),
        child: TabBar(
            onTap: onTap,
            dividerHeight: 0,
            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            labelColor: visuals.accent,
            unselectedLabelColor: visuals.textMuted,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(7)),
            splashBorderRadius: BorderRadius.circular(7),
            tabs: [
              const Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.info_outline_rounded, size: 16),
                SizedBox(width: 6),
                Flexible(
                    child: Text('Información',
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
              ])),
              if (isGame)
                const Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.emoji_events_outlined, size: 17),
                  SizedBox(width: 6),
                  Text('Logros'),
                ]))
              else
                Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.format_quote_rounded, size: 18),
                  const SizedBox(width: 6),
                  const Text('Citas'),
                  const SizedBox(width: 7),
                  Text('$count', style: const TextStyle(fontSize: 11)),
                ])),
              if (!isGame)
                const Tab(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.insights_outlined, size: 16),
                  SizedBox(width: 6),
                  Flexible(
                      child: Text('Estadísticas',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                ])),
            ]));
  }
}

class _LibraryNavigationButton extends StatelessWidget {
  const _LibraryNavigationButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (icon != null) ...[
        Icon(icon, size: 20),
        const SizedBox(width: 6),
      ],
      Text(label),
      if (trailingIcon != null) ...[
        const SizedBox(width: 6),
        Icon(trailingIcon, size: 20),
      ],
    ];
    return OutlinedButton(
      onPressed: onPressed,
      style: _libraryDetailSecondaryButtonStyle(context),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

ButtonStyle _libraryDetailSecondaryButtonStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(100, 48),
    backgroundColor: const Color(0xFFFFFCF8),
    foregroundColor: context.visuals.textStrong,
    side: const BorderSide(color: Color(0xFFE3D8CB)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}

class _LibraryDetailLine extends StatelessWidget {
  const _LibraryDetailLine({
    required this.label,
    required this.value,
    this.valueWidget,
  });

  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final hasLongNote =
        label == 'Notas' && (value.length > 120 || value.contains('\n'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        border: Border.all(color: const Color(0xFFE3D8CB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_detailIcon(label), size: 17, color: const Color(0xFF607A4D)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.visuals.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: valueWidget ??
                (hasLongNote
                    ? InkWell(
                        onTap: () {
                          showDialog<void>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Notas'),
                              scrollable: true,
                              content: SizedBox(
                                width: 560,
                                child: SelectableText(value),
                              ),
                              actions: [
                                OutlinedButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(),
                                  style: _libraryDetailSecondaryButtonStyle(
                                      dialogContext),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              value,
                              key:
                                  const ValueKey('library-detail-note-preview'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Leer notas completas',
                              style: TextStyle(
                                color: context.visuals.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _TextoConAyudaSiRecortado(
                        texto: value.isEmpty ? '-' : value,
                        maxLines: 2,
                        textAlign: TextAlign.left,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      )),
          ),
        ],
      ),
    );
  }
}

/// Muestra el texto y solo ofrece la ayuda emergente cuando queda recortado.
class _TextoConAyudaSiRecortado extends StatelessWidget {
  const _TextoConAyudaSiRecortado({
    required this.texto,
    required this.maxLines,
    required this.style,
    this.textAlign,
  });

  final String texto;
  final int maxLines;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final estiloFinal = DefaultTextStyle.of(context).style.merge(style);
        final medida = TextPainter(
          text: TextSpan(text: texto, style: estiloFinal),
          maxLines: maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final recortado = medida.didExceedMaxLines;
        medida.dispose();
        final contenido = Text(
          texto,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: style,
        );
        return recortado
            ? Tooltip(message: texto, child: contenido)
            : contenido;
      },
    );
  }
}

IconData _detailIcon(String label) {
  if (label.contains('Título')) return Icons.title_rounded;
  if (label.contains('Estado')) return Icons.check_circle_outline_rounded;
  if (label.contains('Valoración')) return Icons.star_outline_rounded;
  if (label.contains('Autor')) return Icons.person_outline_rounded;
  if (label.contains('Fecha')) return Icons.calendar_today_outlined;
  if (label.contains('Año')) return Icons.event_outlined;
  if (label.contains('Formato')) return Icons.menu_book_outlined;
  if (label.contains('Saga') || label.contains('colección')) {
    return Icons.collections_bookmark_outlined;
  }
  if (label.contains('Número')) return Icons.tag_rounded;
  if (label.contains('Mostrar')) return Icons.visibility_outlined;
  if (label.contains('Género')) return Icons.local_offer_outlined;
  if (label.contains('Páginas')) return Icons.article_outlined;
  if (label.contains('Plataforma')) return Icons.sports_esports_outlined;
  if (label.contains('Desarrollador')) return Icons.code_outlined;
  if (label.contains('Director') || label.contains('creador')) {
    return Icons.movie_filter_outlined;
  }
  if (label.contains('Duración') || label.contains('Horas')) {
    return Icons.schedule_outlined;
  }
  if (label.contains('País')) return Icons.public_outlined;
  if (label.contains('Notas')) return Icons.notes_outlined;
  return Icons.info_outline_rounded;
}

Future<void> _showLibraryGoalDetails(
  BuildContext context,
  TodoWorkspace controller,
  int year,
  List<LibraryGoal> goals,
  LibraryGoal goal,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LibraryGoalDetailsDialog(
      controller: controller,
      year: year,
      goals: goals,
      goal: goal,
    ),
  );
}
